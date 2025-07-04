#!/bin/bash
set -euo pipefail

echo "🔧 Installing system dependencies..."
apt-get update
apt-get install -y curl git unzip build-essential libssl-dev autoconf ncurses-dev \
                   inotify-tools

echo "📦 Installing ASDF for Elixir & Erlang..."
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
source ~/.asdf/asdf.sh

echo "➕ Adding plugins..."
asdf plugin add erlang || true
asdf plugin add elixir || true

# Define versions
ERLANG_VERSION="26.2.2"
ELIXIR_VERSION="1.14.5-otp-26"

# Install and set
asdf install erlang "$ERLANG_VERSION"
asdf install elixir "$ELIXIR_VERSION"

# Set for this shell session
asdf shell erlang "$ERLANG_VERSION"
asdf shell elixir "$ELIXIR_VERSION"
source ~/.asdf/asdf.sh

# Verify installed
echo "Erlang: $(erl -version || true)"
echo "Elixir: $(elixir -v)"

# Environment setup
export MIX_ENV=test
export PORT=4002

echo "📦 Installing Elixir deps..."
echo "📦 Installing Hex & Rebar..."
mix archive.install github hexpm/hex --branch latest --force
mix local.rebar --force
mix hex.info
mix deps.get --only test
mix deps.compile
mix compile --warnings-as-errors

echo "🗃️  Preparing DB..."
mix ecto.create --quiet || true
mix ecto.migrate --quiet || true

echo "🧪 Runn

