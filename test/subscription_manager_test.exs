defmodule Komoku.SubscriptionManagerTest do
  use ExUnit.Case

  alias Komoku.SubscriptionManager, as: SM

  test "receive notification" do
    SM.subscribe("foo")
    SM.publish(%{key: "foo", time: Komoku.Util.ts, value: 32})
    receive do
      {:key_update, %{key: "foo", time: _time, value: 32}} ->
        assert 1 == 1
    after 
      100 ->
        assert false
    end
  end
end
