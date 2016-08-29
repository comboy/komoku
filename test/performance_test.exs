defmodule Komoku.PerformanceTest do
  use ExUnit.Case, async: false

  @moduletag :performance

  alias Komoku.Storage

  test "get" do
    num_keys = 20
    num_values = 100
    num_clients = 100
    num_loops = 10

    # prepare data
    (1..num_keys) |> Enum.each(fn i ->
      key = "perf_get_#{i}"
      Storage.insert_key(key, "numeric")
      (0..num_values) |> Enum.each(fn _i -> Storage.put(key, :rand.uniform(1000)) end)
    end)

    t0 = :os.system_time(:milli_seconds)

    # run test
    (0..num_clients) |> Enum.map(fn _ ->
      Task.async(fn ->
        {:ok, socket} = Socket.Web.connect("127.0.0.1", 4545)
        shift = :rand.uniform(num_keys)
        (0..num_loops) |> Enum.each(fn _ ->
          (1..num_keys) |> Enum.each(fn i ->
            key = "perf_get_#{rem(i + shift, num_keys)+1}"
            socket |> Socket.Web.send!({:text, %{get: %{key: key}} |> Poison.encode!})
            {:text, reply} = socket |> Socket.Web.recv!
            value = reply |> Poison.decode!
            assert value > 0
            assert value < 1001
          end)
        end)
      end)
    end)
    |> Enum.map(fn task -> Task.await(task, 60_000) end)

    dt = :os.system_time(:milli_seconds) - t0
    IO.puts "\nGet perf test: #{dt |> round} ms"
  end

end