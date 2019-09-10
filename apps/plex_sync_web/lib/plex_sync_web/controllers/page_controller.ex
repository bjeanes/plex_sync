defmodule PlexSyncWeb.PageController do
  use PlexSyncWeb, :controller

  def index(conn, _params) do
    case Poison.decode(get_session(conn, :user) || "foo") do
      {:ok, user} ->
        conn
        |> assign(:user, user)
        |> live_render(PlexSyncWeb.SyncLive, session: %{user: user})
      _ -> redirect(conn, to: "/login")
    end
  end
end
