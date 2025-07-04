#!/bin/bash
set -euo pipefail

# Update package lists
apt-get update

# Install Elixir and Erlang
apt-get install -y elixir

# Install docker and docker-compose if available
apt-get install -y docker.io docker-compose || true

# Start Docker daemon if possible
if command -v dockerd >/dev/null; then
  if ! pgrep dockerd >/dev/null; then
    (dockerd >/tmp/dockerd.log 2>&1 &) && sleep 3
  fi
fi

cd mmo_server

# Install Hex package manager
mix local.hex --force || true

# Fetch Mix dependencies
mix deps.get || true

# Setup database
if command -v docker-compose >/dev/null; then
  docker-compose up -d || true
fi

mix ecto.create || true
mix ecto.migrate || true
mix run priv/repo/seeds.exs || true

# Run tests
mix test || true
