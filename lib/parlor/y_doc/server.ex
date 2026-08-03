defmodule Parlor.YDoc.Server do
  @moduledoc false

  use Yex.DocServer

  require Logger

  alias Yex.Awareness
  alias Yex.Sync
  alias Parlor.YDoc.Persistence

  @persistence Persistence
  @awareness_throttle_ms 50

  def child_spec(opts) do
    room_id = Keyword.fetch!(opts, :room_id)
    topic = Keyword.fetch!(opts, :topic)

    %{
      id: {__MODULE__, room_id},
      start: {__MODULE__, :start_named, [[room_id: room_id, topic: topic]]},
      restart: :temporary
    }
  end

  def start_named(args) do
    room_id = Keyword.fetch!(args, :room_id)
    start_link(args, name: Parlor.YDoc.via(room_id))
  end

  @impl true
  def init(option, %{doc: doc} = state) do
    room_id = Keyword.fetch!(option, :room_id)
    topic = Keyword.fetch!(option, :topic)

    persistence_state = @persistence.bind(%{}, room_id, doc)

    {:ok,
     assign(state, %{
       room_id: room_id,
       topic: topic,
       persistence_state: persistence_state,
       member_count: 0,
       shutdown_timer_ref: nil,
       origin_clients_map: %{},
       awareness_throttle_ms: @awareness_throttle_ms,
       awareness_window_open: false,
       awareness_pending_clients: MapSet.new(),
       awareness_pending_origin: :unset,
       awareness_flush_timer_ref: nil
     })}
  end

  @impl true
  def handle_update_v1(doc, update, origin, state) do
    persistence_state =
      @persistence.update_v1(
        state.assigns.persistence_state,
        update,
        state.assigns.room_id,
        doc
      )

    state = assign(state, :persistence_state, persistence_state)
    state = maybe_monitor_origin(state, origin)

    with {:ok, sync_update} <- Sync.get_update(update),
         {:ok, message} <- Sync.message_encode({:sync, sync_update}) do
      broadcast_yjs(origin, state.assigns.topic, message)
    else
      error ->
        Logger.warning("Failed to broadcast Yjs update: #{inspect(error)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_awareness_update(
        awareness,
        %{removed: removed, added: added, updated: updated},
        origin,
        state
      ) do
    changed_clients = MapSet.new(added ++ updated ++ removed)

    state =
      if origin do
        monitor_and_update_origin_clients_map(state, origin, added, removed)
      else
        state
      end

    if state.assigns.awareness_window_open do
      pending_clients = MapSet.union(state.assigns.awareness_pending_clients, changed_clients)
      pending_origin = merge_pending_origin(state.assigns.awareness_pending_origin, origin)

      {:noreply,
       assign(state, %{
         awareness_pending_clients: pending_clients,
         awareness_pending_origin: pending_origin
       })}
    else
      flush_awareness_now(awareness, changed_clients, origin, state)
    end
  end

  @impl true
  def handle_cast(:member_joined, state) do
    state = cancel_shutdown(state)
    {:noreply, assign(state, :member_count, state.assigns.member_count + 1)}
  end

  @impl true
  def handle_cast(:member_left, state) do
    count = max(0, state.assigns.member_count - 1)
    state = assign(state, :member_count, count)
    state = if count == 0, do: schedule_shutdown(state), else: cancel_shutdown(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    origin_clients_map = state.assigns.origin_clients_map

    case Map.get(origin_clients_map, pid) do
      %{client_ids: ids} ->
        Awareness.remove_states(state.awareness, ids)
        origin_clients_map = Map.delete(origin_clients_map, pid)
        {:noreply, assign(state, :origin_clients_map, origin_clients_map)}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:flush_awareness, state) do
    pending_clients = MapSet.to_list(state.assigns.awareness_pending_clients)
    topic = state.assigns.topic
    trailing_origin = resolve_pending_origin(state.assigns.awareness_pending_origin)

    if state.assigns.awareness_flush_timer_ref do
      Process.cancel_timer(state.assigns.awareness_flush_timer_ref)
    end

    state =
      assign(state, %{
        awareness_window_open: false,
        awareness_pending_clients: MapSet.new(),
        awareness_pending_origin: :unset,
        awareness_flush_timer_ref: nil
      })

    case pending_clients do
      [] ->
        {:noreply, state}

      _ ->
        with {:ok, update} <- Awareness.encode_update(state.awareness, pending_clients),
             {:ok, message} <- Sync.message_encode({:awareness, update}) do
          broadcast_yjs(trailing_origin, topic, message)
          {:noreply, state}
        else
          error ->
            Logger.warning("Failed to flush awareness: #{inspect(error)}")
            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info(:delayed_shutdown, state) do
    if state.assigns.member_count <= 0 do
      {:stop, :shutdown, state}
    else
      {:noreply, assign(state, :shutdown_timer_ref, nil)}
    end
  end

  @impl true
  def terminate(_reason, state) do
    if state.assigns[:awareness_flush_timer_ref] do
      Process.cancel_timer(state.assigns.awareness_flush_timer_ref)
    end

    if state.assigns[:persistence_state] do
      @persistence.unbind(
        state.assigns.persistence_state,
        state.assigns.room_id,
        state.doc
      )
    end

    :ok
  end

  defp broadcast_yjs(origin, topic, message) do
    if origin do
      ParlorWeb.Endpoint.broadcast_from(origin, topic, "yjs", {:binary, message})
    else
      ParlorWeb.Endpoint.broadcast(topic, "yjs", {:binary, message})
    end
  end

  defp flush_awareness_now(awareness, changed_clients, origin, state) do
    with {:ok, update} <- Awareness.encode_update(awareness, MapSet.to_list(changed_clients)),
         {:ok, message} <- Sync.message_encode({:awareness, update}) do
      broadcast_yjs(origin, state.assigns.topic, message)

      ref = Process.send_after(self(), :flush_awareness, state.assigns.awareness_throttle_ms)

      {:noreply,
       assign(state, %{
         awareness_window_open: true,
         awareness_pending_clients: MapSet.new(),
         awareness_pending_origin: :unset,
         awareness_flush_timer_ref: ref
       })}
    else
      error ->
        Logger.warning("Failed to broadcast awareness: #{inspect(error)}")
        {:noreply, state}
    end
  end

  defp maybe_monitor_origin(state, origin) when is_pid(origin) do
    origin_clients_map = state.assigns.origin_clients_map

    if Map.has_key?(origin_clients_map, origin) do
      state
    else
      ref = Process.monitor(origin)
      Map.put(origin_clients_map, origin, %{monitor_ref: ref, client_ids: []})

      assign(
        state,
        :origin_clients_map,
        Map.put(origin_clients_map, origin, %{monitor_ref: ref, client_ids: []})
      )
    end
  end

  defp maybe_monitor_origin(state, _origin), do: state

  defp monitor_and_update_origin_clients_map(state, origin, added, removed) do
    origin_clients_map = state.assigns.origin_clients_map
    entry = Map.get(origin_clients_map, origin)

    ref =
      case entry do
        nil -> Process.monitor(origin)
        %{monitor_ref: monitor_ref} -> monitor_ref
      end

    client_ids =
      case entry do
        nil ->
          added

        %{client_ids: prev} ->
          (added ++ prev) |> Enum.uniq() |> Enum.reject(&(&1 in removed))
      end

    origin_clients_map =
      if client_ids == [] do
        Process.demonitor(ref, [:flush])
        Map.delete(origin_clients_map, origin)
      else
        Map.put(origin_clients_map, origin, %{monitor_ref: ref, client_ids: client_ids})
      end

    assign(state, :origin_clients_map, origin_clients_map)
  end

  defp merge_pending_origin(:unset, origin), do: origin
  defp merge_pending_origin(:mixed, _origin), do: :mixed
  defp merge_pending_origin(origin, origin), do: origin
  defp merge_pending_origin(_origin, _other), do: :mixed

  defp resolve_pending_origin(:unset), do: nil
  defp resolve_pending_origin(:mixed), do: nil
  defp resolve_pending_origin(origin), do: origin

  defp cancel_shutdown(state) do
    if state.assigns.shutdown_timer_ref do
      Process.cancel_timer(state.assigns.shutdown_timer_ref)
    end

    assign(state, :shutdown_timer_ref, nil)
  end

  defp schedule_shutdown(state) do
    state = cancel_shutdown(state)
    ref = Process.send_after(self(), :delayed_shutdown, room_ttl())
    assign(state, :shutdown_timer_ref, ref)
  end

  defp room_ttl do
    Application.get_env(:parlor, :room_ttl, 60_000)
  end
end
