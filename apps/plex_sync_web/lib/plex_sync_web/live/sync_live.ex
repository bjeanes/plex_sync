defmodule PlexSyncWeb.SyncLive do
  use Phoenix.LiveView

  alias PlexSync.Syncer

  def render(assigns) do
    Phoenix.View.render(PlexSyncWeb.PageView, "index.html", assigns)
  end

  def mount(%{user: user}, socket) do
    if connected?(socket), do: :timer.send_interval(5000, self(), :update)
    {:ok, _pid} = PlexSync.Syncer.find_or_start(user)
    {:ok, assign(socket, user: user, syncer: get_syncer_status(user))}
  end

  def handle_info(:update, %{assigns: %{user: user}} = socket) do
    {:noreply, assign(socket, syncer: get_syncer_status(user))}
  end

  defp get_syncer_status(user) do
    %{servers: Syncer.status(user)}
  end
end
