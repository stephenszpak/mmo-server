#!/bin/bash
set -euo pipefail

# Update package lists
apt-get update

# Install Elixir, Erlang, Hex and Git
apt-get install -y elixir erlang-hex git

# Install docker and docker-compose if available
apt-get install -y docker.io docker-compose || true

# Start Docker daemon if possible
if command -v dockerd >/dev/null; then
  if ! pgrep dockerd >/dev/null; then
    (dockerd >/tmp/dockerd.log 2>&1 &) && sleep 3
  fi
fi

cd mmo_server

# Ensure Hex is available
if ! mix help hex >/dev/null 2>&1; then
  mix archive.install github hexpm/hex --force
fi

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
