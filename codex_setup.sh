#!/bin/bash
set -euo pipefail

echo "🔧 Installing system dependencies..."
apt-get update
apt-get install -y curl git unzip build-essential libssl-dev autoconf ncurses-dev \
                   inotify-tools

echo "📦 Installing ASDF for Elixir & Erlang..."
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
source ~/.asdf/asdf.sh

echo "➕ Adding plugins..."
asdf plugin add erlang || true
asdf plugin add elixir || true

ERLANG_VERSION="26.2.2"
ELIXIR_VERSION="1.14.5-otp-26"

asdf install erlang "$ERLANG_VERSION"
asdf install elixir "$ELIXIR_VERSION"
asdf global elixir "$ELIXIR_VERSION"

# You MUST source again for binaries to work in Codex
source ~/.asdf/asdf.sh

export MIX_ENV=test
export PORT=4002

echo "📦 Installing Elixir deps..."
mix local.hex --force
mix local.rebar --force
mix deps.get --only test
mix deps.compile
mix compile --warnings-as-errors

echo "🗃️  Preparing DB..."
mix ecto.create --quiet || true
mix ecto.migrate --quiet || true

echo "🧪 Running tests..."
mix test

