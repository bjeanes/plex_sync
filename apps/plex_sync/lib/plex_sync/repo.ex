defmodule PlexSync.Repo do
  use Ecto.Repo,
    otp_app: :plex_sync,
    adapter: Ecto.Adapters.Postgres
end
