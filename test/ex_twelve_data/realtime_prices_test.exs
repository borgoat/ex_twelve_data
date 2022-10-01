defmodule ExTwelveData.RealtimePricesTest do
  use ExUnit.Case

  alias ExTwelveData.RealTimePrices

  @moduletag :capture_log

  doctest RealTimePrices

  test "module exists" do
    assert is_list(RealTimePrices.module_info())
  end

  defmodule SamplePriceUpdateHandler do
    @behaviour RealTimePrices.Handler

    @impl true
    def handle_price_update(price) do
      assert price.event == "price"
    end
  end

  test "handle price update" do
    RealTimePrices.handle_frame(
      {:text, ~s({"event": "price"})},
      %{mod: SamplePriceUpdateHandler}
    )
  end
end
