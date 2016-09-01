defmodule Komoku.Mixfile do
  use Mix.Project

  def project do
    [app: :komoku,
     version: "0.1.0",
     elixir: "~> 1.3",
     aliases: aliases,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :postgrex, :cowboy],
     mod: {Komoku, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:ecto, "~> 2.0"}, # database ORM
     {:socket, "~> 0.3.5"},#, only: :test}, # testing websocket server, but also perf test
     {:cowboy, "~> 1.0", optional: true}, # websocket server
     {:poison, "~> 2.0"}, # JSON 
     {:postgrex, "0.11.2"}] # database driver
  end

  defp aliases, do: ["test": ["ecto.create --quiet", "ecto.migrate", "test"]]
end
