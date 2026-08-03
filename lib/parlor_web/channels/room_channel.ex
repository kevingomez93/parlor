defmodule ParlorWeb.RoomChannel do
  @moduledoc false

  use ParlorWeb, :channel

  alias Parlor.Room
  alias Parlor.Rooms

  @impl true
  def join("room:" <> room_id, _params, socket) do
    user = socket.assigns.current_user

    if authorized?(user, room_id) do
      with {:ok, _pid} <- Rooms.ensure_room(room_id) do
        :ok = Room.member_joined(room_id)
        send(self(), :after_join)

        socket =
          socket
          |> assign(:room_id, room_id)
          |> assign(:topic, Rooms.topic(room_id))

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

  @impl true
  def handle_out(event, payload, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("msg", payload, socket) when is_map(payload) do
    broadcast_from!(socket, "msg", Map.put(payload, "from", socket.assigns.current_user.id))
    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("state:set", %{"key" => key, "value" => value}, socket) do
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
  end

  @impl true
  def handle_in("state:delete", %{"key" => key}, socket) do
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
  end

  @impl true
  def terminate(_reason, socket) do
    if room_id = socket.assigns[:room_id] do
      Room.member_left(room_id)
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
end
