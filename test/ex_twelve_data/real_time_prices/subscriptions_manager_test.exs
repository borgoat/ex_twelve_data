defmodule ExTwelveData.RealTimePrices.SubscriptionsManagerTest do
  use ExUnit.Case, async: true

  alias ExTwelveData.RealTimePrices.SubscriptionsManager

  @moduletag :capture_log

  defmodule Provider do
    @behaviour SubscriptionsManager.Provider

    @impl true
    def get_symbols, do: MapSet.new(["AAPL"])
  end

  test "forgets tracked symbols on reconnect, so they are subscribed again" do
    state = %{tracked: MapSet.new(["AAPL"])}

    assert {:noreply, %{tracked: tracked}} = SubscriptionsManager.handle_info(:reconnected, state)
    assert MapSet.size(tracked) == 0
  end

  test "subscribes to the provider's symbols once, retrying a send that failed" do
    # This process stands in for the WebSockex client: it receives the frames and answers them.
    start_supervised!(
      {SubscriptionsManager, pid: self(), provider: Provider, max_subscriptions: 8}
    )

    assert_receive {:"$websockex_send", from, {:text, msg}}, 2_000
    assert Jason.decode!(msg) == %{"action" => "subscribe", "params" => %{"symbols" => "AAPL"}}
    GenServer.reply(from, {:error, %WebSockex.NotConnectedError{}})

    assert_receive {:"$websockex_send", from, {:text, ^msg}}, 2_000
    GenServer.reply(from, :ok)

    # Longer than one clock period (600ms).
    refute_receive {:"$websockex_send", _, _}, 1_000
  end
end
