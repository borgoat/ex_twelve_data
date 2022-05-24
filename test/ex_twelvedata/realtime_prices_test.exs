defmodule ExTwelvedata.RealtimePricesTest do
  use ExUnit.Case

  alias ExTwelvedata.RealtimePrices

  @moduletag :capture_log

  doctest RealtimePrices

  test "module exists" do
    assert is_list(RealtimePrices.module_info())
  end
end
