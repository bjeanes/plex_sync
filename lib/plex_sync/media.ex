defmodule PlexSync.Media do
  def of(attrs) when is_list(attrs) do
    attrs
    |> Map.new()
    |> ProperCase.to_snake_case()
    |> of()
  end

  def of(%{"type" => "episode"} = attrs) do
    {episode, ""} = Integer.parse(attrs["index"])
    {season, ""} = Integer.parse(attrs["parent_index"])
    {year, ""} = Integer.parse(attrs["year"])

    %PlexSync.Media.Episode{
      key: attrs["key"],
      rating_key: attrs["rating_key"],
      title: attrs["title"],
      episode: episode,
      season: season,
      show: attrs["grandparent_title"],
      year: year
    }
  end

  def of(%{"type" => "movie"} = attrs) do
    {year, ""} = Integer.parse(attrs["year"])

    %PlexSync.Media.Movie{
      key: attrs["key"],
      rating_key: attrs["rating_key"],
      title: attrs["title"],
      year: year
    }
  end
end
