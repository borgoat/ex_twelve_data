defmodule ExTwelveData.IntegrationTest do
  use ExUnit.Case

  @moduletag :integration
  @moduletag :capture_log

  defmodule Handler do
    @behaviour ExTwelveData.RealTimePrices.Handler

    @impl true
    def handle_price_update(price), do: send(ExTwelveData.IntegrationTest, {:price, price})
  end

  defmodule Provider do
    @behaviour ExTwelveData.RealTimePrices.SubscriptionsManager.Provider

    # Plain strings exercise the list -> comma-delimited string encoding.
    @impl true
    def get_symbols, do: MapSet.new(["BTC/USD"])
  end

  test "receives live prices through the supervised client" do
    Process.register(self(), __MODULE__)

    start_supervised!(
      {ExTwelveData.Supervisor,
       api_key: System.fetch_env!("TWELVEDATA_APIKEY"),
       handler: Handler,
       provider: Provider,
       max_subscriptions: 8}
    )

    assert_receive {:price, %{event: "price", symbol: "BTC/USD", price: price}}, 30_000
    assert is_number(price)
  end
end
