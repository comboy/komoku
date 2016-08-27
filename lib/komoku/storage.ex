defmodule Komoku.Storage do
  alias Komoku.Storage.Repo
  alias Komoku.Storage.Schema.Key
  alias Komoku.Storage.Schema.DataNumeric
  alias Komoku.Storage.KeyManager, as: KM
  import Ecto.Query

  def start_link do
    # TODO would love to know how to get rid of this from here,
    # test_helper gets evaluated after the application is already started
    if Mix.env == :test do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Komoku.Storage.Repo, {:shared, self()})
    end

    import Supervisor.Spec

    children = [
      worker(KM, [])
    ]
    opts = [strategy: :one_for_one, name: Komoku.Storage.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def insert_key(name, type), do: KM.insert(name, type)
  def list_keys, do: KM.list

  def put(name, value) do
    # TODO this should be happening in the key process
    case KM.get(name) do
      nil ->
        {:error, :key_not_found} # TODO guess key type and insert it
      key ->
        changeset = DataNumeric.changeset(%DataNumeric{}, %{value: value, key_id: key.id})
        case Repo.insert(changeset) do
          {:ok, _dN} -> :ok
          {:error, error} -> {:error, error}
        end
    end
  end

  def get(name) do
    case KM.get(name) do
      nil ->
        nil
      key ->
        # TODO case by key type
        (from p in DataNumeric, where: p.key_id == ^key.id, order_by: [desc: p.inserted_at])
          |> Repo.one
          |> Map.get(:value)
    end
  end

end
