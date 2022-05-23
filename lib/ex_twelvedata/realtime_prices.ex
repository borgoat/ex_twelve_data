defmodule ExTwelvedata.RealtimePrices do
  @moduledoc """
  Module to read the realtime prices from Twelvedata.
  """

  use WebSockex
  require Logger

  @endpoint "wss://ws.twelvedata.com/v1/quotes/price"
  @heartbeat_seconds 10
  @heartbeat_message Jason.encode!(%{"action" => "heartbeat"})

  @spec start_link(String.t()) :: {:error, any} | {:ok, pid}
  def start_link(api_key) do
    Logger.info("-> Connecting to Twelvedata")

    WebSockex.start_link(
      @endpoint,
      __MODULE__,
      # TODO
      :fake_state,
      extra_headers: [
        {"X-TD-APIKEY", api_key}
      ]
    )
  end

  @spec subscribe(pid, [String.t()]) :: {:error, any} | {:ok}
  def subscribe(client, symbols) do
    msg =
      Jason.encode!(%{
        "action" => "subscribe",
        "params" => %{
          "symbols" => Enum.join(symbols, ",")
        }
      })

    Logger.debug("-> Subscribing to symbols: #{msg}")
    WebSockex.send_frame(client, {:text, msg})
  end

  def handle_connect(conn, state) do
    Logger.info("<- Connected to Twelvedata")
    schedule_next_heartbeat()
    super(conn, state)
  end

  def handle_disconnect(_connection_status_map, state) do
    Logger.warning("Disconnected from Twelvedata! Reconnecting...")
    {:reconnect, state}
  end

  def handle_frame({:text, msg}, state) do
    Logger.debug("<- Received message: #{msg}")
    {:ok, obj} = Jason.decode(msg)
    res = process_message(obj)
    {res, state}
  end

  def handle_info(:heartbeat, state) do
    Logger.debug("-> Sending heartbeat")
    schedule_next_heartbeat()
    {:reply, {:text, @heartbeat_message}, state}
  end

  defp process_message(%{
         "event" => "heartbeat",
         "status" => status
       }) do
    if status == "ok" do
      :ok
    else
      Logger.error("Received heartbeat with status: #{status}")
      :close
    end
  end

  defp process_message(
         %{
           "event" => "subscribe-status",
           "status" => status
         } = obj
       ) do
    if status == "ok" do
      :ok
    else
      Logger.error("Subscribe failed: #{inspect(obj)}")
      :close
    end
  end

  defp process_message(%{"event" => "price"} = obj) do
    Logger.debug("Price update received: #{inspect(obj)}")
    # TODO callback
    :ok
  end

  defp process_message(obj) do
    Logger.warning("Received unknown event: #{inspect(obj)}")
    :ok
  end

  defp schedule_next_heartbeat do
    Logger.debug("Scheduling next heartbeat in #{@heartbeat_seconds}s...")
    Process.send_after(self(), :heartbeat, @heartbeat_seconds * 1000)
  end
end
