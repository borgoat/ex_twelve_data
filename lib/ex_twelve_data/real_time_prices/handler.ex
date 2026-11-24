defmodule ExTwelveData.RealTimePrices.Handler do
  @moduledoc """
  Implement the Handler behaviour to process real-time price updates coming from Twelve Data.
  """

  @typedoc """
  A price update. Which fields are present depends on the instrument.

  A field that Twelve Data adds after this release arrives under its string key, not an atom.
  """
  @type price :: %{
          price: number,
          currency: String.t(),
          symbol: String.t(),
          exchange: String.t(),
          timestamp: integer,
          type: String.t(),
          day_volume: integer
        }

  @doc """
  Invoked when a price update is received.
  """
  @callback handle_price_update(price) :: :ok
end
