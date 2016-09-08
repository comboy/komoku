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
      worker(Komoku.SubscriptionManager, []),
      supervisor(Komoku.Stats, []), # TODO add abilitity to disable it in config, all collection are casts so that's not a poblem, just need some error messages for retrievieng
      supervisor(Komoku.Storage, []),
      supervisor(Komoku.Server, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Komoku.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
