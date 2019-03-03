defmodule PlexSync do
  def headers do
    [
      {"X-Plex-Client-Identifier", Application.get_env(:plex_sync, :plex_client_id)},
      {"X-Plex-Product", "PlexSync"},
      {"X-Plex-Version", List.to_string(Application.spec(:plex_sync, :vsn))},
      {"X-Plex-Platform", "Elixir"},
      {"X-Plex-Platform-Version", System.version()}
    ]
  end

  def get_user(username, password) do
    case(
      PlexSync.Client.post(
        "https://plex.tv/users/sign_in.xml",
        "",
        headers(),
        hackney: [basic_auth: {username, password}]
      )
    ) do
      {:ok, %HTTPoison.Response{status_code: 422}} ->
        {:bad_request}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:unauthorized}

      {:ok, %HTTPoison.Response{body: {"user", user, _}}} ->
        user = user |> Map.new() |> ProperCase.to_snake_case()
        {:ok, user}
    end
  end
end
