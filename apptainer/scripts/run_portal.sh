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

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m  ok  %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mFATAL: %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 <command>

  dirs        create the host directories the container binds
  provision   portal-config, db migrate, publish-static, portal init.d hooks
  serve       start the instance
  stop        stop the instance
  status      show what is listening and whether the portal answers

Env: SIF, RUN_ROOT, INSTANCE, ENV_FILE
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

binds() {
  printf '%s' \
    "-B $TETHYS_HOME_HOST:/home/tethys/portal " \
    "-B $PERSIST_HOST:/home/tethys/persist " \
    "-B $LOG_HOST:/home/tethys/log"
}

in_image() {
  load_env
  # shellcheck disable=SC2046
  apptainer exec $(binds) --env-file "$ENV_FILE" "$SIF" bash -c "$1"
}

in_image_writable() {
  load_env
  # shellcheck disable=SC2046
  apptainer exec --writable-tmpfs $(binds) --env-file "$ENV_FILE" "$SIF" bash -c "$1"
}

cmd_dirs() {
  log "Creating host directories"
  mkdir -p "$TETHYS_HOME_HOST/keys" "$PERSIST_HOST"/{static,media,workspaces} "$LOG_HOST"
  ok "$RUN_ROOT"
}

cmd_provision() {
  load_env
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
  log "Starting $INSTANCE"

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
  apptainer instance start $(binds) --env-file "$ENV_FILE" "$SIF" "$INSTANCE"

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
  provision) cmd_provision ;;
  serve) cmd_serve ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  *) usage ;;
esac
