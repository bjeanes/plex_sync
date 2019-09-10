defmodule PlexSync.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      PlexSync.Repo,
      # {Registry, keys: :unique, name: PlexSync.SyncerRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: PlexSync.SyncerSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: PlexSync.Supervisor)
  end
end
