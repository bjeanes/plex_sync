defmodule PlexSync.PlexTv do
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

  defp request(token, method, "/" <> path) do
    PlexSync.Client.request(method, "https://plex.tv/#{path}", "", [{"X-Plex-Token", token}])
  end
end
