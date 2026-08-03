defmodule ParlorWeb.RoomChannel do
  @moduledoc false

  use ParlorWeb, :channel

  alias Parlor.Room
  alias Parlor.Rooms
  alias Parlor.YDoc

  @rate_limited_reply {:error, %{reason: "rate_limited"}}

  @impl true
  def join("room:" <> room_id, _params, socket) do
    user = socket.assigns.current_user

    if authorized?(user, room_id) do
      with {:ok, _pid} <- Rooms.ensure_room(room_id),
           {:ok, doc_pid} <- YDoc.ensure(room_id) do
        :ok = Room.member_joined(room_id)
        :ok = YDoc.member_joined(room_id)
        Process.monitor(doc_pid)
        send(self(), :after_join)

        socket =
          socket
          |> assign(:room_id, room_id)
          |> assign(:topic, Rooms.topic(room_id))
          |> assign(:doc_pid, doc_pid)

        {:ok, socket}
      end
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    %{room_id: room_id, topic: topic, current_user: user} = socket.assigns

    {:ok, _} =
      ParlorWeb.Presence.track(self(), topic, user.id, %{
        online_at: System.system_time(:second),
        meta: user.meta
      })

    push(socket, "state:sync", %{state: Room.get_state(room_id)})

    {:noreply, socket}
  end

  def handle_info({:yjs, message, _pid}, socket) when is_binary(message) do
    push(socket, "yjs", {:binary, message})
    {:noreply, socket}
  end

  def handle_info(
        {:DOWN, _ref, :process, pid, _reason},
        %{assigns: %{doc_pid: pid, room_id: room_id}} = socket
      ) do
    case YDoc.ensure(room_id) do
      {:ok, doc_pid} ->
        Process.monitor(doc_pid)
        push(socket, "yjs_resync", %{})
        {:noreply, assign(socket, :doc_pid, doc_pid)}

      {:error, reason} ->
        push(socket, "yjs_resync", %{reason: inspect(reason)})
        {:noreply, socket}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}

  @impl true
  def handle_out(event, payload, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("msg", payload, socket) when is_map(payload) do
    with :ok <- check_rate_limit(socket) do
      broadcast_from!(socket, "msg", Map.put(payload, "from", socket.assigns.current_user.id))
      {:reply, :ok, socket}
    else
      {:rate_limited, socket} -> {:reply, @rate_limited_reply, socket}
    end
  end

  @impl true
  def handle_in("yjs_sync", payload, socket), do: handle_in("yjs", payload, socket)

  @impl true
  def handle_in("yjs", {:binary, chunk}, socket) when is_binary(chunk) do
    with :ok <- check_rate_limit(socket) do
      room_id = socket.assigns.room_id

      case YDoc.process_message(room_id, chunk, self()) do
        {:ok, replies} ->
          Enum.each(replies, &push(socket, "yjs", {:binary, &1}))
          {:reply, :ok, socket}

        :ok ->
          {:reply, :ok, socket}

        {:error, reason} ->
          {:reply, {:error, %{reason: inspect(reason)}}, socket}
      end
    else
      {:rate_limited, socket} -> {:reply, @rate_limited_reply, socket}
    end
  end

  @impl true
  def handle_in("state:set", %{"key" => key, "value" => value}, socket) do
    with :ok <- check_rate_limit(socket) do
      room_id = socket.assigns.room_id

      case Room.set(room_id, key, value) do
        {:ok, state} ->
          broadcast_from!(socket, "state:patch", %{
            "op" => "set",
            "key" => key,
            "value" => value,
            "state" => state
          })

          {:reply, :ok, socket}

        {:error, reason} ->
          {:reply, {:error, %{reason: inspect(reason)}}, socket}
      end
    else
      {:rate_limited, socket} -> {:reply, @rate_limited_reply, socket}
    end
  end

  @impl true
  def handle_in("state:delete", %{"key" => key}, socket) do
    with :ok <- check_rate_limit(socket) do
      room_id = socket.assigns.room_id

      case Room.delete(room_id, key) do
        {:ok, _value, state} ->
          broadcast_from!(socket, "state:patch", %{
            "op" => "delete",
            "key" => key,
            "state" => state
          })

          {:reply, :ok, socket}

        {:error, reason} ->
          {:reply, {:error, %{reason: inspect(reason)}}, socket}
      end
    else
      {:rate_limited, socket} -> {:reply, @rate_limited_reply, socket}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    if room_id = socket.assigns[:room_id] do
      Room.member_left(room_id)
      YDoc.member_left(room_id)
    end

    :ok
  end

  defp authorized?(user, room_id) do
    if Application.get_env(:parlor, :auth_mode, :jwt) == :none do
      true
    else
      case user.rooms do
        nil -> true
        rooms when is_list(rooms) -> room_id in rooms
        _ -> false
      end
    end
  end

  defp check_rate_limit(%{assigns: %{room_id: room_id, current_user: user}} = socket) do
    key = {:channel, user.id, room_id}
    {limit, window_ms} = Application.get_env(:parlor, :channel_rate_limit, {200, 10_000})

    if Parlor.RateLimiter.allow?(key, limit, window_ms) do
      :ok
    else
      {:rate_limited, socket}
    end
  end
end
