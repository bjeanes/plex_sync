defmodule PlexSync.PMS do
  @moduledoc """
  The module for the API to a PlexMediaServer
  """

  @enforce_keys [:id, :owner, :name, :host, :token]
  defstruct [:id, :owner, :name, :host, :token, port: 32_400, scheme: "http"]

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

        eligible_sections

      {:error, e} ->
        IO.puts("#{server.name} unable to be connected: #{e.reason}")
        []
    end
  end

  @doc """
  Returns media items from the PMS in the given section, ordered by most recently watched.
  """
  def media(%__MODULE__{} = server, %{"key" => key}) do
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

  def media_items(%__MODULE__{} = server) do
    GenServer.call(server, :show_state)
  end

  use GenServer

  def child_spec([%__MODULE__{id: id, name: name}] = server) do
    %{
      id: id,
      name: name,
      start: {__MODULE__, :start_link, server}
    }
  end

  def start_link(%__MODULE__{} = server) do
    GenServer.start_link(__MODULE__, server)
  end

  @impl true
  def init(%__MODULE__{} = server) do
    {
      :ok,
      %{server: server, fetcher: nil, media_items: []},
      {:continue, :start_fetch}
    }
  end

  @impl true
  def handle_continue(:start_fetch, state) do
    parent = self()

    {:ok, pid} =
      Supervisor.start_link(
        [
          {Task,
           fn ->
             sections(state.server)
             |> Enum.map(fn section ->
               media(state.server, section)
               |> Enum.map(fn media ->
                 GenServer.cast(parent, {:add_item, media})
               end)
             end)
           end}
        ],
        strategy: :one_for_one
      )

    {:noreply, %{state | fetcher: pid}}
  end

  @impl true
  def handle_cast({:add_item, %PlexSync.PMS.Media{} = media}, state) do
    new_state = %{state | media_items: [media | state[:media_items]]}
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:show_state, _from, state) do
    {:reply, state, state}
  end
end
