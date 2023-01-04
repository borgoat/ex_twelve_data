defmodule ExTwelveData.RealTimePrices.SubscriptionsManager.Provider do
  @moduledoc """
  Implement the Provider behaviour to use the SubscriptionsManager.

  It should return a set containing Twelve Data symbols that the user wants to subscribe to.
  """

  @doc """
  Invoked by the subscriptions manager.

  Shoud provide the set of Twelve Data symbols to subscribe to at this point in time.
  """
  @callback get_symbols() :: MapSet.t(String.t())
end
