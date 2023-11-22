defmodule ExTwelveData.Supervisor do
  @moduledoc """
  Supervisor for the RealTimePrices and SubscriptionsManager processes.

  It starts the RealTimePrices and SubscriptionsManager processes, and restarts them if they crash.
  This is important since the RealTimePrices client has an implicit state with the Twelve Data connection:
  the list of symbols that are subscribed to is determined by the sequence of subscribe/unsubscribe messages.
  If the RealTimePrices process crashes, the state is lost, and the list of subscribed symbols is reset.
  This supervisor ensures that when the RealTimePrices process crashes,
  it is restarted with a fresh SubscriptionManager process, which will then have a clean state,
  and restart the entire flow.
  """
  use Supervisor

  @type options :: [option]

  @type option ::
          ExTwelveData.RealTimePrices.option()
          | ExTwelveData.RealTimePrices.SubscriptionsManager.option()

  @spec start_link(options) :: {:error, any} | {:ok, pid}
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    realtime_prices_name = ExTwelveData.RealTimePrices.Supervised

    realtime_prices_options =
      Keyword.merge(
        [name: realtime_prices_name],
        Keyword.drop(opts, [:name])
      )

    subscriptions_manager_options =
      Keyword.merge([pid: realtime_prices_name], Keyword.drop(opts, [:name]))

    children = [
      {ExTwelveData.RealTimePrices, realtime_prices_options},
      {ExTwelveData.RealTimePrices.SubscriptionsManager, subscriptions_manager_options}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
