defmodule ExTwelveData.Symbol do
  @derive Jason.Encoder
  defstruct [
    :exchange,
    :mic_code,
    :symbol,
    :type
  ]

  @typedoc """
  Supports: Stock, Index, ETF, REIT
  """
  @type instrument_types :: String.t()

  @typedoc """
  Extended format for Twelve Data symbols.
  """
  @type t :: %__MODULE__{
          exchange: String.t() | nil,
          mic_code: String.t() | nil,
          symbol: String.t(),
          type: instrument_types
        }
end
