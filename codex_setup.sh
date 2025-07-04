#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting Codex environment setup for MmoServer"

# Set environment for test
export MIX_ENV=test

# Install hex and rebar (Elixir build tools)
echo "📦 Installing Hex & Rebar..."
mix local.hex --force || true
mix local.rebar --force || true

# Force a clean install of dependencies (fixes corrupt cache issues)
echo "📥 Fetching dependencies..."
mix deps.get --only test

# Optional: Force compile deps (catches some hidden hex issues early)
mix deps.compile

# Prepare the database
echo "🗃️  Setting up test database..."
mix ecto.create --quiet || true
mix ecto.migrate --quiet || true

# Set PORT in case Phoenix/LiveView run a server
export PORT=4002

# Compile with strict checks
echo "🔧 Compiling code with warnings as errors..."
mix compile --warnings-as-errors

# Run the test suite
echo "🧪 Running tests..."
mix test

