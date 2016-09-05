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

end

