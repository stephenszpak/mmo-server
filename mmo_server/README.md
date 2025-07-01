# MMO Server

Bootstrap Phoenix/Elixir MMORPG server.

## Prerequisites

- Elixir >= 1.18.4
- Erlang/OTP 27
- Docker and Docker Compose

## Setup

```bash
docker compose up -d db
mix deps.get
mix ecto.setup
mix seed
```

## Development

Start the server:

```bash
iex -S mix phx.server
```

Visit [http://localhost:4000/dashboard](http://localhost:4000/dashboard) for LiveDashboard.

Prometheus metrics are exported at `/metrics` via PromEx.
