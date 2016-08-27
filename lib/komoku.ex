defmodule Komoku do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Komoku.Worker.start_link(arg1, arg2, arg3)
      # worker(Komoku.Worker, [arg1, arg2, arg3]),
      supervisor(Komoku.Storage.Repo, []),
      supervisor(Komoku.Storage, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Komoku.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
