defmodule Komoku.Util.PerformanceTest do
  alias Komoku.Storage

  def bench do
    storage_get
    network_get
  end

  def storage_get do
    fun_prep = fn -> :ok end
    fun = fn(_, key) -> 
      value = Storage.get(key) 
      true = value > 0 && value < 1001
    end
    multi_client(:storage_get, fun_prep, fun)
  end

  def network_get do
    fun_prep = fn ->
      {:ok, socket} = Socket.Web.connect("127.0.0.1", 4545)
      socket
    end

    fun = fn(socket, key) ->
      socket |> Socket.Web.send!({:text, %{get: %{key: key}} |> Poison.encode!})
      {:text, reply} = socket |> Socket.Web.recv!
      value = reply |> Poison.decode!
      true = value > 0 && value < 1001
    end

    multi_client(:network_get, fun_prep, fun)
  end

  def multi_client(name, fun_prep, fun) do
    num_keys = 20
    num_values = 100
    num_clients = 100
    num_loops = 100

    # prepare data
    (1..num_keys) |> Enum.each(fn i ->
      key = "test.perf_get_#{i}"
      Storage.insert_key(key, "numeric")
      (0..num_values) |> Enum.each(fn _i -> Storage.put(key, :rand.uniform(1000)) end)
    end)

    t0 = :os.system_time(:milli_seconds)

    # run test
    (0..num_clients) |> Enum.map(fn _ ->
      Task.async(fn ->
        # Test with network stack
        client = fun_prep.()

        shift = :rand.uniform(num_keys)
        (0..num_loops) |> Enum.each(fn _ ->
          (1..num_keys) |> Enum.each(fn i ->
            key = "test.perf_get_#{rem(i + shift, num_keys)+1}"
            fun.(client, key)
          end)
        end)
      end)
    end)
    |> Enum.map(fn task -> Task.await(task, 60_000) end)

    dt = :os.system_time(:milli_seconds) - t0
    (1..num_keys) |> Enum.each(fn i ->
      key = "test.perf_get_#{i}"
      Storage.delete_key(key)
    end)

    ops = num_clients * num_loops * num_keys
    IO.puts ":#{name} perf test: #{dt |> round} ms = #{Float.round(ops / (dt / 1000),2)} ops/sec"
  end
end
