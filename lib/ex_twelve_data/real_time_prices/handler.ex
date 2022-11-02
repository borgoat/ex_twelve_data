defmodule ExTwelveData.RealTimePrices.Handler do
  @moduledoc """
  Implement the Handler behaviour to process real-time price updates coming from Twelve Data.
  """

  @type price :: %{
          price: integer,
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
