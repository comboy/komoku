defmodule Komoku.KeyMasterTest do
  use ExUnit.Case

  alias Komoku.Server
  alias Komoku.KeyMaster

  # Basic operations only have acceptance tests through Komoku.Server

  test "stats" do
    Server.insert_key("km_stats", "numeric")
    %{active: active, total: total} = KeyMaster.stats
    assert total > 0
    Server.put("km_stats2", 77)
    %{active: new_active, total: new_total} = KeyMaster.stats
    assert new_active == active + 1
    assert new_total == total + 1
  end

  test "restarting handlers" do
    Server.put("km_sup", 123)
    pid = KeyMaster.handler("km_sup")
    pid |> Process.exit(:kill)
    10 |> :timer.sleep # plenty of time to restart ;)
    assert 123 == Server.get("km_sup")
  end

  # KM should not be restarted when KH dies
  test "supervision" do
    km_pid = Process.whereis(Komoku.KeyMaster)
    Server.put("km_sup2", 123)
    pid = KeyMaster.handler("km_sup2")
    pid |> Process.exit(:kill)
    10 |> :timer.sleep
    assert 123 == Server.get("km_sup2")
    assert Process.whereis(Komoku.KeyMaster) == km_pid
  end

end

