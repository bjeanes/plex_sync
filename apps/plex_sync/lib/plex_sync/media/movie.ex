defmodule PlexSync.Media.Movie do
  @enforce_keys [:title, :year]
  defstruct [:title, :year]

  defimpl String.Chars, for: __MODULE__ do
    def to_string(movie) do
      "#{movie.title} (#{movie.year})"
    end
  end
end
