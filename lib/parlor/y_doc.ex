defmodule Parlor.YDoc do
  @moduledoc """
  Context for managing Yjs document processes per room.
  """

  alias Parlor.YDoc.Server
  alias Parlor.Rooms

  @doc """
  Ensures a Yjs DocServer exists for the given room id.
  """
  @spec ensure(String.t()) :: {:ok, pid()} | {:error, term()}
  def ensure(room_id) when is_binary(room_id) do
    case Horde.Registry.lookup(Parlor.YDocRegistry, room_id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        child = {Server, room_id: room_id, topic: Rooms.topic(room_id)}

        case Horde.DynamicSupervisor.start_child(Parlor.YDocSupervisor, child) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          other -> other
        end
    end
  end

  @doc false
  def via(room_id), do: {:via, Horde.Registry, {Parlor.YDocRegistry, room_id}}

  @doc """
  Processes an incoming Yjs binary message from a channel client.
  """
  @spec process_message(String.t(), binary(), pid()) :: :ok | {:ok, [binary()]} | {:error, term()}
  def process_message(room_id, message, origin)
      when is_binary(room_id) and is_binary(message) and is_pid(origin) do
    with {:ok, pid} <- ensure(room_id) do
      case Server.process_message_v1(pid, message, origin) do
        {:ok, replies} when is_list(replies) -> {:ok, replies}
        :ok -> :ok
        other -> other
      end
    end
  end

  @doc false
  def member_joined(room_id) when is_binary(room_id) do
    with {:ok, _pid} <- ensure(room_id) do
      GenServer.cast(via(room_id), :member_joined)
      :ok
    end
  end

  @doc false
  def member_left(room_id) when is_binary(room_id) do
    case Horde.Registry.lookup(Parlor.YDocRegistry, room_id) do
      [{_pid, _}] ->
        GenServer.cast(via(room_id), :member_left)
        :ok

      [] ->
        :ok
    end
  end
end
