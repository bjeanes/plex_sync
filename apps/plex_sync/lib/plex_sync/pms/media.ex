defmodule PlexSync.PMS.Media do
  @enforce_keys [:pms, :item, :watched, :key, :rating_key]
  defstruct [:pms, :item, :watched, :key, :rating_key]

  defimpl String.Chars, for: __MODULE__ do
    def to_string(media) do
      "#{media.item} on PMS #{media.pms}"
    end
  end
end
