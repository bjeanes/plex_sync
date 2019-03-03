defmodule PlexSync.App do
  use Application

  def start(_type, _args) do
    IO.puts("Starting...")
    Supervisor.start_link([], strategy: :one_for_one)
    # Supervisor.start_link(__MODULE__, [])
  end
end
