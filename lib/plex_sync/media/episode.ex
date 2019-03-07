defmodule PlexSync.Media.Episode do
  @enforce_keys [:key, :rating_key, :title, :season, :show, :episode, :year]
  defstruct [:key, :rating_key, :title, :season, :show, :episode, :year]

  defimpl String.Chars, for: __MODULE__ do
    def to_string(episode) do
      ep = episode.episode |> Kernel.to_string() |> String.pad_leading(2, "0")

      "#{episode.show} (#{episode.year}) - S#{episode.season}E#{ep} - #{episode.title}"
    end
  end
end
