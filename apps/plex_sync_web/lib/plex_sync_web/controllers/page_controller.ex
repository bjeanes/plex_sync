defmodule PlexSyncWeb.PageController do
  use PlexSyncWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
