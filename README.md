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

The client sends the heartbeat every 10 seconds, and reconnects (with backoff) if the connection drops.
Twelve Data forgets subscriptions with the connection: use `RealTimePrices.notify_on_reconnect/2`
to be told when to subscribe again, or let `ExTwelveData.Supervisor` with a
`ExTwelveData.RealTimePrices.SubscriptionsManager.Provider` resubscribe for you.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_twelve_data` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_twelve_data, "~> 0.4"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ex_twelve_data>.

## Development

The toolchain comes from the Nix flake: run `nix develop`, or `direnv allow` to load it
automatically (direnv also loads `TWELVEDATA_APIKEY` from a git-ignored `.env` file).

```sh
mix deps.get
mix test                     # unit tests
mix test --only integration  # live API test, needs TWELVEDATA_APIKEY
mix credo --strict && mix dialyzer
```

CI runs all of the above on every pull request and push to `main`
(the live test only when the `TWELVEDATA_APIKEY` secret is available).

### Releasing

Bump `version` in `mix.exs`, move the `Unreleased` changelog entries under a new
`## [x.y.z] - YYYY-MM-DD` heading, and merge to `main`. CI then publishes the package to Hex
and creates the `vx.y.z` tag and GitHub release, using that changelog section as release notes.

Publishing uses [Hex workload identity](https://hex.pm/docs/workload-identity), not an API key:
the package's workload identity on hex.pm trusts repository `borgoat/ex_twelve_data`,
workflow `ci.yml` and environment `release` (restricted to the `main` branch on GitHub).

## Reference

[^1]: https://twelvedata.com/docs#real-time-price-websocket
