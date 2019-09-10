defmodule PlexSyncWeb.SyncLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <p><%= @user["uuid"] %></p>
    <pre><%= inspect assigns, pretty: true %></pre>
    """
  end

  def mount(%{user: user}, socket) do
    {:ok, assign(socket, user: user)}
  end

end
