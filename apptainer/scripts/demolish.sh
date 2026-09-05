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

apptainer instance stop "$INSTANCE" >/dev/null 2>&1 || true
echo "stopped instance $INSTANCE"

if [ -f "$RUN_ROOT/proxy/docker-compose.yml" ]; then
  docker compose -f "$RUN_ROOT/proxy/docker-compose.yml" down >/dev/null 2>&1 || true
fi
docker rm -f "$PROXY_NAME" >/dev/null 2>&1 || true
echo "stopped proxy $PROXY_NAME"

if [ ! -d "$RUN_ROOT" ]; then
  echo "no runtime state at $RUN_ROOT"
  exit 0
fi

echo
echo "About to delete $RUN_ROOT"
echo "  media:  $(find "$RUN_ROOT/persist/media" -type f 2>/dev/null | wc -l) files"
echo "  static: $(find "$RUN_ROOT/persist/static" -type f 2>/dev/null | wc -l) files"
echo "Media is not regenerable. Back it up first if it matters."

if ! $confirm; then
  read -r -p "Type the run root name to confirm: " reply
  [ "$reply" = "$(basename "$RUN_ROOT")" ] || { echo "aborted"; exit 1; }
fi

rm -rf "${RUN_ROOT:?}"
echo "deleted $RUN_ROOT"
