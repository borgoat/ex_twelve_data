defmodule ExTwelveData.RealTimePrices do
  @moduledoc """
  WebSocket client to get real-time prices from Twelve Data.
  """

  use WebSockex

  require Logger

  alias ExTwelveData.RealTimePrices.Handler
  alias ExTwelveData.Symbol

  @typedoc """
  Symbols passed to subscribe/unsubscribe.

  It can either be an array of objects (extended format),
  or a comma-delimited string with multiple symbols.
  """
  @type symbols_list :: String.t() | [Symbol.t()]

  @type options :: [option]

  @type option ::
          WebSockex.option()
          | {:api_key, binary}
          | {:handler, Handler}

  @endpoint "wss://ws.twelvedata.com/v1/quotes/price"
  @heartbeat_seconds 10
  @heartbeat_message Jason.encode!(%{action: "heartbeat"})

  @spec start_link(options) :: {:error, any} | {:ok, pid}
  def start_link(opts) do
    Logger.info("~> Connecting to Twelve Data")

    handler = Keyword.fetch!(opts, :handler)

    WebSockex.start_link(
      @endpoint,
      __MODULE__,
      %{handler: handler},
      websockex_opts(opts)
    )
  end

  @spec websockex_opts(options) :: options
  defp websockex_opts(opts) do
    api_key = Keyword.fetch!(opts, :api_key)

    # TODO CAStore should probably be optional, and users should be able to pass in their own CA certificates file.
    ssl_options = [
      verify: :verify_peer,
      depth: 99,
      cacertfile: CAStore.file_path(),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]

    extra_headers = [
      {"X-TD-APIKEY", api_key}
    ]

    Keyword.merge([ssl_options: ssl_options, extra_headers: extra_headers, insecure: false], opts)
  end

  @doc """
  Specify a list of symbols you're interested to.

  Subsequent calls will append new symbols to the list.
  See `unsubscribe/2` and `reset/1` to remove
  """
  @spec subscribe(pid, symbols_list()) :: {:error, any} | {:ok}
  def subscribe(client, symbols) do
    msg =
      Jason.encode!(%{
        action: "subscribe",
        params: %{
          symbols: symbols
        }
      })

    Logger.debug("~> Subscribing to symbols: #{msg}")
    WebSockex.send_frame(client, {:text, msg})
  end

  @doc """
  Send a list of symbols that you're no longer interested to.

  Twelve Data will stop sending updates.
  """
  @spec unsubscribe(pid, symbols_list()) :: {:error, any} | {:ok}
  def unsubscribe(client, symbols) do
    msg =
      Jason.encode!(%{
        action: "unsubscribe",
        params: %{
          symbols: symbols
        }
      })

    Logger.debug("~> Unsubscribing from symbols: #{msg}")
    WebSockex.send_frame(client, {:text, msg})
  end

  @doc """
  Reset the subscription to all price updates.
  """
  @spec reset(pid) :: {:error, any} | {:ok}
  def reset(client) do
    msg = Jason.encode!(%{action: "reset"})

    Logger.debug("~> Resetting...")
    WebSockex.send_frame(client, {:text, msg})
  end

  def handle_connect(conn, state) do
    Logger.info("<~ Connected to Twelve Data")
    schedule_next_heartbeat()
    super(conn, state)
  end

  def handle_disconnect(_connection_status_map, state) do
    Logger.warning("Disconnected from Twelve Data! Reconnecting...")
    {:reconnect, state}
  end

  def handle_frame({:text, msg}, state) do
    Logger.debug("<~ Received message: #{msg}")

    case Jason.decode(msg, keys: :atoms) do
      {:ok, obj} ->
        Logger.debug("Processing message: #{inspect(obj)}")
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
         },
         _state
       ) do
    case status do
      "ok" ->
        :ok

      _ ->
        Logger.error("Subscribe failed with status: #{status}")
        :close
    end
  end

  defp process_message(
         %{
           event: "unsubscribe-status",
           status: status
         },
         _state
       ) do
    case status do
      "ok" ->
        :ok

      _ ->
        Logger.error("Unsubscribe failed with status: #{status}")
        :close
    end
  end

  defp process_message(
         %{
           event: "reset-status",
           status: status
         },
         _state
       ) do
    case status do
      "ok" ->
        :ok

      _ ->
        Logger.error("Reset failed with status: #{status}")
        :close
    end
  end

  defp process_message(%{event: "price"} = obj, %{handler: handler}) do
    Logger.debug("Price update received: #{inspect(obj)}")
    handler.handle_price_update(obj)
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
