#!/usr/bin/env bash
#
# run_db_tasks.sh – migrate the Tethys database and sync app stores
#
# Usage:
#   ./run_db_tasks.sh [APP_STORE …]
#   # With no arguments: runs `tethys syncstores tethysdash`
#   # With arguments:   runs `tethys syncstores` for each one
#
# Exit codes:
#   0  – success
#   1+ – a sub-command failed

set -euo pipefail               # ⛑  strict mode
IFS=$'\n\t'

# ────────────────────────────────────────────────────────────────────
# Configuration
# ────────────────────────────────────────────────────────────────────
TETHYS_BIN="/opt/conda/envs/tethys/bin/tethys"   # adjust if you move the env

DEFAULT_STORES=(tethysdash)      # fallback if user passes no args

# ────────────────────────────────────────────────────────────────────
# Helper functions
# ────────────────────────────────────────────────────────────────────
log() {
  # Colored, time-stamped log messages
  local clr_ok="\e[1;32m" clr_info="\e[1;34m" clr_err="\e[1;31m" clr_end="\e[0m"
  local lvl="$1" msg="$2"
  local ts
  ts=$(date "+%Y-%m-%d %H:%M:%S")

  case "$lvl" in
    OK)    printf "%b[%s] %s%b\n"  "$clr_ok"  "$ts" "$msg" "$clr_end" ;;
    INFO)  printf "%b[%s] %s%b\n"  "$clr_info" "$ts" "$msg" "$clr_end" ;;
    ERROR) printf "%b[%s] %s%b\n"  "$clr_err" "$ts" "$msg" "$clr_end" ;;
    *)     printf "[%s] %s\n" "$ts" "$msg" ;;
  esac
}

run() {
  log INFO "➜ $*"
  "$@"
  log OK   "✔ Command finished: $*"
}

# ────────────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────────────
log INFO "Running database migrations and syncing stores …"

run "$TETHYS_BIN" db sync

# decide which stores to sync
STORES=("$@")
[[ ${#STORES[@]} -eq 0 ]] && STORES=("${DEFAULT_STORES[@]}")

for store in "${STORES[@]}"; do
  run "$TETHYS_BIN" syncstores "$store"
done

log OK "All tasks completed successfully."