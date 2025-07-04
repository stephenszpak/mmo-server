#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Installing Elixir and dependencies"

# Set Elixir environment
export MIX_ENV=test

# Install Elixir and Hex tools
mix local.hex --force
mix local.rebar --force

# Install dependencies
mix deps.get

# Setup DB (if needed — comment out if not using Ecto migrations)
mix ecto.create --quiet
mix ecto.migrate --quiet

# Compile with warnings as errors to catch issues
mix compile --warnings-as-errors

# Run tests
mix test

