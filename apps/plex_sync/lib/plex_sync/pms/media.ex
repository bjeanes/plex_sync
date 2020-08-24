defmodule PlexSync.PMS.Media do
  @enforce_keys [:pms, :item, :watched, :key, :rating_key]
  defstruct [:pms, :item, :watched, :key, :rating_key]

  defimpl String.Chars, for: __MODULE__ do
    def to_string(media) do
      "#{media.item} on PMS #{media.pms}"
    end
  end

  def mark_watched!(%__MODULE__{watched: watched} = media) do
    if not watched do
      # TODO
      {:TODO, %__MODULE__{media | watched: true}}
    else
      :noop
    end
  end
end
