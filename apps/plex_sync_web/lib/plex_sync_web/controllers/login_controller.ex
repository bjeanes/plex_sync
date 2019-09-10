defmodule PlexSyncWeb.LoginController do
  use PlexSyncWeb, :controller

  def index(conn, _params) do
    %{id: pin_id, code: code, client_id: client_id} = PlexSync.PlexTV.create_pin()

    callback_url = PlexSyncWeb.Router.Helpers.login_url(conn, :callback, pin_id: pin_id)

    plex_login_query =
      Plug.Conn.Query.encode(%{
        clientID: client_id,
        forwardUrl: callback_url,
        code: code,
        context: %{
          device: %{
            product: PlexSync.Client.headers()["X-Plex-Product"],
            version: PlexSync.Client.headers()["X-Plex-Version"],
            platform: PlexSync.Client.headers()["X-Plex-Platform"],
            platformVersion: PlexSync.Client.headers()["X-Plex-Platform-Version"],
            device: PlexSync.Client.headers()["X-Plex-Device"],
            protocol: "https",
            model: "hosted",
            layout: "desktop",
            environment: "bundled"
          }
        }
      })

    plex_login_url = "https://app.plex.tv/auth/#!?#{plex_login_query}"
    redirect(conn, external: plex_login_url)
  end

  def callback(conn, %{"pin_id" => pin_id}) do
    case(PlexSync.PlexTV.exchange_pin(pin_id)) do
      %{token: nil} -> conn |> put_status(:unauthorized) |> text("Unauthorized")
      %{token: token} ->
        { :ok, user } = PlexSync.PlexTV.get_current_user(token)
        conn
        |> put_session(:user, user |> Poison.encode!)
        |> redirect(to: "/")
    end
  end
end
