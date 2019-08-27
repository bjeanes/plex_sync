# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of Mix.Config.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
use Mix.Config

# Configure Mix tasks and generators
config :plex_sync,
  ecto_repos: [PlexSync.Repo],
  plex_client_id: "plexsync"

config :plex_sync_web,
  ecto_repos: [PlexSync.Repo],
  generators: [context_app: :plex_sync, binary_id: true]

# Configures the endpoint
config :plex_sync_web, PlexSyncWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "8z9DpspHJdib/zmh+dz69ye1rPlRvU86mo4hKlhNDyTwqSbBdra7s6xNERRjzaOH",
  render_errors: [view: PlexSyncWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: PlexSyncWeb.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
