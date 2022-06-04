defmodule ExTwelvedata.RealtimePricesTest do
  use ExUnit.Case

  alias ExTwelvedata.RealtimePrices

  @moduletag :capture_log

  doctest RealtimePrices

  test "module exists" do
    assert is_list(RealtimePrices.module_info())
  end

  defmodule SamplePriceUpdateHandler do
    @behaviour RealtimePrices

    @impl true
    def handle_price_update(price) do
      assert price.event == "price"
    end
  end

  test "handle price update" do
    RealtimePrices.handle_frame(
      {:text, ~s({"event": "price"})},
      %{mod: SamplePriceUpdateHandler}
    )
  end
end
