defmodule Komoku.StorageTest do
  # pretty hardcore since one test is killking the key master, but oh well it seems to work
  # may stop working when we start doing dp storage async in KH
  use ExUnit.Case, async: true

  alias Komoku.Storage

  setup do
    # Explicitly get a connection before each test
    #:ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    #    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  # Keys operations

  test "create a key" do
    assert has_key?("boo") == false
    :ok = Storage.insert_key "boo", "numeric"
    assert has_key?("boo") == true
  end

  test "delete a key" do
    :ok = Storage.put("delete_key", 123)
    :ok = Storage.delete_key("delete_key")
    assert Storage.get("delete_key") == nil
    :ok = Storage.put("delete_key", "true")
    assert Storage.get("delete_key") == true
  end

  test "update a key when doesn't exist" do
    :ok = Storage.update_key "boo_update", "numeric"
    assert has_key?("boo_update", "numeric") == true
  end

  test "update opts for an existing key" do
    name = "update_uptime_opts"
    :ok = Storage.insert_key(name, "uptime", %{"max_time" => 60})
    assert has_key?(name, "uptime") == true
    assert Storage.list_keys[name].opts["max_time"] == 60
    :ok = Storage.update_key(name, "uptime", %{"max_time" => 77})
    assert has_key?(name, "uptime") == true
    assert Storage.list_keys[name].opts["max_time"] == 77
  end

  test "try updating key with wrong type" do
    name = "update_wrong_type"
    :ok = Storage.insert_key(name, "numeric")
    {:error, :type_mismatch} = Storage.update_key(name, "boolean")
  end

  # Storing values

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

  test "try to insert invalid key type" do
    {:error, _} = Storage.insert_key("invalid_type", "foo")
  end

  # Opts

  test "store key opts" do
    :ok = Storage.insert_key("keyopts", "numeric", %{"foo" => 123})
    %{opts: %{"foo" => 123}} = Storage.list_keys["keyopts"]
  end

  test "append default opts" do
    :ok = Storage.insert_key("keyopts_uptime", "uptime")
    %{opts: %{"max_time" => 60}} = Storage.list_keys["keyopts_uptime"]
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

  # Uptime

  test "uptime key changes to false" do
    :ok = Storage.insert_key("uptime_change", "uptime", %{"max_time" => 0.1})
    :ok = Storage.put("uptime_change", true)
    assert Storage.get("uptime_change") == true
    100 |> :timer.sleep
    assert Storage.get("uptime_change") == false
  end

  test "uptime bump stops it from changing to false" do
    :ok = Storage.insert_key("uptime_change2", "uptime", %{"max_time" => 0.1})
    :ok = Storage.put("uptime_change2", true)
    assert Storage.get("uptime_change2") == true
    50 |> :timer.sleep
    :ok = Storage.put("uptime_change2", true)
    50 |> :timer.sleep
    assert Storage.get("uptime_change2") == true
    50 |> :timer.sleep
    assert Storage.get("uptime_change2") == false
  end

  test "uptime handled proprly on init" do
    :ok = Storage.insert_key("uptime_change3", "uptime", %{"max_time" => 0.1})
    :ok = Storage.put("uptime_change3", true)
    Process.exit(Komoku.KeyMaster |> Process.whereis, :kill) # KILL THE MASTER ! Which will also key key handlers
    100 |> :timer.sleep
    assert Storage.get("uptime_change3") == false
  end

  # TODO test for same_value_resultion and min_resolution, we need to have access to number of stored data points for that

  defp has_key?(name) do
    Storage.list_keys |> Enum.any?(fn {k, _v} -> k == name end) == true
  end

  defp has_key?(name, type) do
    Storage.list_keys |> Enum.any?(fn {k, %{type: type_}} -> k == name && type_ == type end) == true
  end
end
