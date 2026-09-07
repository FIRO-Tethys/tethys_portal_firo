#!/usr/bin/env bash
# build_image.sh - build the FIRO Portal Apptainer image
# Usage: ./build_image.sh [DEF_FILE] [OUTPUT_SIF]

set -euo pipefail

DEF_FILE="${1:-firo_portal.def}"
OUT_SIF="${2:-../firo-portal-uvx.sif}"

[ -f "$DEF_FILE" ] || { echo "definition file not found: $DEF_FILE" >&2; exit 1; }

mkdir -p "$(dirname "$OUT_SIF")"
OUT_DIR="$(cd "$(dirname "$OUT_SIF")" && pwd)"

export APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-$OUT_DIR/.apptainer-tmp}"
mkdir -p "$APPTAINER_TMPDIR"

avail_gb=$(( $(df -Pk "$APPTAINER_TMPDIR" | awk 'NR==2{print $4}') / 1024 / 1024 ))
[ "$avail_gb" -ge 15 ] || echo "WARNING: ${avail_gb}G free on $APPTAINER_TMPDIR; this build needs ~15G. Set APPTAINER_TMPDIR elsewhere." >&2

echo "Building $OUT_SIF from $DEF_FILE (scratch: $APPTAINER_TMPDIR, ${avail_gb}G free)"
apptainer build --force --fakeroot --fix-perms "$OUT_SIF" "$DEF_FILE"
echo "Done: $OUT_SIF"
