defmodule ExTwelvedata.RealtimePrices do
  @moduledoc """
  Module to get realtime prices from Twelvedata.
  """

  use WebSockex
  require Logger

  @type price :: %{
                   price: integer,
                   currency: String.t,
                   symbol: String.t,
                   exchange: String.t,
                   timestamp: integer,
                   type: String.t,
                   day_volume: integer,
                 }

  @doc """
  Invoked when a price update is received.
  """
  @callback handle_price(price) :: :ok

  @endpoint "wss://ws.twelvedata.com/v1/quotes/price"
  @heartbeat_seconds 10
  @heartbeat_message Jason.encode!(%{action: "heartbeat"})

  @spec start_link(String.t(), module) :: {:error, any} | {:ok, pid}
  def start_link(api_key, module) do
    Logger.info("~> Connecting to Twelvedata")

    WebSockex.start_link(
      @endpoint,
      __MODULE__,
      # TODO
      %{mod: module},
      extra_headers: [
        {"X-TD-APIKEY", api_key}
      ]
    )
  end

  @doc """
  Specify a list of symbols you're interested to.

  Subsequent calls will append new symbols to the list.
  See `unsubscribe/2` and `reset/1` to remove
  """
  @spec subscribe(pid, [String.t()]) :: {:error, any} | {:ok}
  def subscribe(client, symbols) do
    msg =
      Jason.encode!(
        %{
          action: "subscribe",
          params: %{
            symbols: Enum.join(symbols, ",")
          }
        }
      )

    Logger.debug("~> Subscribing to symbols: #{msg}")
    WebSockex.send_frame(client, {:text, msg})
  end

  @doc """
  Send a list of symbols that you're no longer interested to.

  Twelvedata will stop sending updates.
  """
  @spec unsubscribe(pid, [String.t()]) :: {:error, any} | {:ok}
  def unsubscribe(client, symbols) do
    msg =
      Jason.encode!(
        %{
          action: "unsubscribe",
          params: %{
            symbols: Enum.join(symbols, ",")
          }
        }
      )

    Logger.debug("~> Unsubscribing from symbols: #{msg}")
    WebSockex.send_frame(client, {:text, msg})
  end

  @doc """
  Reset the subscription to all price updates.
  """
  @spec reset(pid) :: {:error, any} | {:ok}
  def reset(client) do
    msg =
      Jason.encode!(%{action: "reset"})

    Logger.debug("~> Resetting...")
    WebSockex.send_frame(client, {:text, msg})
  end

  def handle_connect(conn, state) do
    Logger.info("<~ Connected to Twelvedata")
    schedule_next_heartbeat()
    super(conn, state)
  end

  def handle_disconnect(_connection_status_map, state) do
    Logger.warning("Disconnected from Twelvedata! Reconnecting...")
    {:reconnect, state}
  end

  def handle_frame({:text, msg}, state) do
    Logger.debug("<~ Received message: #{msg}")
    case Jason.decode(msg, keys: :atoms) do
      {:ok, obj} ->
        Logger.debug("Processing message: #{inspect obj}")
        {process_message(obj, state), state}
      {:error, _} ->
        Logger.warning("Failed to parse received message as JSON: #{msg}")
        {:ok, state}
    end
  end

  def handle_info(:heartbeat, state) do
    # TODO At this stage, we should also schedule a message to close the connection, keep a reference to it,
    #      and cancel it when we receive the heartbeat reply. This prevents situations where the WebSocket connection
    #      is open, we can send heartbeats, but the server is unresponsive.
    Logger.debug("~> Sending heartbeat")
    schedule_next_heartbeat()
    {:reply, {:text, @heartbeat_message}, state}
  end

  defp process_message(
         %{
           event: "heartbeat",
           status: status
         },
         _state
       ) do
    case status do
      "ok" ->
        :ok
      _ ->
        Logger.error("Received heartbeat with status: #{status}")
        :close
    end
  end

  defp process_message(
         %{
           event: "subscribe-status",
           status: status
         } = obj,
         _state
       ) do
    case status do
      "ok" -> :ok
      _ ->
        Logger.error("Subscribe failed with status: #{status}")
        :close
    end
  end

  defp process_message(
         %{
           event: "unsubscribe-status",
           status: status
         } = obj,
         _state
       ) do
    case status do
      "ok" -> :ok
      _ ->
        Logger.error("Unsubscribe failed with status: #{status}")
        :close
    end
  end

  defp process_message(
         %{
           event: "reset-status",
           status: status
         } = obj,
         _state
       ) do
    case status do
      "ok" -> :ok
      _ ->
        Logger.error("Reset failed with status: #{status}")
        :close
    end
  end

  defp process_message(%{event: "price"} = obj, %{mod: module}) do
    Logger.debug("Price update received: #{inspect(obj)}")
    apply(module, :handle_price, [obj])
    :ok
  end

  defp process_message(obj, _state) do
    Logger.warning("Received unknown event: #{inspect(obj)}")
    :ok
  end

  defp schedule_next_heartbeat do
    Logger.debug("Scheduling next heartbeat in #{@heartbeat_seconds}s...")
    Process.send_after(self(), :heartbeat, @heartbeat_seconds * 1000)
  end
end
