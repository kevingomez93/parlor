defmodule ParlorWeb.AdminLive do
  @moduledoc false

  use ParlorWeb, :live_view

  alias Parlor.Rooms
  alias Parlor.Rooms.Store
  alias Parlor.YDoc.Store, as: YDocStore

  @refresh_ms 2_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      schedule_refresh()
    end

    {:ok, assign(socket, page_title: "Parlor Admin")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      case socket.assigns.live_action do
        :index -> load_index(socket)
        :show -> load_show(socket, params["id"])
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    socket =
      case socket.assigns.live_action do
        :index -> load_index(socket)
        :show -> load_show(socket, socket.assigns.room_id)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("broadcast", %{"event" => event, "payload" => payload_json}, socket) do
    room_id = socket.assigns.room_id

    with {:ok, payload} <- Jason.decode(payload_json),
         :ok <- Rooms.broadcast(room_id, event, payload) do
      {:noreply, put_flash(socket, :info, "Broadcast sent to #{room_id}")}
    else
      {:error, %Jason.DecodeError{}} ->
        {:noreply, put_flash(socket, :error, "Invalid JSON payload")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Broadcast failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_persistence", _params, socket) do
    room_id = socket.assigns.room_id
    _ = Store.delete(room_id)
    _ = YDocStore.delete(room_id)

    socket =
      socket
      |> put_flash(:info, "Deleted persisted data for #{room_id}")
      |> load_show(room_id)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div :if={@live_action == :index}>
        <div class="stats">
          <div class="stat">
            <div class="stat-label">Rooms</div>
            <div class="stat-value">{@total_rooms}</div>
          </div>
          <div class="stat">
            <div class="stat-label">Online users</div>
            <div class="stat-value">{@total_online}</div>
          </div>
          <div class="stat">
            <div class="stat-label">Node</div>
            <div class="stat-value" style="font-size: 0.95rem;">{@node}</div>
          </div>
        </div>

        <table>
          <thead>
            <tr>
              <th>Room</th>
              <th>Members</th>
              <th>Online</th>
              <th>State keys</th>
              <th>KV persisted</th>
              <th>Yjs persisted</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={room <- @rooms}>
              <td><.link navigate={~p"/admin/rooms/#{room.id}"}>{room.id}</.link></td>
              <td>{room.member_count}</td>
              <td>{Map.get(room, :online_count, 0)}</td>
              <td>{room.state_keys |> Enum.join(", ")}</td>
              <td><.badge value={Map.get(room, :persisted, false)} /></td>
              <td><.badge value={Map.get(room, :yjs_persisted, false)} /></td>
            </tr>
          </tbody>
        </table>

        <p :if={@rooms == []} style="color: var(--muted); margin-top: 1rem;">
          No active rooms. Join a room from a client to see it here.
        </p>
      </div>

      <div :if={@live_action == :show}>
        <p><.link navigate={~p"/admin"}>← Back to rooms</.link></p>

        <div class="stats">
          <div class="stat">
            <div class="stat-label">Room</div>
            <div class="stat-value" style="font-size: 1rem;">{@room.id}</div>
          </div>
          <div class="stat">
            <div class="stat-label">Members</div>
            <div class="stat-value">{@room.member_count}</div>
          </div>
          <div class="stat">
            <div class="stat-label">Online</div>
            <div class="stat-value">{@room.online_count}</div>
          </div>
        </div>

        <div class="panel">
          <h2>Shared state</h2>
          <pre>{Jason.encode!(@room.state, pretty: true)}</pre>
        </div>

        <div class="panel">
          <h2>Presence</h2>
          <pre>{Jason.encode!(@room.presence, pretty: true)}</pre>
        </div>

        <div class="panel">
          <h2>Persistence</h2>
          <p>
            KV persisted: <.badge value={@room.persisted} />
            Yjs persisted: <.badge value={@room.yjs_persisted} />
          </p>
        </div>

        <div class="panel">
          <h2>Broadcast event</h2>
          <.form for={%{}} phx-submit="broadcast" id="broadcast-form">
            <label for="event">Event name</label>
            <input id="event" name="event" type="text" value={@broadcast_event} />

            <label for="payload">Payload (JSON)</label>
            <textarea id="payload" name="payload" rows="4">{@broadcast_payload}</textarea>

            <button type="submit">Send broadcast</button>
          </.form>
        </div>

        <div class="panel">
          <h2>Danger zone</h2>
          <button
            type="button"
            class="danger"
            phx-click="delete_persistence"
            data-confirm="Delete all persisted KV and Yjs data for this room?"
          >
            Delete persisted data
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :value, :boolean, required: true

  defp badge(assigns) do
    ~H"""
    <span class={["badge", if(@value, do: "badge-yes", else: "badge-no")]}>
      {if @value, do: "yes", else: "no"}
    </span>
    """
  end

  defp load_index(socket) do
    rooms =
      Rooms.list()
      |> Enum.map(fn room ->
        case Rooms.get_info(room.id) do
          {:ok, info} -> Map.merge(room, info)
          _ -> room
        end
      end)

    total_online = Enum.sum(Enum.map(rooms, &Map.get(&1, :online_count, 0)))

    socket
    |> assign(:rooms, rooms)
    |> assign(:total_rooms, length(rooms))
    |> assign(:total_online, total_online)
    |> assign(:node, Node.self() |> to_string())
  end

  defp load_show(socket, room_id) do
    case Rooms.get_info(room_id) do
      {:ok, info} ->
        socket
        |> assign(:room, info)
        |> assign(:room_id, room_id)
        |> assign(:broadcast_event, "server:event")
        |> assign(:broadcast_payload, ~s({"message":"hello from admin"}))

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Room not found")
        |> push_navigate(to: ~p"/admin")
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_ms)
  end
end
