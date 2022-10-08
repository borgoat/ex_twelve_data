# ExTwelveData

Unofficial Elixir client for [Twelve Data](https://twelvedata.com/).

Currently, it only covers the real-time prices WebSocket API.

Happy to accept contributions to support the other endpoints.

## Usage

### Real-time prices client

Twelve Data offers a WebSocket based API for real-time prices[^1].
ExTwelveData uses the [WebSockex](https://github.com/Azolo/websockex)
library to access this endpoint.
Because of this, the WebSocket client runs as a supervised process.

The `ExTwelveData.RealTimePrices.Handler` behaviour requires a single callback,
invoked whenever the client receives a price update from Twelve Data.

```elixir
defmodule Your.Handler do
  @behaviour ExTwelveData.RealTimePrices.Handler
  
  @impl true
  def handle_price_update(price) do
    # Here you can process inbound price updates
    :ok
  end  
end

defmodule Your.Application do
  use Application
  alias ExTwelveData.RealTimePrices
  
  def start(_type, _args) do
    children = [
      {RealTimePrices, name: Your.Name, api_key: "abc", handler: Your.Handler},
    ]
    
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

With the process running, you can now subscribe, unsubscribe, and reset the subscriptions.

```elixir
# Send a list of Twelve Data symbols to subscribe to
ExTwelveData.RealTimePrices.subscribe(Your.Name, ["BTC/USD", "AAPL"])

# Use the PID or process name to address the messages
ExTwelveData.RealTimePrices.unsubscribe(Your.Name, ["AAPL"])

# This stops listening for all updates, while keeping the client running
ExTwelveData.RealTimePrices.reset(Your.Name)
```

The client currently takes care of reconnecting, and sending the heartbeat every 10 seconds.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_twelve_data` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_twelve_data, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ex_twelve_data>.

## Reference

[^1]: https://twelvedata.com/docs#real-time-price-websocket
