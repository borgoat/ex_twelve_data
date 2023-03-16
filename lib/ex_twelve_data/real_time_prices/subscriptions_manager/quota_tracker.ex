defmodule ExTwelveData.RealTimePrices.SubscriptionsManager.QuotaTracker do
  @moduledoc """
  Helpers to decide whether to remove or add items
  """

  @empty MapSet.new()

  def action(old, new, limit) when is_list(old) and is_list(new) do
    case action(MapSet.new(old), MapSet.new(new), limit) do
      :noop -> :noop
      {op, delta, new} -> {op, MapSet.to_list(delta), MapSet.to_list(new)}
    end
  end

  def action(old, new, limit) do
    if MapSet.equal?(old, new) do
      :noop
    else
      if MapSet.equal?(new, @empty) do
        {:remove, old, @empty}
      else
        to_add = MapSet.difference(new, old)
        to_remove = MapSet.difference(old, new)

        res_if_remove = MapSet.difference(old, to_remove)
        res_if_add = MapSet.union(old, to_add)

        if MapSet.size(res_if_add) > limit || MapSet.size(to_add) == 0 do
          {:remove, to_remove, res_if_remove}
        else
          {:add, to_add, res_if_add}
        end
      end
    end
  end
end
