defmodule PlexSync.PlexTV do
  @moduledoc """
  The module for the API to Plex.tv
  """

  def servers(token) do
    case(request(token, :get, "/pms/servers")) do
      {:ok, %HTTPoison.Response{body: body, status_code: code}} when code in 200..299 ->
        {"MediaContainer", _, servers_data} = body

        servers =
          servers_data
          |> Enum.map(fn {"Server", attrs_list, _} ->
            attrs = Map.new(attrs_list)

            %PlexSync.PMS{
              id: attrs["machineIdentifier"],
              owner: %{
                id: attrs["ownerId"],
                name: attrs["sourceTitle"]
              },
              token: attrs["accessToken"],
              name: attrs["name"],
              host: attrs["host"],
              port: attrs["port"],
              scheme: attrs["scheme"]
            }
          end)

        {:ok, servers}

      {:ok, %HTTPoison.Response{body: raw_body} = response} ->
        case Saxy.SimpleForm.parse_string(raw_body) do
          {:ok, body} ->
            {:error, %HTTPoison.Response{response | body: body}}

          _ ->
            {:error, response}
        end
    end
  end

  def get_user(username, password) do
    case(
      PlexSync.Client.post(
        "/users/sign_in.xml",
        "",
        [],
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

  # https://github.com/tidusjar/Ombi/issues/2894#issuecomment-477404691
  def create_pin do
    case(PlexSync.Client.post("/api/v2/pins.xml?strong=true", "")) do
      {:ok, %HTTPoison.Response{body: {"pin", pin, _}}} ->
        pin = Map.new(pin)

        %{
          id: String.to_integer(pin["id"]),
          code: pin["code"],
          client_id: pin["clientIdentifier"],
        }
    end
  end

  # https://github.com/tidusjar/Ombi/issues/2894#issuecomment-477404691
  def exchange_pin(pin_id) do
    case(PlexSync.Client.get("/api/v2/pins/#{pin_id}.xml")) do
      {:ok, %HTTPoison.Response{body: {"pin", pin, _}}} ->
        pin = Map.new(pin)

        %{
          id: String.to_integer(pin["id"]),
          code: pin["code"],
          client_id: pin["clientIdentifier"],
          token: pin["authToken"],
        }
    end
  end

  defp request(token, method, "/" <> path) do
    PlexSync.Client.request(method, "/#{path}", "", [{"X-Plex-Token", token}])
  end
end