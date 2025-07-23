#!/usr/bin/env bash
set -euo pipefail

tail_file() {
  echo "tailing file $1"
  ALIGN=27
  LENGTH=`echo $1 | wc -c`
  PADDING=`expr ${ALIGN} - ${LENGTH}`
  PREFIX=$1`perl -e "print ' ' x $PADDING;"`
  file="/var/log/$1"
  # each tail runs in the background but prints to stdout
  # sed outputs each line from tail prepended with the filename+padding
  tail -qF $file | sed --unbuffered "s|^|${PREFIX}:|g" &
}


check_db_and_roles() {
  local db="$TETHYS_DB_NAME"
  local role="$TETHYS_DB_USERNAME"
  local super="${TETHYS_DB_SUPERUSER:-postgres}"

  # just the executable + options
  local -a PSQL=(
      "${CONDA_HOME}/envs/${CONDA_ENV_NAME}/bin/psql"
      -d postgres
      -U postgres
      -h "$TETHYS_DB_HOST"
      -p "$TETHYS_DB_PORT"
      -tA -c
  )

  # prepend the temporary environment assignment **when you call it**
  db_exists=$( PGPASSWORD="$POSTGRES_PASSWORD" \
              "${PSQL[@]}" "SELECT 1 FROM pg_database WHERE datname = '$db';" ) || true

  role_exists=$( PGPASSWORD="$POSTGRES_PASSWORD" \
              "${PSQL[@]}" "SELECT 1 FROM pg_roles    WHERE rolname = '$role';" ) || true

  super_exists=$( PGPASSWORD="$POSTGRES_PASSWORD" \
              "${PSQL[@]}" "SELECT 1 FROM pg_roles    WHERE rolname = '$super';" ) || true

  [[ -n $db_exists && -n $role_exists && -n $super_exists ]]
}

echo_status() {
  local args="${@}"
  tput setaf 4
  tput bold
  echo -e "- $args"
  tput sgr0
}

db_max_count=24;
no_daemon=true;
skip_perm=false;
test=false;
db_engine=${TETHYS_DB_ENGINE} # Get the DB engine from environment variable
skip_db_setup=${SKIP_DB_SETUP} # Get the DB setup flag from environment variable
USAGE="USAGE: . run.sh [options]
OPTIONS:
--background              \t run supervisord in background.
--skip-perm               \t skip fixing permissions step.
--db-max-count <INT>      \t number of attempt to connect to the database. Default is at 24.
--test                    \t only run test.
"

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-perm)
      skip_perm=true;
    ;;
    --background)
      no_daemon=false;
    ;;
    --db-max-count)
      shift # shift from key to value
      db_max_count=$1;
    ;;
    --test)
      test=true;
    ;;
    *)
      echo -e "${USAGE}"
      return 0
  esac
  shift
done

echo_status "Starting up..."

# ───────────────────────── DB readiness / setup ────────────
if [[ $test == false ]]; then
  export NGINX_USER=$(grep 'user .*;' /etc/nginx/nginx.conf \
                      | awk '{print $2}' | awk -F';' '{print $1}')

    if [[ $db_engine == "django.db.backends.postgresql" ]]; then
        db_check_count=0

        until ${CONDA_HOME}/envs/${CONDA_ENV_NAME}/bin/pg_isready -h ${TETHYS_DB_HOST} -p ${TETHYS_DB_PORT} -U postgres; do
          if [[ $db_check_count -gt $db_max_count ]]; then
            >&2 echo "DB was not available in time - exiting"
            exit 1
          fi
          >&2 echo "DB is unavailable - sleeping"
          db_check_count=`expr $db_check_count + 1`
          sleep 5
        done
    else
      echo_status "Using SQLite3 as the database"
    fi 

fi

if check_db_and_roles ; then
    echo_status "DB '$TETHYS_DB_NAME' and roles already exist – skipping Salt DB setup."
else
    echo_status "DB '$TETHYS_DB_NAME' and roles do not exist – running"
    echo "postgres.host: '${TETHYS_DB_HOST}'" >> /etc/salt/minion
    echo "postgres.port: '${TETHYS_DB_PORT}'" >> /etc/salt/minion
    echo "postgres.user: '${TETHYS_DB_USERNAME}'" >> /etc/salt/minion
    echo "postgres.pass: '${TETHYS_DB_PASSWORD}'" >> /etc/salt/minion
    echo "postgres.bins_dir: '${CONDA_HOME}/envs/${CONDA_ENV_NAME}/bin'" >> /etc/salt/minion
fi


echo_status "Enforcing start state... (This might take a bit)"
salt-call --local state.apply

if [[ $test = false ]]; then
  if [[ $skip_perm = false ]]; then
    echo_status "Fixing permissions"
    find ${STATIC_ROOT} ! -user ${NGINX_USER} -print0 | xargs -0 -I{} chown ${NGINX_USER}: {}
    find ${WORKSPACE_ROOT} ! -user ${NGINX_USER} -print0 | xargs -0 -I{} chown ${NGINX_USER}: {}
    find ${MEDIA_ROOT} ! -user ${NGINX_USER} -print0 | xargs -0 -I{} chown ${NGINX_USER}: {}
    find ${TETHYS_PERSIST} ! -user ${NGINX_USER} -print0 | xargs -0 -I{} chown ${NGINX_USER}: {}
    find ${TETHYSAPP_DIR} ! -user ${NGINX_USER} -print0 | xargs -0 -I{} chown ${NGINX_USER}: {}
    find ${TETHYS_HOME} ! -user ${NGINX_USER} -print0 | xargs -0 -I{} chown ${NGINX_USER}: {}
  fi

  echo_status "Starting supervisor"

  # Start Supervisor
  /usr/bin/supervisord

  echo_status "Done!"

  # Watch Logs
  echo_status "Watching logs. You can ignore errors from either apache (httpd) or nginx depending on which one you are using."

  ls -la /var/log/nginx
  ls -la /var/log/supervisor
  ls -la /var/log/tethys

  log_files=("nginx/access.log" 
    "nginx/error.log" 
    "supervisor/supervisord.log" 
    "tethys/tethys.log")

  # When this exits, exit all background tail processes
  trap 'kill $(jobs -p)' EXIT
  for log_file in "${log_files[@]}"; do
    tail_file "${log_file}"
  done

  # Read output from tail; wait for kill or stop command (docker waits here)
  wait
fi
