defmodule Komoku.StorageTest do
  use ExUnit.Case, async: true

  alias Komoku.Storage

  setup do
    # Explicitly get a connection before each test
    #:ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    #    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  test "create a key" do 
    assert has_key?("boo") == false
    :ok = Storage.insert_key "boo", "numeric"
    assert has_key?("boo") == true
  end

  test "store a value" do
    :ok = Storage.insert_key "num", "numeric"
    :ok = Storage.put("num", 123)
    assert Storage.get("num") == 123
  end

  test "get the last value" do
    :ok = Storage.insert_key "num2", "numeric"
    assert Storage.get("num2") == nil
    :ok = Storage.put("num2", 123)
    assert Storage.get("num2") == 123
    :ok = Storage.put("num2", 345)
    assert Storage.get("num2") == 345
  end

  test "get the last value with time" do
    :ok = Storage.insert_key "last_with_time", "numeric"
    :ok = Storage.put("last_with_time", 123)
    time_now = :os.system_time(:milli_seconds) / 1_000
    {value, time} = Storage.last("last_with_time")
    assert value == 123
    assert time > time_now - 0.1
    assert time < time_now + 0.1
  end

  defp has_key?(name) do
    Storage.list_keys |> Enum.any?(fn {k, _v} -> k == name end) == true
  end
end
