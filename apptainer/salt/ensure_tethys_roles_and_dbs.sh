#!/usr/bin/env bash
set -euo pipefail

log() { echo "[ensure-tethys-db] $*"; }
die() { echo "[ensure-tethys-db] ERROR: $*" >&2; exit 1; }

# ---- Required env vars (from your deployment/secrets) ----
: "${TETHYS_DB_USERNAME:?TETHYS_DB_USERNAME is required}"
: "${TETHYS_DB_PASSWORD:?TETHYS_DB_PASSWORD is required}"
: "${TETHYS_DB_SUPERUSER:?TETHYS_DB_SUPERUSER is required}"
: "${TETHYS_DB_SUPERUSER_PASS:?TETHYS_DB_SUPERUSER_PASS is required}"

# Admin connection (postgres role)
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required to connect as admin (postgres)}"

# ---- Optional env vars (safe defaults) ----
TETHYS_DB_HOST="${TETHYS_DB_HOST:-localhost}"
TETHYS_DB_PORT="${TETHYS_DB_PORT:-5432}"
POSTGRES_ADMIN_USER="${POSTGRES_ADMIN_USER:-postgres}"

# "Associated DB" names (override if you want)
# Common: TETHYS_DB_NAME=tethys_platform (portal DB)
TETHYS_DB_NAME="${TETHYS_DB_NAME:-$TETHYS_DB_USERNAME}"
TETHYS_DB_SUPERUSER_DB_NAME="${TETHYS_DB_SUPERUSER_DB_NAME:-$TETHYS_DB_SUPERUSER}"

export PGPASSWORD="${POSTGRES_PASSWORD}"

# ---- Safety: reject names that would break quoting ----
reject_bad_ident() {
  local v="$1" label="$2"
  if [[ "$v" == *'"'* ]]; then
    die "$label contains a double quote, which is not supported safely: $v"
  fi
}
reject_bad_ident "$TETHYS_DB_USERNAME" "TETHYS_DB_USERNAME"
reject_bad_ident "$TETHYS_DB_SUPERUSER" "TETHYS_DB_SUPERUSER"
reject_bad_ident "$TETHYS_DB_NAME" "TETHYS_DB_NAME"
reject_bad_ident "$TETHYS_DB_SUPERUSER_DB_NAME" "TETHYS_DB_SUPERUSER_DB_NAME"

psql_admin() {
  psql \
    -h "$TETHYS_DB_HOST" \
    -p "$TETHYS_DB_PORT" \
    -U "$POSTGRES_ADMIN_USER" \
    -d postgres \
    -v ON_ERROR_STOP=1 \
    -A -t -q \
    -c "$1"
}

sql_escape_literal() {
  # escape single quotes for SQL literal strings
  printf "%s" "$1" | sed "s/'/''/g"
}

role_exists() {
  local role esc out
  role="$1"
  esc="$(sql_escape_literal "$role")"
  out="$(psql_admin "SELECT 1 FROM pg_roles WHERE rolname='${esc}';" || true)"
  [[ "$out" == "1" ]]
}

role_is_superuser() {
  local role esc out
  role="$1"
  esc="$(sql_escape_literal "$role")"
  out="$(psql_admin "SELECT rolsuper FROM pg_roles WHERE rolname='${esc}';" || true)"
  [[ "$out" == "t" || "$out" == "true" || "$out" == "1" ]]
}

db_exists() {
  local db esc out
  db="$1"
  esc="$(sql_escape_literal "$db")"
  out="$(psql_admin "SELECT 1 FROM pg_database WHERE datname='${esc}';" || true)"
  [[ "$out" == "1" ]]
}

db_owner() {
  local db esc out
  db="$1"
  esc="$(sql_escape_literal "$db")"
  out="$(psql_admin "SELECT pg_catalog.pg_get_userbyid(datdba) FROM pg_database WHERE datname='${esc}';" || true)"
  printf "%s" "$out"
}

ensure_superuser_role() {
  local role="$1" pass="$2"
  local role_lit pass_lit
  role_lit="$(sql_escape_literal "$role")"
  pass_lit="$(sql_escape_literal "$pass")"

  if role_exists "$role"; then
    log "Role \"$role\" exists; ensuring it is SUPERUSER and setting password."
  else
    log "Role \"$role\" missing; creating SUPERUSER role."
  fi

  # Create if missing (idempotent)
  psql_admin "
DO \$do\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${role_lit}') THEN
    CREATE ROLE \"${role}\" LOGIN PASSWORD '${pass_lit}';
  END IF;
END
\$do\$;
"

  # Force desired properties (idempotent)
  psql_admin "ALTER ROLE \"${role}\" WITH LOGIN SUPERUSER CREATEDB CREATEROLE PASSWORD '${pass_lit}';"
}

ensure_normal_role() {
  local role="$1" pass="$2"
  local role_lit pass_lit
  role_lit="$(sql_escape_literal "$role")"
  pass_lit="$(sql_escape_literal "$pass")"

  if role_exists "$role"; then
    log "Role \"$role\" exists; ensuring it is NON-superuser and setting password."
  else
    log "Role \"$role\" missing; creating normal role."
  fi

  # Create if missing (idempotent)
  psql_admin "
DO \$do\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${role_lit}') THEN
    CREATE ROLE \"${role}\" LOGIN PASSWORD '${pass_lit}';
  END IF;
END
\$do\$;
"

  # Force desired properties (idempotent)
  psql_admin "ALTER ROLE \"${role}\" WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '${pass_lit}';"
}

create_db() {
  local owner="$1" db="$2"
  log "Creating database \"$db\" owned by \"$owner\"..."
  createdb \
    -h "$TETHYS_DB_HOST" \
    -p "$TETHYS_DB_PORT" \
    -U "$POSTGRES_ADMIN_USER" \
    -E utf8 \
    -O "$owner" \
    "$db"
}

ensure_db_owned_by() {
  local db="$1" owner="$2"

  if db_exists "$db"; then
    log "Database \"$db\" already exists (ok)."
  else
    create_db "$owner" "$db"
  fi

  # Ensure correct owner (helps prevent permission issues)
  local current_owner
  current_owner="$(db_owner "$db" || true)"
  if [[ -n "$current_owner" && "$current_owner" != "$owner" ]]; then
    log "Fixing owner of \"$db\": \"$current_owner\" -> \"$owner\""
    psql_admin "ALTER DATABASE \"${db}\" OWNER TO \"${owner}\";"
  fi

  # Ensure role can connect (harmless if already granted)
  psql_admin "GRANT CONNECT ON DATABASE \"${db}\" TO \"${owner}\";"
}

# ---- FIX A: create/repair roles directly (no tethys db create fallback) ----
ensure_superuser_role "$TETHYS_DB_SUPERUSER" "$TETHYS_DB_SUPERUSER_PASS"
ensure_normal_role "$TETHYS_DB_USERNAME" "$TETHYS_DB_PASSWORD"

# ---- Ensure associated DBs exist and are owned correctly ----
ensure_db_owned_by "$TETHYS_DB_SUPERUSER_DB_NAME" "$TETHYS_DB_SUPERUSER"
ensure_db_owned_by "$TETHYS_DB_NAME" "$TETHYS_DB_USERNAME"

log "All roles and databases present."