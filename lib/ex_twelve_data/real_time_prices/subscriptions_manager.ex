defmodule ExTwelveData.RealTimePrices.SubscriptionsManager do
  @moduledoc """
  High-level client to manage subscriptions to the real-time prices endpoint.

  It avoids hitting the rate limits, and batches subscribe and unsubscribe requests.
  SubscriptionsManager expects a list of symbols, and creates a subscription for **at least** those symbols.
  It is implemented as a GenServer, which schedules a message every 600ms (100 events/minute), to subscribe/unsubscribe.

  > ## What do the 100 events per minute limit stand for?
  > This does not affect how many price updates might be received from the server, but instead,
  > it limits how many events (subscribe/unsubscribe/reset) could be sent to the server from the client side.
  >
  > -- from https://support.twelvedata.com/en/articles/5194610-websocket-faq
  """

  use GenServer

  alias ExTwelveData.RealTimePrices
  alias ExTwelveData.RealTimePrices.SubscriptionsManager
  alias ExTwelveData.RealTimePrices.SubscriptionsManager.QuotaTracker

  @type options :: [option]

  @type option ::
          GenServer.option()
          | {:pid, pid()}
          | {:provider, SubscriptionsManager.Provider}
          | {:max_subscriptions, integer()}
          | {:symbols_extended, boolean()}

  # 1 event / 600ms -> 100 events per minute
  @clock_period_ms 600

  @spec start_link(options) :: {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    pid = Keyword.fetch!(opts, :pid)
    provider = Keyword.fetch!(opts, :provider)
    max_subscriptions = Keyword.fetch!(opts, :max_subscriptions)
    symbols_extended = Keyword.get(opts, :symbols_extended, false)

    schedule_next_message()

    {:ok,
     %{
       tracked: MapSet.new(),
       pid: pid,
       provider: provider,
       max_subscriptions: max_subscriptions,
       symbols_extended: symbols_extended
     }}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @doc """
  Runs every @clock_period_ms to honour the rate limit.

  It checks with the configured {SubscriptionsManager.Provider} behaviour what to add/remove,
  and sends the corresponding subscribe/unsubscribe message to Twelve Data.
  """
  def handle_info(:clock, state) do
    %{
      tracked: current,
      pid: pid,
      provider: provider,
      max_subscriptions: max_subscriptions,
      symbols_extended: symbols_extended
    } = state

    new = provider.get_symbols()

    new_state =
      case QuotaTracker.action(current, new, max_subscriptions) do
        :noop ->
          state

        {:add, to_add, new_tracked} ->
          symbols = to_add |> MapSet.to_list() |> join_symbols_if_needed(symbols_extended)
          RealTimePrices.subscribe(pid, symbols)
          %{state | tracked: new_tracked}

        {:remove, to_remove, new_tracked} ->
          symbols = to_remove |> MapSet.to_list() |> join_symbols_if_needed(symbols_extended)
          RealTimePrices.unsubscribe(pid, symbols)
          %{state | tracked: new_tracked}
      end

    schedule_next_message()
    {:noreply, new_state}
  end

  defp join_symbols_if_needed(symbols_set, extended) do
    if extended do
      symbols_set
    else
      Enum.join(symbols_set, ",")
    end
  end

  defp schedule_next_message do
    Process.send_after(self(), :clock, @clock_period_ms)
  end
end
