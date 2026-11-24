defmodule ExTwelveData.RealTimePrices.SubscriptionsManager.QuotaTracker do
  @moduledoc """
  Helpers to decide whether to remove or add items
  """

  @spec action([symbol], [symbol], integer) :: :noop | {:add | :remove, [symbol], [symbol]}
        when symbol: String.t()
  @spec action(set, set, integer) :: :noop | {:add | :remove, set, set}
        when set: MapSet.t(String.t())
  def action(old, new, limit) when is_list(old) and is_list(new) do
    case set_action(MapSet.new(old), MapSet.new(new), limit) do
      :noop -> :noop
      {op, delta, new} -> {op, MapSet.to_list(delta), MapSet.to_list(new)}
    end
  end

  def action(old, new, limit), do: set_action(old, new, limit)

  defp set_action(old, new, limit) do
    to_add = MapSet.difference(new, old)
    to_remove = MapSet.difference(old, new)
    room = limit - MapSet.size(old)

    cond do
      MapSet.equal?(old, new) ->
        :noop

      # Nothing to add, or adding would exceed the limit: free up slots first.
      MapSet.size(to_remove) > 0 and (MapSet.size(to_add) == 0 or MapSet.size(to_add) > room) ->
        {:remove, to_remove, MapSet.difference(old, to_remove)}

      # More symbols than the limit and nothing left to remove: keep what we have.
      room <= 0 ->
        :noop

      true ->
        to_add = to_add |> Enum.take(room) |> MapSet.new()
        {:add, to_add, MapSet.union(old, to_add)}
    end
  end
end
