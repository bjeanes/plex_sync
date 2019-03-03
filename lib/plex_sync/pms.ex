defmodule PlexSync.PMS do
  @moduledoc """
  The module for the API to a PlexMediaServer
  """

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
    PlexSync.Client.stream({server, "/library/sections/#{key}/all?sort=lastViewedAt:desc"})
    |> Stream.map(fn {_, attrs, _children} ->
      Map.new(attrs)
      |> Map.take(["key", "lastViewedAt", "ratingKey", "title", "type", "viewCount", "year"])
      |> ProperCase.to_snake_case()
    end)
  end
end
