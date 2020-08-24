defmodule PlexSync.PMS.Syncer do
  @moduledoc """
  Per-PMS process to manage watch states for a specific user on that server.
  """

  require Logger
  alias PlexSync.{PMS, Client, Syncer}

  use GenServer

  def child_spec({%PMS{} = server, syncer, options}) do
    %{
      id: __MODULE__,
      start: {
        GenServer,
        :start_link,
        [__MODULE__, {server, syncer}, options]
      }
    }
  end

  @impl GenServer
  def init({%PMS{} = server, syncer}) do
    case valid_address(server) do
      {:ok, address} ->
        state = %{
          fetcher: nil,
          server: %PMS{server | addresses: [address]},
          syncer: syncer,
          media_items: []
        }

        {:ok, state, {:continue, :start_fetch}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_continue(:start_fetch, state) do
    parent = self()

    {:ok, pid} =
      Supervisor.start_link(
        [
          {Task,
           fn ->
             PMS.sections(state.server)
             |> Enum.map(fn section ->
               PMS.media(state.server, section)
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

  @impl GenServer
  def handle_cast(
        {:add_item, %PlexSync.PMS.Media{} = media},
        %{syncer: syncer, media_items: media_items} = state
      ) do
    # Logger.debug("Adding media item #{media} to PMS #{media.pms}")

    if media.watched do
      Syncer.mark_watched(syncer, media)
    end

    {:noreply, %{state | media_items: [media | media_items]}}
  end

  @impl GenServer
  def handle_call(:show_state, _from, state) do
    {:reply, state, state}
  end

  @doc """
  Determines (in parallel) which of a given PMS' addresses (as URIs) are
  accessible and returns the first one we can connect to.
  """
  def valid_address(%PMS{addresses: addresses} = server) when is_list(addresses) do
    addresses
    |> Task.async_stream(
      fn address ->
        Logger.debug("Trying to connect to #{server} on #{address.host}:#{address.port}")

        case(Client.get({%PMS{server | addresses: [address]}, "/"})) do
          {:ok, %HTTPoison.Response{status_code: code}} when code in 200..299 ->
            address

          _ ->
            nil
        end
      end,
      timeout: 2_000,
      on_timeout: :kill_task,
      # We care about the first one to connect, so we don't need to preserve order here
      ordered: false,
      # IO-heavy so this should be fine
      max_concurrency: System.schedulers_online() * 2
    )
    |> Enum.find_value({:error, :inaccessible}, fn
      x = {:ok, addr} when not is_nil(addr) -> x
      _ -> false
    end)
  end
end
