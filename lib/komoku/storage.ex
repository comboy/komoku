defmodule Komoku.Storage do
  alias Komoku.Storage.Repo
  alias Komoku.Util
  alias Komoku.KeyMaster, as: KM # TODO KM and KH look too much alike, use different aliases
  alias Komoku.KeyHandler, as: KH


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
  def delete_key(name), do: KM.delete(name)

  def list_keys do
    KM.list |> Enum.map(fn {key, opts} ->
      {key, opts |> Map.delete(:handler)}
    end)
    |> Enum.into(%{})
  end

  def put(name, value), do: put(name, value, Util.ts)

  def put(name, value, time) do
    case KM.handler(name) do
      nil ->
        case guess_type(value) do
          "unknown" -> 
            {:error, :unknown_value_type}
          type ->
            insert_key(name, type)
            put(name, value)
        end
      handler ->
        handler |> KH.put(value, time)
    end
  end

  def get(name) do
    case last(name) do
      nil -> nil
      {value, _time} -> value
    end
  end

  def last(name) do
    case KM.handler(name) do
      nil -> nil
      pid ->  KH.last(pid)
    end
  end

  defp guess_type(value) when is_number(value), do: "numeric"
  defp guess_type(value) when is_boolean(value), do: "boolean"
  defp guess_type("true"), do: "boolean"
  defp guess_type("false"), do: "boolean"
  defp guess_type(str) when is_binary(str), do: "string"
  defp guess_type(_), do: "unknown"

end

