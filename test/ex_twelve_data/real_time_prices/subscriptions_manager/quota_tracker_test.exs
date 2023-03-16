defmodule ExTwelveData.RealTimePrices.SubscriptionsManager.QuotaTrackerTest do
  use ExUnit.Case

  alias ExTwelveData.RealTimePrices.SubscriptionsManager.QuotaTracker

  @moduletag :capture_log

  doctest QuotaTracker

  test "module exists" do
    assert is_list(QuotaTracker.module_info())
  end

  test "noop when equal inputs" do
    map = MapSet.new([:a, :b, :c])

    assert :noop = QuotaTracker.action(map, map, 10)
  end

  test "always add when going from empty list to some elements" do
    old = []
    new = [1, 2, 3]
    limit = 10

    assert {:add, [1, 2, 3], [1, 2, 3]} = QuotaTracker.action(old, new, limit)
  end

  test "always remove when going to the empty list" do
    old = ["a", "b", "c"]
    new = []
    limit = 10

    assert {:remove, ["a", "b", "c"], []} = QuotaTracker.action(old, new, limit)
  end

  test "add if there's enough available slots" do
    old = [1, 2]
    new = [1, 2, 3, 4, 5, 6, 7]
    limit = 10

    assert {:add, [3, 4, 5, 6, 7], [1, 2, 3, 4, 5, 6, 7]} = QuotaTracker.action(old, new, limit)
  end

  test "remove if there's too many values" do
    old = [1, 2, 3]
    new = [1, 4, 5, 6]
    limit = 5

    # On the first call we must have a remove to go below the limit
    assert {:remove, [2, 3], [1]} = QuotaTracker.action(old, new, limit)

    # A second call will then get to the expected result
    assert {:add, [4, 5, 6], [1, 4, 5, 6]} = QuotaTracker.action([1], new, limit)
  end

  test "remove if there's nothing to add" do
    old = [1, 2, 3, 4, 5]
    new = [1, 2, 3]
    limit = 10

    assert {:remove, [4, 5], [1, 2, 3]} = QuotaTracker.action(old, new, limit)
  end
end
