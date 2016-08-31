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
    :ok = Storage.put("last_with_time", 123)
    time_now = :os.system_time(:milli_seconds) / 1_000
    {value, time} = Storage.last("last_with_time")
    assert value == 123
    assert time > time_now - 0.1
    assert time < time_now + 0.1
  end

  test "guess numeric value type" do
    :ok = Storage.put("guess_num", 123)
    assert Storage.get("guess_num") == 123
    :ok = Storage.put("guess_num2", 3.14)
    assert Storage.get("guess_num2") == 3.14
  end

  test "guess boolean value type" do
    :ok = Storage.put("guess_bool", false)
    assert Storage.get("guess_bool") == false
    :ok = Storage.put("guess_bool2", "true")
    assert Storage.get("guess_bool2") == true
  end

  test "guess string value type" do
    :ok = Storage.put("guess_string", "foo")
    assert Storage.get("guess_string") == "foo"
  end

  test "delete a key" do
    :ok = Storage.put("delete_key", 123)
    :ok = Storage.delete_key("delete_key")
    assert Storage.get("delete_key") == nil
    :ok = Storage.put("delete_key", "true")
    assert Storage.get("delete_key") == true
  end

  # Time 

  test "should store provided time properly" do
    ts = 1472600000
    :ok = Storage.put("store_time", 123, ts)
    {123, time} = Storage.last("store_time")
    assert time == ts
  end

  test "last value should be ordered by time not storage time" do
    ts1 = 14726_00000
    :ok = Storage.put("store_time2", 123, ts1)
    ts2 = 14720_00000
    :ok = Storage.put("store_time2", 123, ts2)
    {123, time} = Storage.last("store_time2")
    assert time == ts1
  end

  # Boolean

  test "store a bool value" do
    :ok = Storage.insert_key "bput", "boolean"
    :ok = Storage.put("bput", false)
    assert Storage.get("bput") == false
    :ok = Storage.put("bput", true)
    assert Storage.get("bput") == true
  end

  # String

  test "store a string value" do
    :ok = Storage.insert_key "str_put", "string"
    :ok = Storage.put("str_put", "boo!")
    assert Storage.get("str_put") == "boo!"
  end

  defp has_key?(name) do
    Storage.list_keys |> Enum.any?(fn {k, _v} -> k == name end) == true
  end
end
