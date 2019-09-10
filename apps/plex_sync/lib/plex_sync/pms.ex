defmodule PlexSync.PMS do
  @moduledoc """
  The module for the API to a PlexMediaServer
  """

  @enforce_keys [:id, :owner, :name, :addresses, :token]
  defstruct [:id, :owner, :name, :addresses, :token]

  require Logger
  alias PlexSync.Client

  defimpl String.Chars, for: __MODULE__ do
    def to_string(pms) do
      pms.name
    end
  end

  @doc """
  Returns eligible sections from the specified PMS
  """
  def sections(%__MODULE__{} = server) do
    Logger.debug("Getting media sections for PMS #{server}")

    case(PlexSync.Client.get({server, "/library/sections"})) do
      {:ok, %HTTPoison.Response{body: {"MediaContainer", _, sections}}} ->
        eligible_sections =
          sections
          |> Enum.map(fn {"Directory", attrs, _} -> Map.new(attrs) end)
          |> Enum.filter(fn %{"type" => t} -> Enum.member?(["show", "movie"], t) end)

        eligible_sections

      {:error, e} ->
        Logger.error("#{server} unable to be connected: #{e.reason}")
        []
    end
  end

  @doc """
  Returns media items from the PMS in the given section, ordered by most recently watched.
  """
  def media(%__MODULE__{} = server, %{"key" => key, "type" => type}) do
    Logger.debug("Getting media for #{type} section #{key} for PMS #{server}")

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

  def child_spec({%__MODULE__{} = server, syncer_pid, options}) do
    %{
      id: __MODULE__,
      start: {
        GenServer,
        :start_link,
        [__MODULE__, {server, syncer_pid}, options]
      }
    }
  end

  @impl true
  def init({%__MODULE__{addresses: []}, _}) do
    {:stop, :inaccessible}
  end

  @impl true
  def init({%__MODULE__{addresses: addresses} = server, syncer_pid}) do
    valid_addresses =
      addresses
      |> Task.async_stream(
        fn address ->
          Logger.debug("Trying to connect to #{server} on #{address.host}:#{address.port}")

          case(Client.get({%__MODULE__{server | addresses: [address]}, "/"})) do
            {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
              address

            _ ->
              nil
          end
        end,
        on_timeout: :kill_task,
        max_concurrency: System.schedulers_online() * 2
      )
      |> Stream.map(fn
        {:ok, nil} -> nil
        {:ok, address} -> address
        _ -> nil
      end)
      |> Stream.reject(&is_nil/1)

    if Enum.any?(valid_addresses) do
      {:ok,
       %{
         server: %__MODULE__{server | addresses: Enum.to_list(valid_addresses)},
         fetcher: nil,
         media_items: [],
         syncer_pid: syncer_pid
       }, {:continue, :start_fetch}}
    else
      {:stop, :inaccessible}
    end
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
    # Logger.debug("Adding media item #{media} to PMS #{media.pms}")
    new_state = %{state | media_items: [media | state[:media_items]]}
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:show_state, _from, state) do
    {:reply, state, state}
  end
end
