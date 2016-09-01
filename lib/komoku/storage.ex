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

  # TODO find a good place to put doc about types and opts (some opts are common)
  #
  # Add a new key. TODO proper docs, here are available opts to have them in one place:
  # * same_value_resolution - update to key with same value won't be stored in db until time difference is greater than this value [seconds, can be float]
  # * min_resolution - if multiple values will be pushed within that time, only one value will be stored in db [seconds, can be float] - we probably want e.g. averaging for numeric
  #
  # type specific:
  # * uptime
  # ** max_time - time after which value automatically goes to false [seconds, can be float]
  def insert_key(name, type, opts \\ %{}), do: KM.insert(name, type, opts)
  def update_key(name, type, opts \\ %{}), do: KM.update(name, type, opts)

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
            put(name, value, time)
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

