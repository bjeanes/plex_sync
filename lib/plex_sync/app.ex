defmodule PlexSync.App do
  use Application
  # use Supervisor

  def start(_type, _args) do
    IO.puts("Starting...")
    Supervisor.start_link([], strategy: :one_for_one)
  end

  def init(_) do
    {:ok}
  end
end
