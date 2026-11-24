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
  a comma-delimited string with multiple symbols,
  or a list of strings (sent as a comma-delimited string).
  """
  @type symbols_list :: String.t() | [String.t()] | [Symbol.t()]

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

    Keyword.merge(
      [ssl_options: ssl_options, extra_headers: extra_headers, insecure: false],
      opts
    )
  end

  @doc """
  Specify a list of symbols you're interested to.

  Subsequent calls will append new symbols to the list.
  See `unsubscribe/2` and `reset/1` to remove
  """
  @spec subscribe(WebSockex.client(), symbols_list()) :: :ok | {:error, any}
  def subscribe(client, symbols) do
    msg =
      Jason.encode!(%{
        action: "subscribe",
        params: %{
          symbols: encode_symbols(symbols)
        }
      })

    Logger.debug("~> Subscribing to symbols: #{msg}")
    WebSockex.send_frame(client, {:text, msg})
  end

  @doc """
  Send a list of symbols that you're no longer interested to.

  Twelve Data will stop sending updates.
  """
  @spec unsubscribe(WebSockex.client(), symbols_list()) :: :ok | {:error, any}
  def unsubscribe(client, symbols) do
    msg =
      Jason.encode!(%{
        action: "unsubscribe",
        params: %{
          symbols: encode_symbols(symbols)
        }
      })

    Logger.debug("~> Unsubscribing from symbols: #{msg}")
    WebSockex.send_frame(client, {:text, msg})
  end

  @doc """
  Reset the subscription to all price updates.
  """
  @spec reset(WebSockex.client()) :: :ok | {:error, any}
  def reset(client) do
    msg = Jason.encode!(%{action: "reset"})

    Logger.debug("~> Resetting...")
    WebSockex.send_frame(client, {:text, msg})
  end

  @doc """
  Send `:reconnected` to `pid` whenever the client reconnects to Twelve Data.

  Twelve Data drops all subscriptions with the connection, so `pid` should subscribe again.
  `SubscriptionsManager` registers itself this way.
  """
  @spec notify_on_reconnect(WebSockex.client(), pid) :: :ok
  def notify_on_reconnect(client, pid) do
    WebSockex.cast(client, {:notify_on_reconnect, pid})
  end

  def handle_connect(conn, state) do
    if state[:connected] do
      Logger.info("<~ Reconnected to Twelve Data, notifying listeners to resubscribe")
      Enum.each(Map.get(state, :listeners, []), &send(&1, :reconnected))
    else
      Logger.info("<~ Connected to Twelve Data")
      # The heartbeat loop survives reconnects, so start it only once.
      schedule_next_heartbeat()
    end

    super(conn, Map.put(state, :connected, true))
  end

  def handle_cast({:notify_on_reconnect, pid}, state) do
    {:ok, Map.update(state, :listeners, [pid], &[pid | &1])}
  end

  def handle_disconnect(%{attempt_number: attempt}, state) do
    Logger.warning("Disconnected from Twelve Data! Reconnecting (attempt #{attempt})...")

    # Wait 1, 2, then 3s: never instantly, since Twelve Data may close connections in bursts (and every
    # reconnect costs a resubscribe), and capped below send_frame's 5s timeout so callers aren't killed.
    Process.sleep(min(attempt, 3) * 1000)
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

        # Exit (not reconnect): subscriptions are per connection, so the supervisor must restart from scratch.
        exit({:heartbeat_failed, status})
    end
  end

  # Twelve Data replies "ok", "warning" (partial success) or "error",
  # listing rejected symbols in `fails` and parse errors in `messages`.
  defp process_message(%{event: event, status: status} = obj, _state)
       when event in ["subscribe-status", "unsubscribe-status", "reset-status"] do
    fails = Enum.map(obj[:fails] || [], & &1[:symbol])
    messages = obj[:messages] || []

    if status != "ok" or fails != [] or messages != [] do
      Logger.warning(
        "Received #{event} with status: #{status}, " <>
          "failed symbols: #{inspect(fails)}, messages: #{inspect(messages)}"
      )
    end

    :ok
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

  defp encode_symbols(symbols) when is_list(symbols) do
    if Enum.all?(symbols, &is_binary/1), do: Enum.join(symbols, ","), else: symbols
  end

  defp encode_symbols(symbols), do: symbols

  defp schedule_next_heartbeat do
    Logger.debug("Scheduling next heartbeat in #{@heartbeat_seconds}s...")
    Process.send_after(self(), :heartbeat, @heartbeat_seconds * 1000)
  end
end
