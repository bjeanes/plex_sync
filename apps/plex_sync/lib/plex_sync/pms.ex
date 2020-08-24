defmodule PlexSync.PMS do
  @moduledoc """
  The module for the API to a PlexMediaServer
  """

  @enforce_keys [:id, :owner, :name, :addresses, :token]
  defstruct [:id, :owner, :name, :addresses, :token]

  require Logger
  alias PlexSync.Client

  defimpl String.Chars, for: __MODULE__ do
    def to_string(pms) do
      pms.name
    end
  end

  @doc """
  Returns eligible sections from the specified PMS
  """
  def sections(%__MODULE__{} = server) do
    Logger.debug("Getting media sections for PMS #{server}")

    case(PlexSync.Client.get({server, "/library/sections"})) do
      {:ok, %HTTPoison.Response{body: {"MediaContainer", _, sections}}} ->
        eligible_sections =
          sections
          |> Enum.map(fn {"Directory", attrs, _} -> Map.new(attrs) end)
          |> Enum.filter(fn %{"type" => t} -> Enum.member?(["show", "movie"], t) end)

        eligible_sections

      {:error, e} ->
        Logger.error("#{server} unable to be connected: #{e.reason}")
        []
    end
  end

  @doc """
  Returns media items from the PMS in the given section, ordered by most recently watched.
  """
  def media(%__MODULE__{} = server, %{"key" => key, "type" => type}) do
    Logger.debug("Getting media for #{type} section #{key} for PMS #{server}")

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
