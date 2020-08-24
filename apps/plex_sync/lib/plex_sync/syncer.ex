defmodule PlexSync.Syncer do
  @moduledoc """
  Starts syncing for a specific plex account. Acts as a standalone process and also as a
  supervisor for each PMS endpoint the user has access to.
  """

  use GenServer

  require Logger
  alias PlexSync.{PMS, PlexTV}
  alias PlexSync.PMS.Media

  def find_or_start({user, password}) when is_bitstring(user) and is_bitstring(password) do
    {:ok, user} = PlexTV.get_user(user, password)
    find_or_start(user)
  end

  def find_or_start(token) when is_bitstring(token) do
    {:ok, user} = PlexTV.get_current_user(token)
    find_or_start(user)
  end

  def find_or_start(%{} = user) do
    result =
      DynamicSupervisor.start_child(
        PlexSync.SyncerSupervisor,
        {__MODULE__, user}
      )

    case result do
      {:ok, _} -> result
      {:error, {:already_started, current_pid}} -> {:ok, current_pid}
      _ -> result
    end
  end

  def pid(%{} = user) do
    GenServer.whereis(name_for(user))
  end

  def status(%{} = user) do
    case pid(user) do
      nil -> nil
      pid -> GenServer.call(pid, :status)
    end
  end

  def mark_watched(pid, media) do
    GenServer.cast(pid, {:mark_watched, media})
  end

  def find_or_start_server_syncer(%{user: user} = state, %PMS{} = server) do
    Logger.debug("Finding or starting PMS syncer for #{server}")

    case(
      DynamicSupervisor.start_child(
        name_for(user, PlexSync.PMS.Supervisor),
        {PMS.Syncer, {server, name_for(state), [name: name_for(state, {PMS.Syncer, server.id})]}}
      )
    ) do
      {:error, {:already_started, pid}} ->
        Logger.debug("PMS Syncer for #{server} already started: #{inspect(pid)}")
        {:ok, pid}

      {:ok, pid} ->
        Logger.debug("Started PMS Syncer for #{server}: #{inspect(pid)}")
        {:ok, pid}

      :ignore ->
        :ignore

      {:error, reason} ->
        Logger.error("Unable to establish connection to PMS #{server}: #{inspect(reason)}")
        {:error, reason}

      result ->
        Logger.warn(
          "Unexpected message starting/finding PMS Syncer #{server}: #{inspect(result)}"
        )

        result
    end
  end

  def pid_name(pid, term) when is_pid(pid) do
    GenServer.call(pid, {:name_for, term})
  end

  defp name_for(state), do: name_for(state, PlexSync.Syncer)

  defp name_for(%{user: user}, term), do: name_for(user, term)

  defp name_for(%{"uuid" => uuid}, term) do
    {:global, {PlexSync.Syncer, {:user, uuid}, term}}
  end

  def start_link(%{} = user) do
    GenServer.start_link(__MODULE__, user, name: name_for(user))
  end

  def init(%{} = user) do
    Logger.info("Starting syncer for #{user["username"]}...")

    {:ok, _} =
      DynamicSupervisor.start_link(
        strategy: :one_for_one,
        name: name_for(user, PlexSync.PMS.Supervisor)
      )

    {
      :ok,
      %{user: user, servers: []},
      {:continue, :load_servers}
    }
  end

  def handle_call({:name_for, term}, _from, state) do
    {:reply, name_for(state, term), state}
  end

  def handle_call(:status, _from, %{servers: servers} = state) do
    servers =
      servers
      |> Enum.map(fn server ->
        case GenServer.whereis(name_for(state, {PlexSync.PMS.Syncer, server.id})) do
          nil -> {server, :down}
          pid -> {server, {:running, pid}}
        end
      end)
      |> Enum.into(%{})

    {:reply, servers, state}
  end

  def handle_cast({:add_server, pms}, %{servers: servers} = state) do
    spawn_link(fn -> find_or_start_server_syncer(state, pms) end)

    {:noreply, %{state | servers: [pms | servers]}}
  end

  def handle_cast({:mark_watched, %Media{} = _item}, state) do
    # TODO: send the item to all PMS which don't already have the item
    {:noreply, state}
  end

  def handle_continue(:load_servers, %{user: %{"auth_token" => token}} = state) do
    {:ok, servers} = PlexTV.servers(token)

    Enum.each(servers, fn pms ->
      spawn_link(fn ->
        GenServer.cast(name_for(state), {:add_server, pms})
      end)
    end)

    {:noreply, state}
  end
end
