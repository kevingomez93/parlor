# Parlor

Self-hosted stateful rooms server for realtime apps — a PartyKit-style alternative built on Elixir and Phoenix Channels.

Parlor gives any backend language websocket rooms with shared state, presence, and server-to-server push. Each room is a lightweight BEAM process that holds key-value state in memory.

## Features

- **Stateful rooms** — shared key-value state synced to all connected clients
- **Presence** — see who is online in each room
- **JWT auth** — clients connect with HS256 tokens signed by your backend
- **HTTP push API** — broadcast events into rooms from your server
- **Idle shutdown** — empty rooms stop automatically after a configurable TTL

## Quickstart

```bash
mix setup
mix phx.server
```

By default, development runs with `auth_mode: :none`, so you can connect without a token.

Websocket endpoint: `ws://localhost:4000/socket/websocket`

HTTP API: `http://localhost:4000/api`

## Client connection

Use the TypeScript client in `clients/js` or connect directly with `phoenix.js`:

```javascript
import { Socket } from "phoenix";

const socket = new Socket("ws://localhost:4000/socket", {
  params: { token: "<jwt>" }
});

socket.connect();

const room = socket.channel("room:lobby", {});
room.join();

room.on("state:sync", ({ state }) => console.log("state", state));
room.on("msg", (payload) => console.log("message", payload));

room.push("msg", { text: "hello" });
room.push("state:set", { key: "status", value: "ready" });
```

## Signing JWTs

Tokens must be HS256 JWTs signed with `PARLOR_SIGNING_SECRET`.

Claims:

| Claim | Required | Description |
| --- | --- | --- |
| `sub` | yes | User id used for presence |
| `rooms` | no | List of room ids the user may join. Omit to allow all rooms. |
| `meta` | no | Arbitrary map attached to presence |

### Elixir

```elixir
{:ok, token, _} =
  Parlor.Token.sign(%{
    "sub" => "user-123",
    "rooms" => ["lobby"],
    "meta" => %{"name" => "Alice"}
  })
```

### Node.js

```javascript
import jwt from "jsonwebtoken";

const token = jwt.sign(
  { sub: "user-123", rooms: ["lobby"], meta: { name: "Alice" } },
  process.env.PARLOR_SIGNING_SECRET,
  { algorithm: "HS256" }
);
```

### Python

```python
import jwt

token = jwt.encode(
    {"sub": "user-123", "rooms": ["lobby"], "meta": {"name": "Alice"}},
    os.environ["PARLOR_SIGNING_SECRET"],
    algorithm="HS256",
)
```

## HTTP API

All room endpoints require the `x-api-key` header.

### List rooms

`GET /api/rooms`

### Room info

`GET /api/rooms/:id`

Returns room state, member count, and presence.

### Broadcast to room

`POST /api/rooms/:id/broadcast`

```json
{
  "event": "server:event",
  "payload": { "message": "hello from backend" }
}
```

Clients receive the event on their room channel.

## Configuration

| Variable | Default (dev) | Description |
| --- | --- | --- |
| `PARLOR_SIGNING_SECRET` | dev secret | HS256 secret for websocket JWTs |
| `PARLOR_API_KEY` | dev key | HTTP API key |
| `PARLOR_ROOM_TTL` | `60000` | Milliseconds before idle rooms shut down |
| `PARLOR_AUTH` | `none` in dev, `jwt` in prod | Set to `none` to disable JWT auth |
| `PORT` | `4000` | HTTP port |
| `SECRET_KEY_BASE` | required in prod | Phoenix secret |

## Demo

Open `examples/cursors.html` in a browser while the server is running to see multiplayer cursors over Parlor.

## Roadmap

- Yjs/CRDT document sync
- Room persistence
- Multi-node clustering with Horde
- Rate limiting and admin dashboard

## License

MIT
