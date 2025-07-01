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

3. Create the development database (if it does not already exist):

   ```bash
   mix ecto.create
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
