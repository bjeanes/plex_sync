defmodule PlexSync.Media.Movie do
  @enforce_keys [:key, :rating_key, :title, :year]
  defstruct [:key, :rating_key, :title, :year]

  defimpl String.Chars, for: __MODULE__ do
    def to_string(movie) do
      "#{movie.title} (#{movie.year})"
    end
  end
end
