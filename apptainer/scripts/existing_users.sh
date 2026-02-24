#!/usr/bin/env bash
set -euo pipefail

# ───────────── defaults ─────────────
binds="../nginx_logs:/var/log/nginx,\
../salt_logs:/var/log/salt,\
../tethys_logs:/var/log/tethys,\
./tethys_persist:/var/lib/tethys_persist,\
./custom_themes/tethysext-default_theme:/usr/lib/tethys/ext/tethysext-default_theme,\
../supervisor_logs:/var/log/supervisor"

envfile="dev.env"
sif="../firo-portal-singularity_latest.sif"

fresh=false
seed_super=true         # default: seed superuser
seed_normal=false       # default: do NOT seed normal user unless asked

usage() {
  cat <<EOF
Usage: $0 [--fresh] [--seed-normal] [--seed-super|--no-seed-super] [--bind host:ctr[,..]] [--envfile FILE] [--sif IMAGE]

  --fresh          Stop apptainer instance, remove docker containers, wipe bind host dirs (except protected).
  --seed-normal    Also pre-create TETHYS_DB_USERNAME role+db (default: false)
  --seed-super     Pre-create TETHYS_DB_SUPERUSER role+db (default: true)
  --no-seed-super  Do not pre-create the superuser role+db
  --bind           Override bind list (comma-separated)
  --envfile        Env file to load (bash KEY=VALUE)
  --sif            Apptainer image path
EOF
  exit 1
}

# ───────────── parse CLI ─────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --fresh) fresh=true ;;
    --seed-normal) seed_normal=true ;;
    --seed-super) seed_super=true ;;
    --no-seed-super) seed_super=false ;;
    --bind) binds=$2; shift ;;
    --envfile) envfile=$2; shift ;;
    --sif) sif=$2; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option $1"; usage ;;
  esac
  shift
done
IFS=',' read -ra bind_arr <<< "$binds"

# ───────────── helpers ─────────────
wipe_dir() {
  local target=$1
  rm -rf -- "${target:?}"/{*,.[!.]*} 2>/tmp/rm_err$$ || true
  if grep -q "Permission denied" /tmp/rm_err$$ ; then
    echo "  ↳ need sudo for ${target} (permission denied)"
    sudo rm -rf -- "${target:?}"/{*,.[!.]*}
  fi
  rm -f /tmp/rm_err$$
}

start_docker() {
  local cname=$1 image=$2 args=$3
  if docker ps -q -f "name=^/${cname}$" | grep -q .; then
    echo "$cname already running"
    return 0
  fi
  docker rm -f "$cname" 2>/dev/null || true
  echo "Starting $cname…"
  eval docker run --rm --name="$cname" $args -d "$image"
}

# ───────────── load env file ─────────────
set -a
# shellcheck disable=SC1090
. "$envfile"
set +a

# Always required to start db container + run psql/createdb as admin
: "${POSTGRES_PASSWORD:?missing}"

# Required only if you seed that role
if $seed_super; then
  : "${TETHYS_DB_SUPERUSER:?missing}"
  : "${TETHYS_DB_SUPERUSER_PASS:?missing}"
fi
if $seed_normal; then
  : "${TETHYS_DB_USERNAME:?missing}"
  : "${TETHYS_DB_PASSWORD:?missing}"
fi

# Host/port your portal should use to reach docker-mapped Postgres
TETHYS_DB_HOST="${TETHYS_DB_HOST:-127.0.0.1}"
POSTGRES_PORT="${POSTGRES_PORT:-5437}"

cname="firo_postgis"

# ───────────── FRESH cleanup ─────────────
if $fresh; then
  echo "Fresh start requested — removing existing containers and data"

  if apptainer instance list | grep -q "^firo_portal[[:space:]]"; then
    echo "Stopping existing Apptainer instance: firo_portal"
    apptainer instance stop firo_portal
  fi

  docker rm -f firo_postgis firo_redis 2>/dev/null || true

  readonly keep_paths=("./custom_themes/tethysext-default_theme")

  for b in "${bind_arr[@]}"; do
    host=${b%%:*}  # before ':'

    if printf '%s\n' "${keep_paths[@]}" | grep -qx "$host"; then
      echo "  - keeping ${host} (protected)"
      continue
    fi

    if [[ $host = /* || $host = .* ]]; then
      echo "  - deleting ${host}/*"
      wipe_dir "$host"
    fi
  done
fi

# ───────────── ensure postgis is running ─────────────
start_docker firo_postgis postgis/postgis:17-3.5 \
  "-e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} -p 5437:5432"

echo "Waiting for Postgres to be ready..."
for i in {1..60}; do
  if docker exec "$cname" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker exec "$cname" pg_isready -U postgres -d postgres >/dev/null

psql_admin() {
  docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" "$cname" \
    psql -U postgres -d postgres -v ON_ERROR_STOP=1 -A -t -q -c "$1"
}

db_exists() {
  local d="$1"
  [[ "$(psql_admin "SELECT 1 FROM pg_database WHERE datname='${d//\'/\'\'}';")" == "1" ]]
}

ensure_superuser_role() {
  local role="$1" pass="$2"
  echo "Seeding superuser role: $role"
  psql_admin "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${role//\'/\'\'}') THEN
    CREATE ROLE \"${role}\" LOGIN PASSWORD '${pass//\'/\'\'}';
  END IF;
END
\$\$;
"
  psql_admin "ALTER ROLE \"${role}\" WITH SUPERUSER CREATEDB CREATEROLE LOGIN PASSWORD '${pass//\'/\'\'}';"
}

ensure_normal_role() {
  local role="$1" pass="$2"
  echo "Seeding normal role: $role"
  psql_admin "
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${role//\'/\'\'}') THEN
    CREATE ROLE \"${role}\" LOGIN PASSWORD '${pass//\'/\'\'}';
  END IF;
END
\$\$;
"
  psql_admin "ALTER ROLE \"${role}\" WITH NOSUPERUSER NOCREATEDB NOCREATEROLE LOGIN PASSWORD '${pass//\'/\'\'}';"
}

ensure_db_owned_by() {
  local db="$1" owner="$2"
  if db_exists "$db"; then
    echo "Database exists: $db"
  else
    echo "Creating database $db owned by $owner"
    docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" "$cname" \
      createdb -U postgres -O "$owner" "$db"
  fi
}

# ───────────── seed scenario ─────────────
if $seed_super; then
  ensure_superuser_role "$TETHYS_DB_SUPERUSER" "$TETHYS_DB_SUPERUSER_PASS"
  ensure_db_owned_by "$TETHYS_DB_SUPERUSER" "$TETHYS_DB_SUPERUSER"
fi

if $seed_normal; then
  ensure_normal_role "$TETHYS_DB_USERNAME" "$TETHYS_DB_PASSWORD"
  ensure_db_owned_by "$TETHYS_DB_USERNAME" "$TETHYS_DB_USERNAME"
fi

echo "Seed complete. Current roles (filtered):"
roles=()
$seed_super && roles+=("$TETHYS_DB_SUPERUSER")
$seed_normal && roles+=("$TETHYS_DB_USERNAME")
if ((${#roles[@]})); then
  docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" "$cname" psql -U postgres -d postgres -c \
    "\du+ ${roles[*]}" || true
else
  echo "  (no roles were seeded)"
fi

# ───────────── build -B flags and start apptainer ─────────────
bind_flags=()
for b in "${bind_arr[@]}"; do bind_flags+=(-B "$b"); done

if apptainer instance list | grep -q "^firo_portal[[:space:]]"; then
  echo "Stopping existing Apptainer instance: firo_portal"
  apptainer instance stop firo_portal
fi

echo "Starting Apptainer instance..."
apptainer instance start \
  --fakeroot \
  --writable-tmpfs \
  "${bind_flags[@]}" \
  --env-file "$envfile" \
  "$sif" firo_portal

echo "✔ seeded DB + started firo_portal (fresh=$fresh, seed_super=$seed_super, seed_normal=$seed_normal)."