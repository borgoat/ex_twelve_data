defmodule ExTwelveData.RealtimePricesTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

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
      %{handler: SamplePriceUpdateHandler}
    )
  end

  describe "status events" do
    # Payloads as returned by the live API.
    test "logs failed symbols on partial subscribe" do
      msg =
        ~s({"event":"subscribe-status","status":"warning","success":[{"symbol":"EUR/USD"}],"fails":[{"symbol":"ETH/USD"}]})

      log =
        capture_log(fn -> assert {:ok, _} = RealTimePrices.handle_frame({:text, msg}, %{}) end)

      assert log =~ ~s(status: warning, failed symbols: ["ETH/USD"])
    end

    test "logs parse errors" do
      msg = ~s({"event":"subscribe-status","status":"error","messages":["Cant parse message"]})

      log =
        capture_log(fn -> assert {:ok, _} = RealTimePrices.handle_frame({:text, msg}, %{}) end)

      assert log =~ "Cant parse message"
    end

    test "does not crash on failed unsubscribe or reset" do
      for event <- ["unsubscribe-status", "reset-status"] do
        msg = ~s({"event":"#{event}","status":"error","success":null,"fails":null})
        assert {:ok, _} = RealTimePrices.handle_frame({:text, msg}, %{})
      end
    end

    test "is silent on success with null fields" do
      msg = ~s({"event":"subscribe-status","status":"ok","success":null,"fails":null})

      assert capture_log([level: :warning], fn ->
               RealTimePrices.handle_frame({:text, msg}, %{})
             end) == ""
    end

    test "exits on a failed heartbeat" do
      msg = ~s({"event":"heartbeat","status":"error"})

      assert {:heartbeat_failed, "error"} =
               catch_exit(RealTimePrices.handle_frame({:text, msg}, %{}))
    end
  end

  describe "connection lifecycle" do
    test "first connect marks the client as connected" do
      assert {:ok, %{connected: true}} = RealTimePrices.handle_connect(nil, %{})
    end

    test "notifies listeners on reconnect, since subscriptions are lost" do
      assert {:ok, state} = RealTimePrices.handle_cast({:notify_on_reconnect, self()}, %{})
      assert {:ok, _} = RealTimePrices.handle_connect(nil, Map.put(state, :connected, true))
      assert_received :reconnected
    end
  end
end
