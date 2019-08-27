defmodule PlexSync.Syncer do
  @moduledoc """
  Starts syncing for a specific plex account. Acts as a standalone process and also as a
  supervisor for each PMS endpoint the user has access to.
  """

  use GenServer

  def start_link({user, password}) when is_bitstring(user) and is_bitstring(password) do
    %{"authToken" => token} = PlexSync.PlexTV.get_user(user, password)
    start_link(token)
  end

  def start_link(token) when is_bitstring(token) do
    GenServer.start_link(__MODULE__, token)
  end

  def init(token) do
    {
      :ok,
      %{token: token, supervisor: nil},
      {:continue, :start}
    }
  end

  def handle_continue(:start, %{token: token} = state) do
    {:ok, servers} = PlexSync.PlexTV.servers(token)

    {:ok, pid} =
      Supervisor.start_link(
        Enum.map(servers, fn pms -> {PlexSync.PMS, [pms]} end),
        strategy: :one_for_one
      )

    {:noreply, %{state | supervisor: pid}}
  end
end
