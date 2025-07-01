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

3. Create the development database (if it does not already exist) and seed initial players:

   ```bash
   mix ecto.create
   mix ecto.migrate
   mix run priv/repo/seeds.exs
   ```

4. Run the application:

   ```bash
   mix phx.server
   ```

   The API will be available on `http://localhost:4000`.

## Running Tests

Execute the test suite with:

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

Visit `http://localhost:4000/players` to view live player positions.

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
    {MmoServer.Player, %{player_id: "player1", zone_id: "zone1"}})
```

These commands must be executed from the `mmo_server` directory after the server has started.
