#!/usr/bin/env bash
set -euo pipefail

# ───────────── defaults ─────────────
binds="../nginx_logs:/var/log/nginx,\
../salt_logs:/var/log/salt,\
../tethys_logs:/var/log/tethys,\
./tethys_persist:/var/lib/tethys_persist,\
./custom_themes/tethysext-default_theme:/usr/lib/tethys/ext/tethysext-default_theme,\
../supervisor_logs:/var/log/supervisor"
envfile="dev.env"
sif="../firo-portal-singularity_latest.sif"
fresh=false

usage() {
  cat <<EOF
Usage: $0 [--fresh] [--bind host:ctr[,..]] [--envfile FILE] [--sif IMAGE]
EOF
  exit 1
}

# ───────────── parse CLI ─────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --fresh)    fresh=true ;;
    --bind)     binds=$2; shift ;;
    --envfile)  envfile=$2; shift ;;
    --sif)      sif=$2; shift ;;
    -h|--help)  usage ;;
    *) echo "Unknown option $1"; usage ;;
  esac
  shift
done
IFS=',' read -ra bind_arr <<< "$binds"

# ───────────── docker helpers ─────────────
start_docker() {
  local cname=$1 image=$2 args=$3
  if ! docker inspect -f '{{.State.Running}}' "$cname" &>/dev/null; then
    echo "Starting $cname…"
    eval docker run --rm --name="$cname" $args -d "$image"
  else
    echo "$cname already running"
  fi
}

# helper that deletes a host directory contents
wipe_dir() {
    local target=$1
    # First try unprivileged
    rm -rf -- "${target:?}"/{*,.[!.]*} 2>/tmp/rm_err$$ || true
    if grep -q "Permission denied" /tmp/rm_err$$ ; then
        echo "  ↳ need sudo for ${target} (permission denied)"
        sudo rm -rf -- "${target:?}"/{*,.[!.]*}
    fi
    rm -f /tmp/rm_err$$
}

# ─────── FRESH cleanup ────────────────────────────────────────────────
if $fresh; then
  echo "Fresh start requested — removing existing containers and data"
  docker rm -f firo_redis firo_postgis 2>/dev/null || true

  if apptainer instance list | grep -q "^firo_portal[[:space:]]"; then
      echo "Stopping existing Apptainer instance: firo_portal"
      apptainer instance stop firo_portal
  fi

  for b in "${bind_arr[@]}"; do
      host=${b%%:*}           # part before ':'
      if [[ $host = /* || $host = .* ]]; then
          echo "  - deleting ${host}/*"
          wipe_dir "$host"
      fi
  done
fi

# ───────────── ensure redis + postgis ─────────────
start_docker firo_postgis postgis/postgis:17-3.5 \
  "-e POSTGRES_PASSWORD=pass -p 5437:5432"
start_docker firo_redis redis:7 "-p 6379:6379"

# ───────────── build -B flags for apptainer ─────────────
bind_flags=()
for b in "${bind_arr[@]}"; do
  bind_flags+=(-B "$b")
done



# ───────────── start Apptainer instance ─────────────
apptainer instance start \
  --fakeroot \
  --writable-tmpfs \
  "${bind_flags[@]}" \
  --env-file "$envfile" \
  "$sif" firo_portal

echo "✔  firo_portal instance and backing services are up."
