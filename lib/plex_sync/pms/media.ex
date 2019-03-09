defmodule PlexSync.PMS.Media do
  @enforce_keys [:pms, :item, :watched, :key, :rating_key]
  defstruct [:pms, :item, :watched, :key, :rating_key]
end
