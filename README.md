# MMO Server

This repository contains a minimal Phoenix application used for experimenting with a simple multiplayer server.

## Prerequisites

- **Elixir 1.15** and Erlang/OTP 26 or later
- **PostgreSQL** (Docker Compose is provided for convenience)

## Getting Started

1. Start PostgreSQL using Docker Compose:

   ```bash
   cd mmo_server
   docker-compose up -d
   ```

   This will launch a local PostgreSQL instance listening on `localhost:5432` with the default credentials defined in `docker-compose.yml`.

2. Fetch Elixir dependencies:

   ```bash
   mix deps.get
   ```

3. Create the development database (if it does not already exist) and load the development seed data:

   ```bash
   mix ecto.create
   mix ecto.migrate
   mix seed        # or: mix run priv/repo/seeds.exs
   ```

4. Run the application:

   ```bash
   mix phx.server
   ```

   The API will be available on `http://localhost:4001`.

## Running Tests

The sandbox runs in manual mode so each case checks out a shared
connection before spawning processes. Tests therefore run serially.

```bash
mix test
```

## Production Configuration

The production config expects `DATABASE_URL`, `POOL_SIZE` and `SECRET_KEY_BASE` environment variables. See `config/runtime.exs` for details.

## Exit Criteria Demo

To verify the phase 1 functionality, open two terminal windows and run two UDP clients.
Each client sends move packets and you should see both players' movements in the
server logs.

1. Start the server:

   ```bash
   cd mmo_server
   mix deps.get
   mix phx.server
   ```

2. In another terminal send a move packet. Example using the Erlang shell:

   ```erlang
   {ok, S} = gen_udp:open(0, []),
   Packet = <<1:32, 1:16, 1.0:32/float, 0.0:32/float, 0.0:32/float>>,
   gen_udp:send(S, {127,0,0,1}, 4000, Packet).
   ```

3. Repeat with a different `player_id` from a second terminal. The log output
   will display position updates for both players.

## How to run the live dashboard

Start the Phoenix server:

```bash
cd mmo_server
mix phx.server
```

Visit `http://localhost:4001/players` to view live player positions.

From `iex -S mix` you can print all positions using:

```elixir
MmoServer.CLI.LivePlayerTracker.print_all_positions()
```

## Starting Zones and Players from IEx

After launching the Phoenix server from the `mmo_server` directory, you can manually create zones and players in an interactive shell. Start `iex` alongside the server and then run:

```elixir
iex -S mix phx.server

{:ok, _zone} =
  DynamicSupervisor.start_child(MmoServer.ZoneSupervisor,
    {MmoServer.Zone, "zone1"})

{:ok, _player} =
  DynamicSupervisor.start_child(MmoServer.PlayerSupervisor,
    {MmoServer.Player, %{player_id: "player3", zone_id: "zone1"}})
```
Check player positions with:

```elixir
MmoServer.Player.get_position("player1")
```
Move player1 to a new position:

```elixir
MmoServer.Player.move("player1", {1.0, 2.0, 3.0})
```

get full zone state:

```elixir
MmoServer.Quests.get_progress("player1", MmoServer.Quests.wolf_kill_id())
```

These commands must be executed from the `mmo_server` directory after the server has started.

## Running Two Terminals

Start two IEx nodes to simulate different regions or players and connect them together:

```bash
# Terminal 1 – Backend node 1
iex --sname node1 -S mix phx.server

# Terminal 2 – Backend node 2 (simulate another region/player)
iex --sname node2 -S mix
Node.connect(:"node1@localhost")
```

## Real-time Chat

Chat messages are delivered over Phoenix Channels. Clients connect to
`ws://localhost:4001/socket/websocket` and join one or more topics:

- `"chat:global"` – global chat for everyone
- `"chat:zone:<zone_id>"` – messages scoped to a zone
- `"chat:whisper:<player_id>"` – private 1:1 chat

### Example client code

To run the sample below you need the [`phoenix_client`](https://hex.pm/packages/phoenix_client)
library. The server does not depend on this package, so create a small
client project and add it as a dependency:

```bash
mix new chat_client
cd chat_client
# mix.exs
defp deps do
  [
    {:phoenix_client, "~> 0.1"}
  ]
end

mix deps.get
iex -S mix
```

Once the dependency is available you can connect to the running server:

```elixir
# Join the channel and send a message (Elixir client example)
{:ok, socket} = PhoenixClient.Socket.start_link(url: "ws://localhost:4001/socket/websocket")
{:ok, _, chan} = PhoenixClient.Channel.join(socket, "chat:global")
PhoenixClient.Channel.push(chan, "message", %{
  "from" => "player1",
  "to" => "chat:global",
  "text" => "Hello!"
})
```

Unity clients can use similar logic via a WebSocket library:

```csharp
var socket = new Websocket("ws://localhost:4001/socket/websocket");
socket.Connect();
socket.Join("chat:zone:elwynn");
socket.Push("message", new { from = "player1", to = "chat:zone:elwynn", text = "Hi" });
```

You can also broadcast messages without a channel using:

```elixir
Phoenix.PubSub.broadcast(MmoServer.PubSub, "chat:zone:elwynn", {:chat_msg, "gm", "Server restart soon"})
```
