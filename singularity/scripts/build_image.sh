#!/usr/bin/env bash
# build_sif.sh – simple helper for building the FIRO Portal Apptainer image
# Usage: ./build_sif.sh [DEF_FILE] [OUTPUT_SIF]

set -euo pipefail          # exit on any error, unset var, or failed pipe

DEF_FILE="${1:-firo_portal.def}"
OUT_SIF="${2:-../firo-portal-singularity_latest.sif}"

echo "▶ Building image: ${OUT_SIF} from ${DEF_FILE} ..."
apptainer build --fakeroot --fix-perms "${OUT_SIF}" "${DEF_FILE}"
echo "✔ Done."