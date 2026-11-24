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

  defmodule ForwardingHandler do
    @behaviour RealTimePrices.Handler

    # `handle_frame/2` runs in the test process here.
    @impl true
    def handle_price_update(price) do
      send(self(), {:price, price})
      :ok
    end
  end

  test "documented fields get atom keys, any other field keeps its string key" do
    msg = ~s({"event":"price","symbol":"AAPL","price":1.5,"brand_new_field":1})

    assert {:ok, _} = RealTimePrices.handle_frame({:text, msg}, %{handler: ForwardingHandler})

    assert_received {:price, price}
    assert price == %{:event => "price", :symbol => "AAPL", :price => 1.5, "brand_new_field" => 1}
  end

  test "survives a frame that is not JSON, or an event it does not know" do
    for msg <- ["not json", ~s({"event":"brand-new-event"})] do
      assert capture_log(fn ->
               assert {:ok, %{}} = RealTimePrices.handle_frame({:text, msg}, %{})
             end) =~ "[warning]"
    end
  end

  test "answers the heartbeat tick with a heartbeat frame" do
    assert {:reply, {:text, msg}, %{}} = RealTimePrices.handle_info(:heartbeat, %{})
    assert Jason.decode!(msg) == %{"action" => "heartbeat"}
  end

  test "closes the connection when the server is silent for a whole heartbeat interval" do
    assert {:reply, _, state} =
             RealTimePrices.handle_info(:heartbeat, %{handler: ForwardingHandler})

    # Any frame counts as a reply.
    assert {:ok, replied} = RealTimePrices.handle_frame({:text, ~s({"event":"price"})}, state)
    assert {:reply, _, state} = RealTimePrices.handle_info(:heartbeat, replied)

    assert {:close, state} = RealTimePrices.handle_info(:heartbeat, state)

    # The reconnect starts afresh, or the next tick would close it again.
    assert {:ok, state} = RealTimePrices.handle_connect(nil, state)
    assert {:reply, _, _} = RealTimePrices.handle_info(:heartbeat, state)
  end

  describe "requests" do
    # Stands in for the WebSockex client: accepts one frame, and returns its JSON.
    defp sent(request) do
      test = self()

      client =
        spawn_link(fn ->
          receive do
            {:"$websockex_send", from, {:text, msg}} ->
              GenServer.reply(from, :ok)
              send(test, {:sent, Jason.decode!(msg)})
          end
        end)

      assert :ok = request.(client)
      assert_receive {:sent, msg}
      msg
    end

    # Twelve Data rejects an array of strings with "Cant parse message".
    test "a list of strings is sent as one comma-delimited string" do
      assert sent(&RealTimePrices.subscribe(&1, ["AAPL", "BTC/USD"])) ==
               %{"action" => "subscribe", "params" => %{"symbols" => "AAPL,BTC/USD"}}
    end

    test "extended symbols are sent as an array of objects" do
      symbol = %ExTwelveData.Symbol{symbol: "AAPL", exchange: "NASDAQ"}

      assert %{"action" => "unsubscribe", "params" => %{"symbols" => [object]}} =
               sent(&RealTimePrices.unsubscribe(&1, [symbol]))

      assert %{"symbol" => "AAPL", "exchange" => "NASDAQ"} = object
    end

    test "a string of symbols is sent as it is" do
      assert %{"params" => %{"symbols" => "AAPL,MSFT"}} =
               sent(&RealTimePrices.subscribe(&1, "AAPL,MSFT"))
    end

    test "reset names no symbols" do
      assert sent(&RealTimePrices.reset/1) == %{"action" => "reset"}
    end
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
