#!/usr/bin/env bash
# build_image.sh - helper for building the FIRO Portal Apptainer image
# Usage: ./build_image.sh [DEF_FILE] [OUTPUT_SIF] [PROXY_USER]
#   or: PROXY_USER=myuser ./build_image.sh

set -euo pipefail          # exit on any error, unset var, or failed pipe

DEF_FILE="${1:-firo_portal.def}"
OUT_SIF="${2:-../firo-portal-singularity_latest.sif}"
PROXY_USER="${PROXY_USER:-${3:-www}}"

OUT_DIR="$(cd "$(dirname "$OUT_SIF")" && pwd)"
export APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-$OUT_DIR/.apptainer-tmp}"
mkdir -p "$APPTAINER_TMPDIR"

avail_kb="$(df -Pk "$APPTAINER_TMPDIR" | awk 'NR==2{print $4}')"
avail_gb=$(( avail_kb / 1024 / 1024 ))
if [ "$avail_gb" -lt 15 ]; then
  echo "WARNING: only ${avail_gb}G free on $APPTAINER_TMPDIR." >&2
  echo "         This build needs roughly 15G of scratch. Set APPTAINER_TMPDIR" >&2
  echo "         to a larger filesystem to avoid failing at the squashfs step." >&2
fi

echo "▶ Building image: ${OUT_SIF} from ${DEF_FILE}..."
echo "  scratch: ${APPTAINER_TMPDIR} (${avail_gb}G free)"

build_args=()
if grep -q '{{ *PROXY_USER *}}' "${DEF_FILE}"; then
  build_args+=(--build-arg "PROXY_USER=${PROXY_USER}")
  echo "  proxy user: ${PROXY_USER}"
fi

apptainer build "${build_args[@]}" --fakeroot --fix-perms "${OUT_SIF}" "${DEF_FILE}"
echo "✔ Done: ${OUT_SIF}"
