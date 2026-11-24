# Integration tests hit the live API: `mix test --only integration` (needs TWELVEDATA_APIKEY).
ExUnit.start(exclude: [:integration])
