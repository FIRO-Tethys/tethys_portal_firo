#!/usr/bin/env bash
# demolish.sh - stop the portal and delete its runtime state
# Usage: ./demolish.sh [--yes]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_ROOT="${RUN_ROOT:-$HERE/../../../firo-uvx-run}"
INSTANCE="${INSTANCE:-firo_portal}"
PROXY_NAME="${PROXY_NAME:-firo_uvx_proxy}"

confirm=false
[ "${1:-}" = "--yes" ] && confirm=true

echo "This will stop and delete:"
echo "  instance:  $INSTANCE"
echo "  proxy:     $PROXY_NAME"
echo "  run root:  $RUN_ROOT"
if [ -d "$RUN_ROOT" ]; then
  echo "  media:     $(find "$RUN_ROOT/persist/media" -type f 2>/dev/null | wc -l) files (not regenerable)"
  echo "  static:    $(find "$RUN_ROOT/persist/static" -type f 2>/dev/null | wc -l) files"
else
  echo "  (run root does not exist)"
fi

if ! $confirm; then
  read -r -p "Type the run root name to confirm: " reply
  [ "$reply" = "$(basename "$RUN_ROOT")" ] || { echo "aborted; nothing was stopped or deleted"; exit 1; }
fi

apptainer instance stop "$INSTANCE" >/dev/null 2>&1 || true
[ -f "$RUN_ROOT/proxy/docker-compose.yml" ] &&
  docker compose -f "$RUN_ROOT/proxy/docker-compose.yml" down >/dev/null 2>&1 || true
docker rm -f "$PROXY_NAME" >/dev/null 2>&1 || true
rm -rf "${RUN_ROOT:?}"

echo "stopped $INSTANCE and $PROXY_NAME; deleted $RUN_ROOT"
