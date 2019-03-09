defmodule PlexSync.PMS do
  @moduledoc """
  The module for the API to a PlexMediaServer
  """

  @enforce_keys [:name, :host, :token]
  defstruct [:name, :host, :token, port: 32_400, scheme: "http"]

  @doc """
  Returns eligible sections from the specified PMS
  """
  def sections(%__MODULE__{} = server) do
    case(PlexSync.Client.get({server, "/library/sections"})) do
      {:ok, %HTTPoison.Response{body: {"MediaContainer", _, sections}}} ->
        eligible_sections =
          sections
          |> Enum.map(fn {"Directory", attrs, _} -> Map.new(attrs) end)
          |> Enum.filter(fn %{"type" => t} -> Enum.member?(["show", "movie"], t) end)

        {:ok, eligible_sections}
    end
  end

  def media(%__MODULE__{} = server, %{"key" => key}) do
    PlexSync.Client.stream({server, "/library/sections/#{key}/allLeaves?sort=lastViewedAt:desc"})
    |> Stream.map(fn {_node, attrs, _children} ->
      media = PlexSync.Media.of(attrs)
      attrs = Map.new(attrs)

      %PlexSync.PMS.Media{
        pms: server,
        item: media,
        key: attrs["key"],
        rating_key: attrs["ratingKey"],
        watched: String.to_integer(Map.get(attrs, "viewCount", "0")) > 0
      }
    end)
  end
end
