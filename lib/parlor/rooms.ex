defmodule Parlor.Rooms do
  @moduledoc """
  Context for managing room processes and querying room state.
  """

  alias Parlor.Room
  alias Parlor.Rooms.Store

  @doc """
  Ensures a room process exists for the given room id.
  """
  @spec ensure_room(String.t()) :: {:ok, pid()} | {:error, term()}
  def ensure_room(room_id) when is_binary(room_id) do
    case Horde.Registry.lookup(Parlor.RoomRegistry, room_id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        case Horde.DynamicSupervisor.start_child(Parlor.RoomSupervisor, {Room, room_id}) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          other -> other
        end
    end
  end

  @doc """
  Broadcasts an event to all subscribers of a room topic.
  """
  @spec broadcast(String.t(), String.t(), map()) :: :ok | {:error, term()}
  def broadcast(room_id, event, payload)
      when is_binary(room_id) and is_binary(event) and is_map(payload) do
    with {:ok, _pid} <- ensure_room(room_id) do
      ParlorWeb.Endpoint.broadcast(topic(room_id), event, payload)
      :ok
    end
  end

  @doc """
  Returns room info including shared state and presence list.
  """
  @spec get_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_info(room_id) when is_binary(room_id) do
    case Horde.Registry.lookup(Parlor.RoomRegistry, room_id) do
      [{pid, _}] ->
        info = GenServer.call(pid, :info)
        presence = ParlorWeb.Presence.list(topic(room_id))

        {:ok,
         info
         |> Map.put(:presence, presence)
         |> Map.put(:online_count, map_size(presence))
         |> Map.put(:persisted, Store.persisted?(room_id))}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Lists all active rooms across the cluster.
  """
  @spec list() :: [map()]
  def list do
    Parlor.RoomRegistry
    |> Horde.Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.map(fn {room_id, pid} ->
      info = GenServer.call(pid, :info)

      %{
        id: room_id,
        member_count: info.member_count,
        state_keys: Map.keys(info.state)
      }
    end)
    |> Enum.sort_by(& &1.id)
  end

  @doc false
  def topic(room_id), do: "room:#{room_id}"
end
