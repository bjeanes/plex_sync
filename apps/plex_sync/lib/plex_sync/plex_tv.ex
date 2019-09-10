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

            default_port = attrs["port"]

            # Plex returns entries that have both a top-level address and a
            # list of "local addresses". We want to try connecting to all of
            # these, so we'll flatten them into a single list that we can use
            # to try different connections with.
            addresses =
              attrs["localAddresses"]
              |> String.split(",", trim: true)
              |> Enum.map(&String.split(&1, ":"))
              |> List.insert_at(0, [attrs["host"]])
              |> Enum.map(fn
                [host] -> "http://#{host}:#{default_port}/"
                [host, port] -> "http://#{host}:#{port}/"
              end)
              |> Enum.map(&URI.parse/1)

            %PlexSync.PMS{
              id: attrs["machineIdentifier"],
              owner: %{
                id: attrs["ownerId"],
                name: attrs["sourceTitle"]
              },
              token: attrs["accessToken"],
              name: attrs["name"],
              addresses: addresses
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

  # {:ok,
  #  %{
  #    "auth_token" => "REDACTED",
  #    "authentication_token" => "REDACTED",
  #    "certificate_version" => "2",
  #    "cloud_sync_device" => "",
  #    "email" => "me@bjeanes.com",
  #    "guest" => "0",
  #    "has_password" => "true",
  #    "home" => "1",
  #    "home_size" => "1",
  #    "id" => "5618",
  #    "locale" => "en-GB",
  #    "mailing_list_status" => "active",
  #    "max_home_size" => "15",
  #    "pin" => "REDACTED",
  #    "queue_email" => "REDACTED",
  #    "queue_uid" => "REDACTED",
  #    "remember_me" => "false",
  #    "restricted" => "0",
  #    "scrobble_types" => "",
  #    "secure" => "1",
  #    "thumb" => "https://plex.tv/users/f71ec2b78f9bee36/avatar?c=1566947739",
  #    "title" => "bjeanes",
  #    "username" => "bjeanes",
  #    "uuid" => "f71ec2b78f9bee36"
  #  }}
  def get_current_user(token) do
    case PlexSync.Client.get("/users/account", [{"X-Plex-Token", token}]) do
      {:ok, %HTTPoison.Response{body: {"user", user, _}}} ->
        {:ok, user |> Map.new() |> ProperCase.to_snake_case()}

      other ->
        other
    end
  end

  # {:ok,
  #  %{
  #    "auth_token" => "REDACTED",
  #    "authentication_token" => "REDACTED",
  #    "certificate_version" => "2",
  #    "cloud_sync_device" => "",
  #    "email" => "me@bjeanes.com",
  #    "guest" => "0",
  #    "has_password" => "true",
  #    "home" => "1",
  #    "home_size" => "1",
  #    "id" => "5618",
  #    "locale" => "en-GB",
  #    "mailing_list_status" => "active",
  #    "max_home_size" => "15",
  #    "pin" => "REDACTED",
  #    "queue_email" => "REDACTED",
  #    "queue_uid" => "REDACTED",
  #    "remember_me" => "false",
  #    "restricted" => "0",
  #    "scrobble_types" => "",
  #    "secure" => "1",
  #    "thumb" => "https://plex.tv/users/f71ec2b78f9bee36/avatar?c=1566947739",
  #    "title" => "bjeanes",
  #    "username" => "bjeanes",
  #    "uuid" => "f71ec2b78f9bee36"
  #  }}
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
          client_id: pin["clientIdentifier"]
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
          token: pin["authToken"]
        }
    end
  end

  defp request(token, method, "/" <> path) do
    PlexSync.Client.request(method, "/#{path}", "", [{"X-Plex-Token", token}])
  end
end
