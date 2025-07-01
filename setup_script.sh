
#!/usr/bin/env bash
# scripts/setup_codex.sh
set -euo pipefail
set -x                                   # <-- print every command for easy log digs
export DEBIAN_FRONTEND=noninteractive

echo "🔧  apt-get update + basics"
apt-get -qq update
apt-get -qq install --no-install-recommends -y \
  curl gnupg ca-certificates wget lsb-release software-properties-common

# ---------------------------------------------------------------------
# 1. Erlang / Elixir (retry key once; fall back to distro version)
# ---------------------------------------------------------------------
if ! curl --retry 2 --retry-delay 5 -fsSL \
      https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc \
      -o /etc/apt/trusted.gpg.d/erlang.asc ; then
  echo "⚠️  ESRL repo offline – falling back to Ubuntu Elixir/Erlang."
  USE_DISTRO_ELIXIR=true
else
  echo "deb https://packages.erlang-solutions.com/ubuntu $(lsb_release -sc) contrib" \
    | tee /etc/apt/sources.list.d/erlang.list
fi

apt-get -qq update
if [ -z "${USE_DISTRO_ELIXIR:-}" ]; then
  apt-get -qq install -y esl-erlang elixir        # OTP 27 / Elixir 1.18
else
  apt-get -qq install -y elixir erlang-base       # OTP 26 / Elixir 1.16
fi

# ---------------------------------------------------------------------
# 2. Local PostgreSQL cluster (no systemd required)
# ---------------------------------------------------------------------
apt-get -qq install -y postgresql postgresql-contrib
PG_VER=$(ls /etc/postgresql | head -n1)            # e.g. "16"
pg_ctlcluster "$PG_VER" main start
# wait until ready
until pg_isready -q; do sleep 1; done

sudo -u postgres psql -c "CREATE ROLE mmo WITH LOGIN SUPERUSER PASSWORD 'mmo_pass';" || true
sudo -u postgres psql -c "CREATE DATABASE mmo_dev OWNER mmo;" || true
export DATABASE_URL="ecto://mmo:mmo_pass@localhost/mmo_dev"
# persist for future shells -------------------------------------------
export BASH_ENV="/etc/profile.d/mmo_env.sh"
echo "export DATABASE_URL=$DATABASE_URL" >> "$BASH_ENV"
chmod 644 "$BASH_ENV"
# ---------------------------------------------------------------------
# 3. If this repo already contains a Phoenix project, build it
# ---------------------------------------------------------------------
if [ -f mix.exs ]; then
  echo "📦  Installing Hex & fetching deps…"
  mix local.hex --force
  mix local.rebar --force
  mix deps.get --only dev || { echo "❌ mix deps.get failed"; exit 1; }

  echo "🛠  Compiling…"
  mix compile

  echo "🗃  Running DB setup…"
  mix ecto.migrate
  mix run priv/repo/seeds.exs || true
  mix seed || true

  echo "🔍  Static analysis…"
  mix credo --strict || true
  mix dialyzer --halt-exit-status || true

  echo "🧪  Running tests…"
  mix test --cover
else
  echo "ℹ️  mix.exs not found – skipping Elixir steps"
fi


echo "✅  Codex setup finished."
