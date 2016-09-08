defmodule Komoku.KeyMaster.Supervisor do
  use Supervisor

  # TODO Maybe plug KeyMaster in the main supervision tree and mke this KeyHandler.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_kh(name, params) do
    Supervisor.start_child(__MODULE__, worker(Komoku.KeyHandler, [name, params], id: "kh_#{name}"))
  end

  def stop_kh(name) do
    :ok = Supervisor.terminate_child(__MODULE__, "kh_#{name}")
    :ok = Supervisor.delete_child(__MODULE__, "kh_#{name}")
  end

  def init([]) do
    children = [
      worker(Komoku.KeyMaster, [])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
