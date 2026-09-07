#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

SIF="${SIF:-$REPO_ROOT/../firo-portal-uvx.sif}"
RUN_ROOT="${RUN_ROOT:-$REPO_ROOT/../firo-uvx-run}"
INSTANCE="${INSTANCE:-firo_portal}"
ENV_FILE="${ENV_FILE:-$RUN_ROOT/portal.env}"

TETHYS_HOME_HOST="$RUN_ROOT/portal"
PERSIST_HOST="$RUN_ROOT/persist"
LOG_HOST="$RUN_ROOT/log"
PROXY_PORT="${PROXY_PORT:-80}"
PORTAL_GROUP="${PORTAL_GROUP:-}"
PORTAL_UMASK="${PORTAL_UMASK:-0022}"
PY=/opt/conda/envs/tethys/bin/python
GUNICORNC=/opt/conda/envs/tethys/bin/gunicornc
CTL_SOCKET=/home/tethys/portal/gunicorn.ctl
CTL_SOCKET_HOST="$TETHYS_HOME_HOST/gunicorn.ctl"

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
  reload      apply portal_config.yml changes with no downtime (SIGHUP)
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

apptainer_args() {
  APPTAINER_ARGS=(
    -B "$TETHYS_HOME_HOST:/home/tethys/portal"
    -B "$PERSIST_HOST:/home/tethys/persist"
    -B "$LOG_HOST:/home/tethys/log"
    --env "SERVER=${SERVER:-gunicorn}"
    --env CREATE_SUPERUSER=false
    --env "GUNICORN_CMD_ARGS=--control-socket $CTL_SOCKET"
    --env-file "$ENV_FILE"
  )
}

in_image() {
  local writable=()
  [ "${1:-}" = "--writable-tmpfs" ] && { writable=(--writable-tmpfs); shift; }
  umask "$PORTAL_UMASK"
  apptainer_args
  apptainer exec "${writable[@]}" "${APPTAINER_ARGS[@]}" "$SIF" bash -c "$1"
}

wait_http() {
  local url="$1" label="$2" code=000
  printf '  waiting for %s' "$label"
  for _ in $(seq 1 30); do
    code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 5 "$url" 2>/dev/null || echo 000)
    case "$code" in 200|302) break ;; esac
    printf '.'; sleep 2
  done
  echo
  case "$code" in
    200|302) return 0 ;;
    *) return 1 ;;
  esac
}

check_db() {
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

  in_image --writable-tmpfs '/usr/local/bin/publish-static.sh'
  ok "static published"

  if [ -d "$REPO_ROOT/conf/init.d" ]; then
    for hook in "$REPO_ROOT"/conf/init.d/*.sh; do
      [ -e "$hook" ] || continue
      in_image --writable-tmpfs "bash /opt/portal/init.d/$(basename "$hook")"
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

  if apptainer instance list 2>/dev/null | awk -v n="$INSTANCE" '$1==n{found=1} END{exit !found}'; then
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

  umask "$PORTAL_UMASK"
  apptainer_args
  apptainer instance start "${APPTAINER_ARGS[@]}" "$SIF" "$INSTANCE"

  local url="http://localhost:${TETHYS_PORT}${PREFIX_URL:-}/"
  wait_http "$url" "HTTP" \
    && ok "portal serving at $url" \
    || die "portal not serving at $url -- check $LOG_HOST and apptainer instance list"
}

cmd_proxy() {
  load_env
  log "Starting the Apache front end on ${PROXY_PORT}"
  PROXY_PORT="$PROXY_PORT" PORTAL_PORT="$TETHYS_PORT" TETHYS_PERSIST="$PERSIST_HOST" \
    docker compose -f "$REPO_ROOT/apptainer/dev/docker-compose.yml" up -d >/dev/null 2>&1 \
    || die "proxy failed to start; check apptainer/dev/logs/error.log"

  local url="http://localhost:${PROXY_PORT}${PREFIX_URL:-}/"
  wait_http "$url" "proxy" \
    && ok "proxy serving at $url -> portal on ${TETHYS_PORT}" \
    || die "proxy not serving at $url"
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

gunicornc_workers() {
  apptainer exec "instance://$INSTANCE" "$GUNICORNC" -s "$CTL_SOCKET" -c "show workers" -j 2>/dev/null
}

pids_of() {
  grep -oE '"pid":[[:space:]]*[0-9]+' | grep -oE '[0-9]+$' | sort -n | tr '\n' ' ' || true
}

cmd_reload() {
  load_env
  apptainer instance list 2>/dev/null | awk -v n="$INSTANCE" '$1==n{found=1} END{exit !found}' \
    || die "instance $INSTANCE is not running"

  local dbg raw before after i overlap w replaced=0
  dbg=$(apptainer exec "instance://$INSTANCE" "$PY" -c \
    'import yaml; c = yaml.safe_load(open("/home/tethys/portal/portal_config.yml")) or {}; print(str((c.get("settings") or {}).get("DEBUG", False)).lower())' 2>/dev/null) \
    || die "portal_config.yml is not valid YAML; refusing to reload"
  [ "$dbg" = "true" ] \
    && die "DEBUG is true, so the portal runs under runserver, which has no control socket; restart instead of reloading"

  raw=$(gunicornc_workers) \
    || die "no gunicorn control socket at $CTL_SOCKET_HOST; the master may have died -- check $LOG_HOST"
  before=" $(printf '%s' "$raw" | pids_of)"

  apptainer exec "instance://$INSTANCE" "$GUNICORNC" -s "$CTL_SOCKET" -c "reload" >/dev/null 2>&1 \
    || die "gunicornc did not accept reload at $CTL_SOCKET_HOST"

  for i in $(seq 1 45); do
    raw=$(gunicornc_workers) \
      || die "the gunicorn master stopped responding during reload; the portal is DOWN. Restore portal_config.yml, then: $0 stop && $0 serve"
    after=" $(printf '%s' "$raw" | pids_of)"
    if [ "$after" != " " ]; then
      overlap=0
      for w in $after; do case "$before" in *" $w "*) overlap=1 ;; esac; done
      [ "$overlap" = 0 ] && { replaced=1; break; }
    fi
    sleep 1
  done
  [ "$replaced" = 1 ] \
    || die "workers were not replaced within 45s; the reload did not take effect and the portal is still serving the old config"

  local url="http://localhost:${TETHYS_PORT}${PREFIX_URL:-}/"
  wait_http "$url" "portal" \
    && ok "reloaded $INSTANCE (workers${after} )" \
    || die "the new worker is not serving; the portal is DOWN. Restore portal_config.yml, then: $0 stop && $0 serve"
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
  reload) cmd_reload ;;
  destroy) shift; cmd_destroy "$@" ;;
  status) cmd_status ;;
  *) usage ;;
esac
