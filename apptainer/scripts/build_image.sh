#!/usr/bin/env bash
# build_image.sh – helper for building the FIRO Portal Apptainer image
# Usage: ./build_image.sh [DEF_FILE] [OUTPUT_SIF] [PROXY_USER]
#   or: PROXY_USER=myuser ./build_image.sh

set -euo pipefail          # exit on any error, unset var, or failed pipe

DEF_FILE="${1:-firo_portal.def}"
OUT_SIF="${2:-../firo-portal-singularity_latest.sif}"
PROXY_USER="${PROXY_USER:-${3:-www}}"

# Stage the build on the same filesystem as the output image, not on /tmp.
# Apptainer defaults APPTAINER_TMPDIR to /tmp, which on many hosts (and in WSL)
# is a small tmpfs. The uncompressed rootfs for this image is several GB, so
# mksquashfs dies with "No space left on device" at the very end of a ~15 minute
# build, after %post has already succeeded. Overridable if you want it elsewhere.
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

echo "▶ Building image: ${OUT_SIF} from ${DEF_FILE} with user: ${PROXY_USER}..."
echo "  scratch: ${APPTAINER_TMPDIR} (${avail_gb}G free)"

# --fakeroot is implied for an unprivileged build from a definition file, and is
# passed explicitly here so the intent survives a reader who has not read the
# Apptainer docs. No sudo is required, and none should ever be added.
apptainer build --build-arg PROXY_USER="${PROXY_USER}" --fakeroot --fix-perms "${OUT_SIF}" "${DEF_FILE}"
echo "✔ Done: ${OUT_SIF}"
