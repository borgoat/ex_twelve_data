defmodule ExTwelveData.Supervisor do
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
    realtime_prices_name = ExTwelveData.RealTimePrices1

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
