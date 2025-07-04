#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "🔧 Installing system dependencies..."
apt-get update
apt-get install -y curl git unzip build-essential libssl-dev autoconf ncurses-dev \
                   inotify-tools postgresql postgresql-contrib libpq-dev

echo "🗄️ Configuring PostgreSQL to listen on port 5433..."
# Update PostgreSQL config
sed -i 's/#port = 5432/port = 5433/' /etc/postgresql/*/main/postgresql.conf
sed -i "s/^#listen_addresses = .*/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
echo "host all all 127.0.0.1/32 trust" >> /etc/postgresql/*/main/pg_hba.conf

# Start PostgreSQL
service postgresql start

# Wait for it to be ready
sleep 3

# Create dev DB if needed
sudo -u postgres psql -c "CREATE DATABASE mmo_server_dev;" || echo "DB already exists"

echo "📦 Installing ASDF for Elixir & Erlang..."
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
source ~/.asdf/asdf.sh

asdf plugin add erlang || true
asdf plugin add elixir || true

ERLANG_VERSION="26.2.2"
ELIXIR_VERSION="1.14.5-otp-26"

asdf install erlang "$ERLANG_VERSION"
asdf install elixir "$ELIXIR_VERSION"
asdf shell erlang "$ERLANG_VERSION"
asdf shell elixir "$ELIXIR_VERSION"
source ~/.asdf/asdf.sh

echo "⬇️  Downloading Hex archive..."
curl -sSL https://github.com/hexpm/hex/releases/latest/download/hex.ez -o hex.ez

echo "📦 Installing Hex manually..."
mix archive.install ./hex.ez --force

echo "📦 Installing Rebar..."
mix local.rebar --force

export MIX_ENV=test
export PORT=4002

echo "📥 Installing Elixir dependencies..."
mix deps.get --only test
mix deps.compile
mix compile --warnings-as-errors

echo "🗃️ Running migrations..."
mix ecto.migrate --quiet || true

echo "🧪 Running tests..."
mix test

