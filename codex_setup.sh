#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "🔧 Installing dependencies..."
apt-get update
apt-get install -y curl unzip git build-essential libssl-dev autoconf ncurses-dev \
                   inotify-tools postgresql postgresql-contrib libpq-dev

echo "⚙️ Installing Elixir precompiled (v1.14.5)..."
curl -sSL https://repo.hex.pm/builds/elixir/v1.14.5.zip -o elixir.zip
unzip -q elixir.zip -d elixir
export PATH="$PWD/elixir/bin:$PATH"

elixir -v
mix -v

echo "📦 Installing Rebar and Hex..."
mix local.rebar --force
mix local.hex --force

echo "🛠 Starting PostgreSQL on port 5433..."
sed -i 's/#port = 5432/port = 5433/' /etc/postgresql/*/main/postgresql.conf
sed -i "s/^#listen_addresses = .*/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
echo "host all all 127.0.0.1/32 trust" >> /etc/postgresql/*/main/pg_hba.conf
service postgresql start
sleep 2
sudo -u postgres psql -c "CREATE DATABASE mmo_server_dev;" || echo "DB exists"

export MIX_ENV=test
export PORT=4002

echo "📥 Getting deps and compiling..."
mix deps.get --only test
mix deps.compile
mix compile --warnings-as-errors

echo "🗃️ Running migrations..."
mix ecto.migrate --quiet || true

echo "🧪 Running tests..."
mix test

