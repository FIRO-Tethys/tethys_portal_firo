#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SIF="${SIF:-$REPO_ROOT/../firo-portal-fixture.sif}"
FIXTURE_ROOT="${FIXTURE_ROOT:-$REPO_ROOT/../firo-fixture}"
INSTANCE="${INSTANCE:-firo_fixture}"
PG_NAME="${PG_NAME:-firo_fixture_pg}"
REDIS_NAME="${REDIS_NAME:-firo_fixture_redis}"
SEED_ENV="${SEED_ENV:-$REPO_ROOT/apptainer/fixtures/seed.env}"

FIXTURE_NGINX_PORT="${FIXTURE_NGINX_PORT:-8085}"

PERSIST="$FIXTURE_ROOT/tethys_persist"
LOGS="$FIXTURE_ROOT/logs"
ARTIFACTS="$FIXTURE_ROOT/artifacts"
RUN_ENV="$FIXTURE_ROOT/fixture.env"

MEDIA_IN="/var/lib/tethys_persist/media"

PROXY_DIR="$FIXTURE_ROOT/proxy"
PROXY_PORT="${FIXTURE_PROXY_PORT:-80}"

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ok  %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31mFATAL: %s\033[0m\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [phase ...]

Phases (default: all, in order):
  services   start Postgres + Redis and seed the DB roles
  env        render the fixture env file from seed.env
  start      start the Apptainer instance and wait for salt provisioning
  proxy      start the Apache proxy from dev/ that mimics the production front end
  seed       create the superuser, second user, branding and media
  capture    write portal_config.yml, pg_dump and the media manifest
  verify     assert the fixture is production-shaped and correctly awkward

  reset      wipe the persist tree and drop the DB, so salt re-provisions clean
  teardown   stop the instance and containers (does not delete FIXTURE_ROOT)
  clean      teardown plus delete FIXTURE_ROOT

Env overrides: SIF, FIXTURE_ROOT, INSTANCE, PG_NAME, REDIS_NAME, SEED_ENV
EOF
  exit 1
}

[ -f "$SEED_ENV" ] || die "seed file not found: $SEED_ENV"
set -a; . "$SEED_ENV"; set +a

[ "${FIXTURE_SUPERUSER_NAME:-admin}" != "admin" ] || die \
  "FIXTURE_SUPERUSER_NAME must not be 'admin' -- that hides the CREATE_SUPERUSER hole the fixture exists to expose (see seed.env)"

phase_services() {
  log "Starting Postgres and Redis"
  command -v docker >/dev/null || die "docker not found"

  if ! docker ps --format '{{.Names}}' | grep -qx "$PG_NAME"; then
    docker rm -f "$PG_NAME" >/dev/null 2>&1 || true
    docker run -d --rm --name "$PG_NAME" \
      -e POSTGRES_PASSWORD=pass -p 5437:5432 postgis/postgis:17-3.5 >/dev/null
  fi
  if ! docker ps --format '{{.Names}}' | grep -qx "$REDIS_NAME"; then
    docker rm -f "$REDIS_NAME" >/dev/null 2>&1 || true
    docker run -d --rm --name "$REDIS_NAME" -p 6379:6379 redis:7 >/dev/null
  fi

  printf '  waiting for postgres'
  for _ in $(seq 1 60); do
    docker exec "$PG_NAME" pg_isready -U postgres -d postgres >/dev/null 2>&1 && break
    printf '.'; sleep 1
  done
  echo
  docker exec "$PG_NAME" pg_isready -U postgres -d postgres >/dev/null \
    || die "postgres did not become ready"

  psql_admin() {
    docker exec -e PGPASSWORD=pass "$PG_NAME" \
      psql -U postgres -d postgres -v ON_ERROR_STOP=1 -tAq -c "$1"
  }
  psql_admin "DO \$\$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='chapunato') THEN
        CREATE ROLE chapunato LOGIN PASSWORD 'pass';
      END IF;
    END \$\$;" >/dev/null
  psql_admin "ALTER ROLE chapunato WITH SUPERUSER CREATEDB CREATEROLE LOGIN PASSWORD 'pass';" >/dev/null
  if [ "$(psql_admin "SELECT 1 FROM pg_database WHERE datname='chapunato';")" != "1" ]; then
    docker exec -e PGPASSWORD=pass "$PG_NAME" createdb -U postgres -O chapunato chapunato
  fi
  ok "postgres on 5437, redis on 6379, role 'chapunato' seeded"
}

phase_env() {
  log "Rendering fixture env"
  mkdir -p "$FIXTURE_ROOT" "$PERSIST" "$LOGS"/{nginx,salt,tethys,supervisor} "$ARTIFACTS"

  {
    grep -vE '^(PORTAL_SUPERUSER_|SITE_TITLE|BRAND_TEXT|PRIMARY_COLOR|NGINX_PORT|CSRF_TRUSTED_ORIGINS)' dev.env
    echo
    echo "# --- fixture overrides ---"
    echo "PORTAL_SUPERUSER_NAME=$FIXTURE_SUPERUSER_NAME"
    echo "PORTAL_SUPERUSER_PASSWORD=$FIXTURE_SUPERUSER_PASSWORD"
    echo "PORTAL_SUPERUSER_EMAIL=$FIXTURE_SUPERUSER_EMAIL"
    echo "SITE_TITLE='$FIXTURE_SITE_TITLE'"
    echo "BRAND_TEXT='$FIXTURE_BRAND_TEXT'"
    echo "PRIMARY_COLOR='$FIXTURE_PRIMARY_COLOR'"
    echo "NGINX_PORT=$FIXTURE_NGINX_PORT"
    echo "CSRF_TRUSTED_ORIGINS=\"\\\"[http://localhost:$FIXTURE_NGINX_PORT, http://127.0.0.1:$FIXTURE_NGINX_PORT]\\\"\""
  } > "$RUN_ENV"
  ok "wrote $RUN_ENV (superuser: $FIXTURE_SUPERUSER_NAME)"
}

phase_start() {
  log "Starting the current-image instance"
  [ -f "$SIF" ] || die "SIF not found: $SIF  (build it with apptainer/scripts/build_image.sh)"
  [ -f "$RUN_ENV" ] || die "no fixture env; run the 'env' phase first"

  if apptainer instance list 2>/dev/null | awk '{print $1}' | grep -qx "$INSTANCE"; then
    apptainer instance stop "$INSTANCE" >/dev/null 2>&1 || true
    printf '  waiting for ports to clear'
    for _ in $(seq 1 30); do
      ss -ltn 2>/dev/null | grep -qE ":${FIXTURE_NGINX_PORT} |:${TETHYS_PORT:-8000} " || break
      printf '.'; sleep 2
    done
    echo
  fi

  if ss -ltn 2>/dev/null | grep -q ":${FIXTURE_NGINX_PORT} "; then
    die "port $FIXTURE_NGINX_PORT is already in use on this host.
       Apptainer shares the host network namespace, so nginx would fail to bind and
       crash-loop while everything else looks healthy.
       Re-run with: FIXTURE_NGINX_PORT=<free port> $0 env start"
  fi

  apptainer instance start \
    --fakeroot --writable-tmpfs \
    -B "$LOGS/nginx:/var/log/nginx" \
    -B "$LOGS/salt:/var/log/salt" \
    -B "$LOGS/tethys:/var/log/tethys" \
    -B "$LOGS/supervisor:/var/log/supervisor" \
    -B "$PERSIST:/var/lib/tethys_persist" \
    -B "$REPO_ROOT/apptainer/salt:/srv/salt" \
    --env-file "$RUN_ENV" \
    "$SIF" "$INSTANCE"

  log "Waiting for salt provisioning to finish"
  local markers=(setup_complete tethys_services_complete init_apps_setup_complete)
  for m in "${markers[@]}"; do
    printf '  %s' "$m"
    for _ in $(seq 1 180); do
      [ -f "$PERSIST/$m" ] && break
      printf '.'; sleep 5
    done
    [ -f "$PERSIST/$m" ] || die "marker '$m' never appeared -- check $LOGS/tethys/"
    echo " ok"
  done
  ok "provisioning complete"

  local url="http://localhost:${FIXTURE_NGINX_PORT}${PREFIX_URL:-/firo_apps}/"
  local code=000
  printf '  waiting for HTTP'
  for _ in $(seq 1 30); do
    code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 5 "$url" 2>/dev/null || echo 000)
    case "$code" in 200|302) break ;; esac
    printf '.'; sleep 2
  done
  echo
  case "$code" in
    200|302) ok "portal serving at $url (HTTP $code)" ;;
    *) die "portal not serving at $url (last HTTP $code) -- check $LOGS/nginx/error.log" ;;
  esac
}

in_instance() { apptainer exec "instance://$INSTANCE" bash -c "$1"; }

phase_proxy() {
  log "Starting the Apache proxy (mimics the production front end)"
  command -v docker >/dev/null || die "docker not found"
  mkdir -p "$PROXY_DIR/logs"

  sed "s|host\\.docker\\.internal:8080|host.docker.internal:${FIXTURE_NGINX_PORT}|g" \
    "$REPO_ROOT/dev/proxy-vhost.conf" > "$PROXY_DIR/proxy-vhost.conf"
  cp "$REPO_ROOT/dev/load-mods.conf" "$PROXY_DIR/load-mods.conf"

  cat > "$PROXY_DIR/docker-compose.yml" <<EOF
services:
  proxy:
    image: httpd:2.4
    container_name: firo_fixture_proxy
    ports:
      - "${PROXY_PORT}:80"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ${PROXY_DIR}/proxy-vhost.conf:/usr/local/apache2/conf/extra/proxy-vhost.conf:ro
      - ${PROXY_DIR}/load-mods.conf:/usr/local/apache2/conf/extra/load-mods.conf:ro
      - ${REPO_ROOT}/dev/partials/:/var/www/partials/:ro
      - ${PROXY_DIR}/logs/:/usr/local/apache2/logs
    environment:
      APACHE_LOG_DIR: /usr/local/apache2/logs
    command: >
      sh -c 'echo "Include conf/extra/load-mods.conf"   >> conf/httpd.conf &&
             echo "Include conf/extra/proxy-vhost.conf" >> conf/httpd.conf &&
             httpd-foreground'
EOF
  docker compose -f "$PROXY_DIR/docker-compose.yml" up -d >/dev/null 2>&1 \
    || die "proxy failed to start -- check $PROXY_DIR/logs/error.log"

  local url="http://localhost:${PROXY_PORT}${PREFIX_URL:-/firo_apps}/"
  local code=000
  printf '  waiting for proxy'
  for _ in $(seq 1 20); do
    code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 5 "$url" 2>/dev/null || echo 000)
    case "$code" in 200|302) break ;; esac
    printf '.'; sleep 2
  done
  echo
  case "$code" in
    200|302) ok "proxy serving at $url (HTTP $code) -> portal on ${FIXTURE_NGINX_PORT}" ;;
    *) die "proxy not serving at $url (last HTTP $code) -- check $PROXY_DIR/logs/error.log" ;;
  esac
}

phase_seed() {
  log "Seeding accounts, branding and media"

  local su
  su=$(in_instance "python -c \"
import django,os;os.environ.setdefault('DJANGO_SETTINGS_MODULE','tethys_portal.settings');django.setup()
from django.contrib.auth.models import User
print(','.join(User.objects.filter(is_superuser=True).values_list('username',flat=True)))\"" | tr -d '\r')
  [ -n "$su" ] || die "no superuser was created"
  case ",$su," in
    *,admin,*) die "fixture superuser is 'admin' -- the CREATE_SUPERUSER hole would be hidden; check PORTAL_SUPERUSER_NAME in $RUN_ENV" ;;
  esac
  ok "superuser(s): $su"

  in_instance "python -c \"
import django,os;os.environ.setdefault('DJANGO_SETTINGS_MODULE','tethys_portal.settings');django.setup()
from django.contrib.auth.models import User
u,created=User.objects.get_or_create(username='$FIXTURE_USER_NAME',defaults={'email':'$FIXTURE_USER_EMAIL'})
if created:
    u.set_password('$FIXTURE_USER_PASSWORD'); u.save()
print('created' if created else 'exists')\""
  ok "non-privileged user: $FIXTURE_USER_NAME"

  in_instance "set -e
    mkdir -p '$MEDIA_IN'/fixture
    for i in \$(seq 1 ${FIXTURE_MEDIA_FILLER_COUNT:-5}); do
      printf 'firo fixture media file %s\\n' \"\$i\" > '$MEDIA_IN'/fixture/file_\${i}.txt
    done"
  ok "media filler: ${FIXTURE_MEDIA_FILLER_COUNT:-5} files under media/fixture/ (written in-container)"
}

phase_capture() {
  log "Capturing artifacts"
  mkdir -p "$ARTIFACTS"

  [ -f "$PERSIST/portal_config.yml" ] \
    || die "no portal_config.yml on the persist volume -- post_app.sls should have moved it there"
  cp "$PERSIST/portal_config.yml" "$ARTIFACTS/portal_config.yml"
  ok "portal_config.yml"

  docker exec -e PGPASSWORD=pass "$PG_NAME" \
    pg_dump -U postgres -Fc tethys_platform > "$ARTIFACTS/tethys_platform.dump"
  ok "pg_dump ($(du -h "$ARTIFACTS/tethys_platform.dump" | cut -f1))"

  in_instance "cd '$MEDIA_IN' && find . -type f -exec sha256sum {} + | sort -k2" \
    > "$ARTIFACTS/media.manifest"
  ok "media manifest ($(wc -l < "$ARTIFACTS/media.manifest") files)"

  in_instance "tethys db sync >/dev/null 2>&1; python -c \"
import django,os;os.environ.setdefault('DJANGO_SETTINGS_MODULE','tethys_portal.settings');django.setup()
from tethys_config.models import Setting
for s in Setting.objects.exclude(content='').order_by('name'):
    print(f'{s.name}\t{s.content}')\"" > "$ARTIFACTS/site_settings.tsv" || true
  ok "site settings ($(wc -l < "$ARTIFACTS/site_settings.tsv") non-empty)"

  in_instance "python -c \"
import django,os;os.environ.setdefault('DJANGO_SETTINGS_MODULE','tethys_portal.settings');django.setup()
import tethys_portal;print('tethys',tethys_portal.__version__)
import django as d;print('django',d.__version__)\"" > "$ARTIFACTS/versions.txt"
  in_instance "tethys manage showmigrations 2>/dev/null" > "$ARTIFACTS/migrations.txt" || true
  ok "versions + migration state"
}

phase_verify() {
  log "Verifying the fixture is production-shaped"
  local fail=0
  check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else printf '\033[1;31m  FAIL  %s\033[0m\n' "$1"; fail=1; fi; }

  check "marker files present" "[ -f '$PERSIST/setup_complete' ] && [ -f '$PERSIST/init_apps_setup_complete' ]"
  check "portal_config.yml captured" "[ -s '$ARTIFACTS/portal_config.yml' ]"
  check "pg_dump non-empty" "[ -s '$ARTIFACTS/tethys_platform.dump' ]"
  check "media manifest non-empty" "[ -s '$ARTIFACTS/media.manifest' ]"
  check "superuser is not named admin" \
    "! in_instance \"python -c \\\"
import django,os;os.environ.setdefault('DJANGO_SETTINGS_MODULE','tethys_portal.settings');django.setup()
from django.contrib.auth.models import User
import sys;sys.exit(0 if User.objects.filter(username='admin',is_superuser=True).exists() else 1)\\\"\""
  check "second non-privileged user exists" \
    "in_instance \"python -c \\\"
import django,os;os.environ.setdefault('DJANGO_SETTINGS_MODULE','tethys_portal.settings');django.setup()
from django.contrib.auth.models import User
import sys;sys.exit(0 if User.objects.filter(username='$FIXTURE_USER_NAME').exists() else 1)\\\"\""
  check "tethysdash primary_db store is linked" \
    "in_instance \"python -c \\\"
import django,os;os.environ.setdefault('DJANGO_SETTINGS_MODULE','tethys_portal.settings');django.setup()
from tethys_apps.models import TethysApp
app=TethysApp.objects.get(package='tethysdash')
s=[x for x in app.settings if x.name=='primary_db']
import sys;sys.exit(0 if s and getattr(s[0],'persistent_store_service',None) else 1)\\\"\""
  check "site settings carry non-default values" "grep -q 'FIRO Fixture' '$ARTIFACTS/site_settings.tsv'"
  check "dump restores into a scratch database" "
    docker exec -e PGPASSWORD=pass '$PG_NAME' psql -U postgres -d postgres -c 'DROP DATABASE IF EXISTS fixture_restore_check;' &&
    docker exec -e PGPASSWORD=pass '$PG_NAME' createdb -U postgres fixture_restore_check &&
    docker exec -i -e PGPASSWORD=pass '$PG_NAME' pg_restore -U postgres -d fixture_restore_check < '$ARTIFACTS/tethys_platform.dump'"

  echo
  [ "$fail" -eq 0 ] && ok "fixture is production-shaped" || die "fixture verification failed"
}

wipe_fakeroot_tree() {
  local target="$1"
  [ -d "$target" ] || return 0
  if rm -rf "${target:?}" 2>/dev/null && [ ! -d "$target" ]; then
    return 0
  fi
  apptainer exec --fakeroot -B "$target:/wipe" "$SIF" \
    bash -c 'rm -rf /wipe/* /wipe/.[!.]* 2>/dev/null; true'
  rmdir "$target" 2>/dev/null || true
}

phase_reset() {
  log "Resetting fixture state (keeps the SIF and containers)"
  apptainer instance stop "$INSTANCE" >/dev/null 2>&1 || true
  wipe_fakeroot_tree "$PERSIST"
  mkdir -p "$PERSIST"
  docker exec -e PGPASSWORD=pass "$PG_NAME" psql -U postgres -d postgres -q \
    -c "DROP DATABASE IF EXISTS tethys_platform WITH (FORCE);" >/dev/null 2>&1 || true
  ok "persist wiped and tethys_platform dropped"
}

phase_teardown() {
  log "Tearing down"
  apptainer instance stop "$INSTANCE" >/dev/null 2>&1 || true
  docker rm -f "$PG_NAME" "$REDIS_NAME" >/dev/null 2>&1 || true
  [ -f "$PROXY_DIR/docker-compose.yml" ] && docker compose -f "$PROXY_DIR/docker-compose.yml" down >/dev/null 2>&1 || true
  ok "instance and containers stopped (FIXTURE_ROOT kept at $FIXTURE_ROOT)"
}

phase_clean() {
  phase_teardown
  wipe_fakeroot_tree "$PERSIST"
  rm -rf "${FIXTURE_ROOT:?}"
  ok "removed $FIXTURE_ROOT"
}

PHASES=("$@")
[ ${#PHASES[@]} -eq 0 ] && PHASES=(services env start proxy seed capture verify)
for p in "${PHASES[@]}"; do
  case "$p" in
    services|env|start|proxy|seed|capture|verify|reset|teardown|clean) "phase_$p" ;;
    -h|--help) usage ;;
    *) echo "unknown phase: $p"; usage ;;
  esac
done

log "Done: ${PHASES[*]}"
[ -d "$ARTIFACTS" ] && echo "Artifacts: $ARTIFACTS"
