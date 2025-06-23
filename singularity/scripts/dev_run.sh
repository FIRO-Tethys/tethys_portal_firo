#!/usr/bin/env bash
set -euo pipefail

# ───────────── defaults ─────────────
binds="../nginx_logs:/var/log/nginx,\
../salt_logs:/var/log/salt,\
../tethys_logs:/var/log/tethys,\
tethys_persist:/var/lib/tethys_persist,\
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

# ───────────── FRESH cleanup ─────────────
if $fresh; then
  echo "Fresh start requested — removing existing containers and data"

  # stop & remove containers if they are running
  docker rm -f firo_redis firo_postgis 2>/dev/null || true
  # ─── stop residual instance only if it exists ─────────────────────────
  if apptainer instance list | grep -q "^firo_portal[[:space:]]"; then   # returns 0 ↔ found :contentReference[oaicite:0]{index=0}
      echo "Stopping existing Apptainer instance: firo_portal"
      apptainer instance stop firo_portal                     # clean shutdown :contentReference[oaicite:1]{index=1}
  fi

  # wipe host-side bind directories
  for b in "${bind_arr[@]}"; do
    host=${b%%:*}                # text before first ':' = host path
    # Resolve relative paths for safety, ignore in-container-only binds
    if [[ $host = /* || $host = .* ]]; then
      echo "  - deleting ${host}/*"
      rm -rf -- "${host:?}"/*    # :? prevents blank variable expansion
    fi
  done
fi

# ───────────── ensure redis + postgis ─────────────
start_docker firo_postgis postgis/postgis:12-2.5 \
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
