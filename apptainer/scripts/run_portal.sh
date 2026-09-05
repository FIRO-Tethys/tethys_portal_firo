#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SIF="${SIF:-$REPO_ROOT/../firo-portal-uvx.sif}"
RUN_ROOT="${RUN_ROOT:-$REPO_ROOT/../firo-uvx-run}"
INSTANCE="${INSTANCE:-firo_portal}"
ENV_FILE="${ENV_FILE:-$RUN_ROOT/portal.env}"

TETHYS_HOME_HOST="$RUN_ROOT/portal"
PERSIST_HOST="$RUN_ROOT/persist"
LOG_HOST="$RUN_ROOT/log"
PROXY_PORT="${PROXY_PORT:-8081}"
PORTAL_GROUP="${PORTAL_GROUP:-}"
PORTAL_UMASK="${PORTAL_UMASK:-0022}"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m  ok  %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mFATAL: %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 <command>

  dirs        create the host directories the container binds
  provision   portal-config, db migrate, publish-static, portal init.d hooks
  serve       start the instance
  proxy       start the Apache front end that serves static and media
  stop        stop the instance
  destroy     stop everything and delete the run root (--yes to skip the prompt)
  status      show what is listening and whether the portal answers

Env: SIF, RUN_ROOT, INSTANCE, ENV_FILE, PROXY_PORT,
     PORTAL_GROUP  group owning the bind tree (setgid; new files inherit it)
     PORTAL_UMASK  0022 world-readable (default), 0027 group-only
EOF
  exit 1
}

[ -f "$SIF" ] || die "SIF not found: $SIF"

load_env() {
  [ -f "$ENV_FILE" ] || die "no env file at $ENV_FILE"
  set -a; . "$ENV_FILE"; set +a
  : "${TETHYS_SECRET_KEY:?TETHYS_SECRET_KEY is required}"
  : "${TETHYS_PORT:=8000}"
}

forced_env() {
  printf '%s' "--env SERVER=${SERVER:-gunicorn} --env CREATE_SUPERUSER=false"
}

binds() {
  printf '%s' \
    "-B $TETHYS_HOME_HOST:/home/tethys/portal " \
    "-B $PERSIST_HOST:/home/tethys/persist " \
    "-B $LOG_HOST:/home/tethys/log"
}

in_image() {
  load_env
  # shellcheck disable=SC2046
  umask "$PORTAL_UMASK"
  apptainer exec $(binds) $(forced_env) --env-file "$ENV_FILE" "$SIF" bash -c "$1"
}

in_image_writable() {
  load_env
  # shellcheck disable=SC2046
  umask "$PORTAL_UMASK"
  apptainer exec --writable-tmpfs $(binds) $(forced_env) --env-file "$ENV_FILE" "$SIF" bash -c "$1"
}

check_db() {
  load_env
  local host="${TETHYS_DB_HOST:-localhost}" port="${TETHYS_DB_PORT:-5432}" name="${TETHYS_DB_NAME:-tethys_platform}"
  if ! apptainer exec "$SIF" pg_isready -h "$host" -p "$port" >/dev/null 2>&1; then
    die "no database at ${host}:${port}.
       Start it before serving. Without it the portal's workers fail to boot in
       AppConfig.ready(), and Django reports SynchronousOnlyOperation from the
       async worker context rather than the connection error."
  fi
  ok "database reachable at ${host}:${port} (${name})"
}

cmd_dirs() {
  log "Creating host directories"
  umask "$PORTAL_UMASK"
  mkdir -p "$TETHYS_HOME_HOST/keys" "$PERSIST_HOST"/{static,media,workspaces} "$LOG_HOST"

  if [ -n "$PORTAL_GROUP" ]; then
    getent group "$PORTAL_GROUP" >/dev/null \
      || die "group '$PORTAL_GROUP' does not exist on this host"
    id -nG | tr ' ' '\n' | grep -qx "$PORTAL_GROUP" \
      || die "$(id -un) is not a member of '$PORTAL_GROUP'; chgrp would fail"
    chgrp -R "$PORTAL_GROUP" "$RUN_ROOT"
    find "$RUN_ROOT" -type d -exec chmod g+s {} +
    ok "group $PORTAL_GROUP, setgid on directories so new files inherit it"
  fi

  ok "$RUN_ROOT (owner $(id -un), umask $PORTAL_UMASK)"
}

cmd_provision() {
  load_env
  check_db
  log "Provisioning"
  in_image '/usr/local/bin/portal-config.sh'
  ok "config rendered"

  in_image 'tethys db migrate'
  ok "migrations applied"

  in_image_writable '/usr/local/bin/publish-static.sh'
  ok "static published"

  if [ -d "$REPO_ROOT/conf/init.d" ]; then
    for hook in "$REPO_ROOT"/conf/init.d/*.sh; do
      [ -e "$hook" ] || continue
      in_image_writable "bash /opt/portal/init.d/$(basename "$hook")"
      ok "hook $(basename "$hook")"
    done
  fi
}

cmd_serve() {
  load_env
  check_db
  log "Starting $INSTANCE (server: ${SERVER:-gunicorn})"

  if [ "${SERVER:-gunicorn}" = "uvicorn" ]; then
    echo "  WARNING: plain uvicorn fails at startup for this portal with" >&2
    echo "           SynchronousOnlyOperation; Tethys queries the database in" >&2
    echo "           AppConfig.ready(). Use gunicorn unless that is fixed upstream." >&2
  fi

  if apptainer instance list 2>/dev/null | awk '{print $1}' | grep -qx "$INSTANCE"; then
    apptainer instance stop "$INSTANCE" >/dev/null 2>&1 || true
    printf '  waiting for ports to clear'
    for _ in $(seq 1 30); do
      ss -ltn 2>/dev/null | grep -q ":${TETHYS_PORT} " || break
      printf '.'; sleep 2
    done
    echo
  fi

  if ss -ltn 2>/dev/null | grep -q ":${TETHYS_PORT} "; then
    die "port $TETHYS_PORT already in use; Apptainer shares the host network namespace so the server would not bind"
  fi

  # shellcheck disable=SC2046
  umask "$PORTAL_UMASK"
  apptainer instance start $(binds) $(forced_env) --env-file "$ENV_FILE" "$SIF" "$INSTANCE"

  local url="http://localhost:${TETHYS_PORT}${PREFIX_URL:-}/"
  local code=000
  printf '  waiting for HTTP'
  for _ in $(seq 1 30); do
    code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 5 "$url" 2>/dev/null || echo 000)
    case "$code" in 200|302) break ;; esac
    printf '.'; sleep 2
  done
  echo
  case "$code" in
    200|302) ok "portal serving at $url (HTTP $code)" ;;
    *) die "portal not serving at $url (last HTTP $code) -- check $LOG_HOST and apptainer instance list" ;;
  esac
}

cmd_proxy() {
  load_env
  log "Starting the Apache front end on ${PROXY_PORT}"
  PROXY_PORT="$PROXY_PORT" PORTAL_PORT="$TETHYS_PORT" TETHYS_PERSIST="$PERSIST_HOST" \
    docker compose -f "$REPO_ROOT/apptainer/dev/docker-compose.yml" up -d >/dev/null 2>&1 \
    || die "proxy failed to start; check apptainer/dev/logs/error.log"

  local url="http://localhost:${PROXY_PORT}${PREFIX_URL:-}/" code=000
  printf '  waiting for proxy'
  for _ in $(seq 1 20); do
    code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 5 "$url" 2>/dev/null || echo 000)
    case "$code" in 200|302) break ;; esac
    printf '.'; sleep 2
  done
  echo
  case "$code" in
    200|302) ok "proxy serving at $url -> portal on ${TETHYS_PORT}" ;;
    *) die "proxy not serving at $url (last HTTP $code)" ;;
  esac
}

cmd_destroy() {
  local confirm=false
  [ "${1:-}" = "--yes" ] && confirm=true

  echo "This will stop and delete:"
  echo "  instance:  $INSTANCE"
  echo "  proxy:     compose project in apptainer/dev"
  echo "  run root:  $RUN_ROOT"
  if [ -d "$RUN_ROOT" ]; then
    echo "  media:     $(find "$PERSIST_HOST/media" -type f 2>/dev/null | wc -l) files (not regenerable)"
    echo "  static:    $(find "$PERSIST_HOST/static" -type f 2>/dev/null | wc -l) files"
  else
    echo "  (run root does not exist)"
  fi

  if ! $confirm; then
    read -r -p "Type the run root name to confirm: " reply
    [ "$reply" = "$(basename "$RUN_ROOT")" ] || { echo "aborted; nothing was stopped or deleted"; exit 1; }
  fi

  apptainer instance stop "$INSTANCE" >/dev/null 2>&1 || true
  docker compose -f "$REPO_ROOT/apptainer/dev/docker-compose.yml" down >/dev/null 2>&1 || true
  rm -rf "${RUN_ROOT:?}"
  ok "stopped $INSTANCE and the proxy; deleted $RUN_ROOT"
}

cmd_stop() {
  apptainer instance stop "$INSTANCE" >/dev/null 2>&1 || true
  ok "stopped $INSTANCE"
}

cmd_status() {
  load_env
  apptainer instance list 2>/dev/null | head -3
  ss -ltn 2>/dev/null | grep ":${TETHYS_PORT} " || echo "  nothing on ${TETHYS_PORT}"
  curl -s -o /dev/null -w "  HTTP %{http_code}\n" -L --max-time 8 \
    "http://localhost:${TETHYS_PORT}${PREFIX_URL:-}/" || true
}

case "${1:-}" in
  dirs) cmd_dirs ;;
  proxy) cmd_proxy ;;
  provision) cmd_provision ;;
  serve) cmd_serve ;;
  stop) cmd_stop ;;
  destroy) shift; cmd_destroy "$@" ;;
  status) cmd_status ;;
  *) usage ;;
esac
