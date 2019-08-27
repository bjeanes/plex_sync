defmodule PlexSync.Media do
  def of(attrs) when is_list(attrs) do
    attrs
    |> Map.new()
    |> ProperCase.to_snake_case()
    |> of()
  end

  def of(%{"type" => "episode"} = attrs) do
    year =
      case(Integer.parse(attrs["year"] || "")) do
        {year, ""} -> year
        :error -> nil
      end

    if !attrs["index"] do
      # FIXME: not sure why index is sometimes missing or what to do about it when it happens
      nil
    else
      %PlexSync.Media.Episode{
        title: attrs["title"],
        episode: String.to_integer(attrs["index"]),
        season: String.to_integer(attrs["parent_index"]),
        show: attrs["grandparent_title"],
        year: year
      }
    end
  end

  def of(%{"type" => "movie"} = attrs) do
    year =
      case(Integer.parse(attrs["year"] || "")) do
        {year, ""} -> year
        :error -> nil
      end

    %PlexSync.Media.Movie{
      title: attrs["title"],
      year: year
    }
  end
end
