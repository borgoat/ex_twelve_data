defmodule ExTwelveData.SupervisorTest do
  use ExUnit.Case, async: true

  alias ExTwelveData.RealTimePrices
  alias ExTwelveData.RealTimePrices.SubscriptionsManager

  # Subscriptions die with the connection, so neither child may outlive the other.
  test "restarts the client and the manager together, the manager addressing the client by name" do
    opts = [api_key: "key", handler: Handler, provider: Provider, max_subscriptions: 8]

    assert {:ok, {%{strategy: :one_for_all}, [client, manager]}} =
             ExTwelveData.Supervisor.init(opts)

    assert %{start: {RealTimePrices, :start_link, [client_opts]}} = client
    assert %{start: {SubscriptionsManager, :start_link, [manager_opts]}} = manager
    assert manager_opts[:pid] == client_opts[:name]
  end
end
