#!/usr/bin/env bash
set -euo pipefail

args=()

[ -n "${PORTAL_STATIC_ROOT:-}" ]     && args+=(--set TETHYS_PORTAL_CONFIG.STATIC_ROOT "$PORTAL_STATIC_ROOT")
[ -n "${PORTAL_MEDIA_ROOT:-}" ]      && args+=(--set TETHYS_PORTAL_CONFIG.MEDIA_ROOT "$PORTAL_MEDIA_ROOT")
[ -n "${PORTAL_WORKSPACES_ROOT:-}" ] && args+=(--set TETHYS_PORTAL_CONFIG.TETHYS_WORKSPACES_ROOT "$PORTAL_WORKSPACES_ROOT")
[ -n "${PORTAL_STATIC_URL:-}" ]      && args+=(--set TETHYS_PORTAL_CONFIG.STATIC_URL "$PORTAL_STATIC_URL")
[ -n "${PORTAL_MEDIA_URL:-}" ]       && args+=(--set TETHYS_PORTAL_CONFIG.MEDIA_URL "$PORTAL_MEDIA_URL")
[ -n "${PORTAL_PREFIX_URL:-}" ]      && args+=(--set PREFIX_URL "$PORTAL_PREFIX_URL")

if [ ${#args[@]} -gt 0 ]; then
  tethys settings "${args[@]}"
fi
