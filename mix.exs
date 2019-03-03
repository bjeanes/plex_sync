defmodule PlexSync.MixProject do
  @moduledoc false

  use Mix.Project

  def project do
    [
      app: :plex_sync,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {PlexSync.App, []},
      # applications: [:httpoison, :proper_case],
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:saxy, "~> 0.9.1"},
      {:httpoison, "~> 1.4"},
      {:poison, "~> 3.1"},
      {:proper_case, "~> 1.0.2"},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
