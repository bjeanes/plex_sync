defmodule PlexSyncWeb.Router do
  use PlexSyncWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug Phoenix.LiveView.Flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PlexSyncWeb do
    pipe_through :browser

    get "/login", LoginController, :index
    get "/login/callback", LoginController, :callback
    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", PlexSyncWeb do
  #   pipe_through :api
  # end
end
