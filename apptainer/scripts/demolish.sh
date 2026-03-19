#!/usr/bin/env bash
set -euo pipefail

# ───────────── defaults ─────────────
binds="../nginx_logs:/var/log/nginx,\
../salt_logs:/var/log/salt,\
../tethys_logs:/var/log/tethys,\
./tethys_persist:/var/lib/tethys_persist,\
./custom_themes/tethysext-default_theme:/usr/lib/tethys/ext/tethysext-default_theme,\
../supervisor_logs:/var/log/supervisor"

usage() {
  cat <<EOF
Usage: $0 [--bind host:ctr[,..]]

Stops the firo_portal Apptainer instance, removes backing Docker containers,
and wipes the host bind paths without starting anything again.

  --bind               Override bind list (comma-separated)
EOF
  exit 1
}

# ───────────── parse CLI ─────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --bind) binds=$2; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option $1"; usage ;;
  esac
  shift
done
IFS=',' read -r -a bind_arr <<< "$binds"

# ───────────── helpers ─────────────
canonical_path() {
  realpath -m -- "$1"
}

wipe_dir() {
  local target=$1
  local err_file

  if [[ ! -d "$target" ]]; then
    echo "  - skipping ${target} (not a directory)"
    return
  fi

  err_file=$(mktemp)
  rm -rf -- "${target:?}"/{*,.[!.]*,..?*} 2>"$err_file" || true
  if grep -q "Permission denied" "$err_file"; then
    echo "  ↳ need sudo for ${target} (permission denied)"
    sudo rm -rf -- "${target:?}"/{*,.[!.]*,..?*}
  fi
  rm -f "$err_file"
}

remove_docker() {
  local cname=$1

  if docker inspect "$cname" >/dev/null 2>&1; then
    echo "Removing Docker container: $cname"
    docker rm -f "$cname"
  else
    echo "Docker container not present: $cname"
  fi
}

readonly protected_theme_path="$(canonical_path "./custom_themes/tethysext-default_theme")"

path_is_protected() {
  local candidate
  candidate=$(canonical_path "$1")

  [[ "$candidate" == "$protected_theme_path" ||
     "$candidate" == "$protected_theme_path"/* ||
     "$protected_theme_path" == "$candidate"/* ]]
}

# ───────────── stop services ─────────────
if apptainer instance list | grep -q "^firo_portal[[:space:]]"; then
  echo "Stopping existing Apptainer instance: firo_portal"
  apptainer instance stop firo_portal
else
  echo "Apptainer instance not running: firo_portal"
fi

remove_docker firo_postgis
remove_docker firo_redis

# ───────────── wipe bind paths ─────────────
for b in "${bind_arr[@]}"; do
  host=${b%%:*}

  if path_is_protected "$host"; then
    echo "  - keeping ${host} (protected theme path)"
    continue
  fi

  if [[ $host = /* || $host = .* ]]; then
    echo "  - deleting ${host}/*"
    wipe_dir "$host"
  else
    echo "  - skipping ${host} (not absolute or dot-relative)"
  fi
done

echo "Demolition complete. Nothing was started."
