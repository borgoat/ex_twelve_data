defmodule MockHandler do
  @behaviour ExTwelveData.RealTimePrices.Handler

  require Logger

  @impl true
  def handle_price_update(price) do
    Logger.info(price)
  end
end

{:ok, pid} =
  ExTwelveData.RealTimePrices.start_link(
    api_key: System.fetch_env!("TWELVE_DATA_API_KEY"),
    handler: MockHandler
  )

alias ExTwelveData.RealTimePrices.SubscriptionsManager

defmodule MockProvider do
  alias ExTwelveData.Symbol
  @behaviour SubscriptionsManager.Provider

  require Logger

  @impl true
  def get_symbols() do
    new =
      MapSet.new(
        Enum.random([
          [
            %Symbol{exchange: "Euronext", symbol: "SLBEN"},
            %Symbol{mic_code: "XPAR", symbol: "ALMIL"},
            %Symbol{type: "Index", symbol: "IXIC"}
          ],
          [
            %Symbol{mic_code: "XDUS", symbol: "ADS"},
            %Symbol{mic_code: "XFRA", symbol: "MQ1"},
            %Symbol{type: "Index", symbol: "VFIAX"}
          ]
        ])
      )

    Logger.warning(new)

    new
  end
end

SubscriptionsManager.start_link(
  pid: pid,
  provider: MockProvider,
  max_subscriptions: 8,
  symbols_extended: true
)

# ["AAPL", "MSFT", "GOOG"],
# ["TSLA", "MSFT", "ABML"],
# ["IXIC", "VFIAX", "QQQ"]
