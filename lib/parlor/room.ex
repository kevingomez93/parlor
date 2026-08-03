defmodule Parlor.Room do
  @moduledoc """
  A GenServer representing a single realtime room with shared key-value state.
  """

  use GenServer

  alias Parlor.Rooms.Store

  @type room_id :: String.t()

  def child_spec(room_id) do
    %{
      id: {__MODULE__, room_id},
      start: {__MODULE__, :start_link, [room_id]},
      restart: :temporary
    }
  end

  def start_link(room_id) when is_binary(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: via(room_id))
  end

  def via(room_id), do: {:via, Horde.Registry, {Parlor.RoomRegistry, room_id}}

  def set(room_id, key, value) when is_binary(room_id) do
    GenServer.call(via(room_id), {:set, key, value})
  end

  def delete(room_id, key) when is_binary(room_id) do
    GenServer.call(via(room_id), {:delete, key})
  end

  def get_state(room_id) when is_binary(room_id) do
    GenServer.call(via(room_id), :get_state)
  end

  def member_joined(room_id) when is_binary(room_id) do
    GenServer.cast(via(room_id), :member_joined)
  end

  def member_left(room_id) when is_binary(room_id) do
    GenServer.cast(via(room_id), :member_left)
  end

  @impl true
  def init(room_id) do
    state = Store.load_state(room_id)
    {:ok, %{id: room_id, state: state, member_count: 0, shutdown_timer: nil}}
  end

  @impl true
  def handle_call({:set, key, value}, _from, data) do
    new_state = Map.put(data.state, key, value)

    case persist_state(data.id, new_state) do
      :ok ->
        {:reply, {:ok, new_state}, %{data | state: new_state}}

      :error ->
        {:reply, {:error, :persist_failed}, data}
    end
  end

  @impl true
  def handle_call({:delete, key}, _from, data) do
    {value, new_state} = Map.pop(data.state, key)

    case persist_state(data.id, new_state) do
      :ok ->
        {:reply, {:ok, value, new_state}, %{data | state: new_state}}

      :error ->
        {:reply, {:error, :persist_failed}, data}
    end
  end

  @impl true
  def handle_call(:get_state, _from, data) do
    {:reply, data.state, data}
  end

  @impl true
  def handle_call(:info, _from, data) do
    info = %{
      id: data.id,
      state: data.state,
      member_count: data.member_count
    }

    {:reply, info, data}
  end

  @impl true
  def handle_cast(:member_joined, data) do
    data = cancel_shutdown(data)
    {:noreply, %{data | member_count: data.member_count + 1}}
  end

  @impl true
  def handle_cast(:member_left, data) do
    count = max(0, data.member_count - 1)
    data = %{data | member_count: count}
    data = if count == 0, do: schedule_shutdown(data), else: data
    {:noreply, data}
  end

  @impl true
  def handle_info(:shutdown, data) do
    {:stop, :normal, data}
  end

  defp persist_state(room_id, state) do
    case Store.save_state(room_id, state) do
      {:ok, _record} ->
        :ok

      {:error, reason} ->
        require Logger
        Logger.error("Failed to persist room #{room_id}: #{inspect(reason)}")
        :error
    end
  end

  defp cancel_shutdown(%{shutdown_timer: nil} = data), do: data

  defp cancel_shutdown(%{shutdown_timer: ref} = data) do
    _ = Process.cancel_timer(ref)
    %{data | shutdown_timer: nil}
  end

  defp schedule_shutdown(data) do
    ttl = Application.get_env(:parlor, :room_ttl, 60_000)
    ref = Process.send_after(self(), :shutdown, ttl)
    %{data | shutdown_timer: ref}
  end
end
