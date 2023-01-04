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

  require Logger

  @type options :: [option]

  @type option ::
          GenServer.option()
          | {:pid, pid()}
          | {:provider, SubscriptionsManager.Provider}
          | {:max_subscriptions, integer}

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

    schedule_next_message()

    {:ok,
     %{tracked: MapSet.new(), pid: pid, provider: provider, max_subscriptions: max_subscriptions}}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_info(:clock, state) do
    %{
      tracked: current,
      pid: pid,
      provider: provider,
      max_subscriptions: max_subscriptions
    } = state

    new = provider.get_symbols()

    tracked =
      if !MapSet.equal?(current, new) do
        if is_cleanup_task(max_subscriptions) do
          remove(pid, current, new)
        else
          add(pid, current, new)
        end
      else
        current
      end

    schedule_next_message()
    {:noreply, %{state | tracked: tracked}}
  end

  defp schedule_next_message do
    Process.send_after(self(), :clock, @clock_period_ms)
  end

  defp remove(pid, current, new) do
    to_remove = MapSet.difference(current, new)

    if Enum.any?(to_remove) do
      RealTimePrices.unsubscribe(pid, MapSet.to_list(to_remove))
    end

    MapSet.difference(current, to_remove)
  end

  defp add(pid, current, new) do
    to_add = MapSet.difference(new, current)

    if Enum.any?(to_add) do
      RealTimePrices.subscribe(pid, MapSet.to_list(to_add))
    end

    MapSet.union(current, to_add)
  end

  defp is_cleanup_task(max_subscriptions) do
    # TODO Only if we're approaching time limit, or max subscriptions
    Enum.random(1..6) == 6
  end
end
