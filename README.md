# Parlor

Self-hosted stateful rooms server for realtime apps — a PartyKit-style alternative built on Elixir and Phoenix Channels.

Parlor gives any backend language websocket rooms with shared state, presence, and server-to-server push. Each room is a lightweight BEAM process that holds key-value state in memory, persisted to Postgres so it survives idle shutdown and restarts.

## Features

- **Stateful rooms** — shared key-value state synced to all connected clients
- **Room persistence** — shared state saved to Postgres and rehydrated on next join
- **Presence** — see who is online in each room
- **JWT auth** — clients connect with HS256 tokens signed by your backend
- **HTTP push API** — broadcast events into rooms from your server
- **Idle shutdown** — empty rooms stop automatically after a configurable TTL
- **Multi-node clustering** — each room runs once cluster-wide via Horde, with Postgres rehydration on recovery

## Prerequisites

- Elixir 1.17+ and Erlang/OTP 26+
- Docker (recommended) or a local Postgres 16 instance

## Quickstart

```bash
docker compose up -d
mix setup
mix phx.server
```

`mix setup` installs deps, creates the database, and runs migrations.

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

Returns room state, member count, presence, and whether state is persisted.

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
| `DATABASE_URL` | local Postgres via config | Postgres connection URL (required in prod) |
| `PARLOR_SIGNING_SECRET` | dev secret | HS256 secret for websocket JWTs |
| `PARLOR_API_KEY` | dev key | HTTP API key |
| `PARLOR_ROOM_TTL` | `60000` | Milliseconds before idle rooms shut down |
| `PARLOR_AUTH` | `none` in dev, `jwt` in prod | Set to `none` to disable JWT auth |
| `PORT` | `4000` | HTTP port |
| `SECRET_KEY_BASE` | required in prod | Phoenix secret |
| `POOL_SIZE` | `10` | Database connection pool size (prod) |
| `DNS_CLUSTER_QUERY` | unset | DNS query for Erlang node discovery (required for multi-node prod) |
| `RELEASE_COOKIE` | unset | Shared Erlang cookie for clustered nodes (required for multi-node prod) |

## Horizontal scaling

Parlor uses [Horde](https://hexdocs.pm/horde) so each room id maps to exactly one GenServer across the cluster. Phoenix PubSub and Presence already work cluster-wide, so clients connected to any node receive the same events.

**Failure recovery:** when a node dies, its room processes are gone. The next client join or API call to `ensure_room/1` lazily starts the room on a surviving node and rehydrates shared state from Postgres.

**Production clustering** requires:

- A shared `RELEASE_COOKIE` on every node
- `DNS_CLUSTER_QUERY` set so nodes discover each other (dns_cluster)
- A shared Postgres `DATABASE_URL` (all nodes read/write the same room state)

Run multiple instances behind a load balancer with sticky sessions optional — websocket clients can connect to any node.

### Local two-node smoke test

Terminal 1:

```bash
docker compose up -d
mix setup
iex --sname a --cookie parlor -S mix phx.server
```

Terminal 2 (replace `your-hostname` with output of `hostname`):

```bash
PORT=4001 iex --sname b --cookie parlor -S mix phx.server
```

In either IEx shell, connect the nodes:

```elixir
Node.connect(:"a@your-hostname")
Node.connect(:"b@your-hostname")
Node.list()
```

Create a room on node A, then list it from node B:

```bash
curl -X POST http://localhost:4000/api/rooms/cluster-test/broadcast \
  -H "x-api-key: dev-api-key-change-me" \
  -H "Content-Type: application/json" \
  -d '{"payload":{"hello":"world"}}'

curl http://localhost:4001/api/rooms -H "x-api-key: dev-api-key-change-me"
```

You should see `cluster-test` in the room list from node B.

## Demo

Open `examples/cursors.html` in a browser while the server is running to see multiplayer cursors over Parlor.

## Roadmap

- Yjs/CRDT document sync
- Rate limiting and admin dashboard

## License

MIT
