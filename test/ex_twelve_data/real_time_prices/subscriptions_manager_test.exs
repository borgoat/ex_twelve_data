defmodule ExTwelveData.RealTimePrices.SubscriptionsManagerTest do
  use ExUnit.Case, async: true

  alias ExTwelveData.RealTimePrices.SubscriptionsManager

  test "forgets tracked symbols on reconnect, so they are subscribed again" do
    state = %{tracked: MapSet.new(["AAPL"])}

    assert {:noreply, %{tracked: tracked}} = SubscriptionsManager.handle_info(:reconnected, state)
    assert MapSet.size(tracked) == 0
  end
end
