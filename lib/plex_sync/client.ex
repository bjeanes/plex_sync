defmodule PlexSync.Client do
  @moduledoc """
  Wrapper for HTTPotion to do XML de-structuring etc
  """

  use HTTPoison.Base

  def headers do
    [
      {"X-Plex-Client-Identifier", Application.get_env(:plex_sync, :plex_client_id)},
      {"X-Plex-Product", "PlexSync"},
      {"X-Plex-Version", List.to_string(Application.spec(:plex_sync, :vsn))},
      {"X-Plex-Platform", "Elixir"},
      {"X-Plex-Platform-Version", System.version()}
    ]
  end

  @doc """
  Returns a Stream of all `MediaContainer` contents for endpoint until exhausted
  """
  def stream(url, headers \\ [], options \\ []) do
    Stream.resource(
      fn -> {0, nil} end,
      fn
        {start, total} when start >= total ->
          {:halt, {start, total}}

        {start, total} ->
          total = total || 0

          case(
            get(
              url,
              headers,
              options ++
                [
                  params: %{
                    "X-Plex-Container-Size" => 300,
                    "X-Plex-Container-Start" => start
                  }
                ]
            )
          ) do
            {:ok, %HTTPoison.Response{body: body}} ->
              {"MediaContainer", attrs, items} = body
              {new_total, _} = Integer.parse(Map.new(attrs)["totalSize"])
              new_total = [total, new_total] |> Enum.reject(&is_nil/1) |> Enum.max()
              count = Enum.count(items)

              state = {start + count, new_total}

              if count > 0 do
                {items, state}
              else
                {:halt, state}
              end

            state ->
              {:halt, state}
          end
      end,
      fn _ -> :ok end
    )
  end

  # Override request and call super after pre-processing, for two reasons:
  #
  # 1. HTTPoison calls to_string/1 on the `url` before calling `process_request_url` so we can't
  #    transform our PMS struct into a URL in that callback.
  # 2. There is no callback to allow setting headers based on such a "endpoint" struct anyway
  def request(
        %HTTPoison.Request{
          url: {%PlexSync.PMS{scheme: scheme, host: host, port: port, token: token}, "/" <> path},
          headers: headers
        } = request
      ) do
    url = "#{scheme}://#{host}:#{port}/#{path}"

    headers =
      if is_nil(headers) do
        [{"X-Plex-Token", token}]
      else
        [{"X-Plex-Token", token} | headers]
      end

    request = %HTTPoison.Request{request | url: url, headers: headers}

    super(request)
  end

  def request(request), do: super(request)

  # def process_request_url({
  #       %PlexSync.PMS{scheme: scheme, host: host, port: port},
  #       "/" <> path
  #     }) do
  #   "#{scheme}://#{host}:#{port}/#{path}"
  # end

  # If not passing a PMS struct, assume this is destined for plex.tv API
  def process_request_url("/" <> path) when is_bitstring(path) do
    "https://plex.tv/#{path}"
  end

  def process_request_url(path), do: path

  def process_response_body(body) do
    {:ok, parsed_body} =
      body
      |> Saxy.SimpleForm.parse_string()

    parsed_body
  end

  def process_request_headers(headers) when is_map(headers) do
    Enum.into(headers, __MODULE__.headers())
  end

  def process_request_headers(headers) when is_nil(headers) do
    headers()
  end

  def process_request_headers(headers) when is_list(headers) do
    headers() ++ headers
  end

  def process_request_headers(headers), do: headers
end
