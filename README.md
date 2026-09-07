# FIRO TETHYS PORTAL

The FIRO Tethys portal was developed using the [Tethys Platform](https://www.tethysplatform.org/), and it contains the TethysDash application.

## Checkout

```
git clone --recursive-submodules https://github.com/FIRO-Tethys/tethys_portal_firo.git
```

The FIROH portal can be run using `docker` or `apptainer`

## Docker

### Build

```bash
docker compose build web
```

### Run

1. Create Data Directories

```bash
mkdir -p data/db
mkdir -p data/tethys
mkdir -p logs/tethys
```

2. Create copies of the `.env` files in the `env` directory and modify the settings appropriately.

3. Update `env_file` sections in the `docker-compose.yml` to point to your copies of the `.env` files.

4. Start containers:

```bash
docker compose up -d
```

## Deploying (production)

The scripts under `apptainer/` are development tooling. Production is six steps.

**1. Get the image.** Build it, or pull one CI already built.

```bash
apptainer build --fakeroot --fix-perms firo-portal.sif firo_portal.def
```

Apptainer stages the build in `APPTAINER_TMPDIR`, which defaults to `/tmp`. The
build needs roughly 15G of scratch, so point it at a filesystem with room or it
fails at the squashfs step after everything else has succeeded.

Pulling avoids that. Pushing a tag runs `apptainer_tag_publish.yml`; pushing a
`.def` change to `main` runs `apptainer_dev_publish.yml`.

```bash
echo "$GITHUB_TOKEN" | apptainer registry login -u <user> --password-stdin oras://ghcr.io
apptainer pull firo-portal.sif \
  oras://ghcr.io/firo-tethys/tethys-portal-firo-apptainer:<tag>-x86
apptainer verify firo-portal.sif
```

Tagged builds are signed before they are pushed, so `apptainer verify` confirms the
image is what CI produced. It needs the matching public key, which the workflow does
not publish to a keyserver; import it with `apptainer key import`, or read "no public
key" as unverified rather than as a failure. Untagged builds from `main` are unsigned
and tagged `<sha7>-x86-x86`, so prefer a tagged release outside of testing.

Apptainer runs the container as whoever invokes it and ignores the image's `USER`, so
a role account at any uid can run a CI-built image. Two things make that work: the
definition ends with `chmod -R a+rX` over everything the portal reads, and it sets
`chmod 0755 /home/tethys`, without which the base image's `0700` home would block
every uid except 1000 from reaching its own bind mounts.

**2. Create the bind directories.**

```bash
mkdir -p <run>/portal/keys <run>/persist/{static,media,workspaces/tethysdash} <run>/log
```

`<run>/portal` is `TETHYS_HOME` (the rendered config), `<run>/persist` is
`TETHYS_PERSIST` (static, media, workspaces), `<run>/log` is the portal log.
`persist/` can live on another filesystem; bind it wherever it actually is.

Replacing an existing deployment? This is the only step that carries anything over.
**Move the existing media directory in as `<run>/persist/media`.** Media is the one
thing here that cannot be regenerated. The databases are reused untouched, static is
rebuilt by step 4, and the portal config is baked into the image.

**3. Write `portal.env`, and check the database is reachable.**

Every command below passes `--env-file portal.env`. Copy the template and fill in
`TETHYS_SECRET_KEY` (50+ random characters) and `TETHYS_DB_PASSWORD`:

```bash
cp portal.env.example portal.env
```

Keep it outside any directory you might delete, readable only by the account that
runs the portal. It holds the secret key and the database password, and changing
`TETHYS_SECRET_KEY` later invalidates every session.

Postgres and Redis must already be running (see *Services the portal depends on*).
Step 4 has no readiness wait, so `tethys db migrate` fails outright if the database
is down.

**4. Provision.** Once per release; the portal need not be running.

```bash
apptainer exec -B <run>/portal:/home/tethys/portal -B <run>/persist:/home/tethys/persist \
  --env-file portal.env firo-portal.sif \
  bash -c 'portal-config.sh && tethys db migrate'

apptainer exec --writable-tmpfs -B <run>/portal:/home/tethys/portal \
  -B <run>/persist:/home/tethys/persist \
  --env-file portal.env firo-portal.sif \
  bash -c 'publish-static.sh && tethys db sync && tethys syncstores tethysdash'
```

`--writable-tmpfs` is needed for the static step only, which writes into the package
directory that a SIF makes read-only. `CREATE_SUPERUSER=false` in `portal.env` stops
the image's `provision.sh` adding an `admin` account to an existing portal; it takes
effect at `instance start`, not here.

**5. Serve.**

```bash
apptainer instance start -B <run>/portal:/home/tethys/portal \
  -B <run>/persist:/home/tethys/persist -B <run>/log:/home/tethys/log \
  --env-file portal.env --env SERVER=gunicorn \
  --env GUNICORN_CMD_ARGS="--control-socket /home/tethys/portal/gunicorn.ctl" \
  firo-portal.sif firo_portal
```

`SERVER=gunicorn` is required. Plain uvicorn cannot start this portal: Tethys queries
the database in `AppConfig.ready()`, which raises `SynchronousOnlyOperation` in an
async worker.

`GUNICORN_CMD_ARGS` pins the control socket to a known path. Left to itself gunicorn
puts it under `$XDG_RUNTIME_DIR` or `$HOME`, which is per user rather than per
instance, so a second portal started by the same account overwrites the first one's
socket and deletes it on exit, leaving that portal serving but unable to reload. Every
`gunicornc` command below assumes the pinned path.

No `--fakeroot` and no `--writable-tmpfs`.

**6. Serve static and media from the web server.** The portal does not serve them.
Point the web server at `<run>/persist/static` and `<run>/persist/media`, and exclude
those paths from the proxy pass, or every asset is forwarded to the application and
404s.

### Services the portal depends on

The portal needs **PostgreSQL with PostGIS** and **Redis**. In a migration both
already exist and are reused as they are; the swap replaces the container, not the
data.

Redis is not optional. `CHANNEL_LAYERS` uses `channels_redis.core.RedisChannelLayer`,
which carries websocket messages between workers; with `ASGI_PROCESSES` above 1 an
in-memory layer cannot work, because a message published by one worker never reaches
a socket held by another. If Redis is unreachable the HTTP portal still serves
normally and only websockets fail, so check it explicitly rather than inferring it
from the pages loading.

Set the `TETHYS_DB_*` variables in `portal.env` to wherever Postgres runs. They are
environment variables read at startup, not keys in `portal_config.yml`, and
`TETHYS_DB_PASSWORD` is injected over whatever the YAML says. Redis is the other way
round: point `settings.CHANNEL_LAYERS.default.CONFIG.hosts` in `portal_config.yml` at
its host and port.

### File ownership

The portal writes the files; the web server only reads them. Grant the shared group
only the two trees the web server serves, and leave the rest owner-only.
`<run>/portal` holds the rendered `portal_config.yml`, which carries the secret key
and database password once startup injects them.

```bash
chgrp -R <group> <run>/persist/static <run>/persist/media
find <run>/persist/static <run>/persist/media -type d -exec chmod 2750 {} +

chgrp <group> <run> <run>/persist
chmod 710 <run> <run>/persist

chmod 700 <run>/portal <run>/log <run>/persist/workspaces
```

The setgid bit (the `2`) makes files written by later `collectstatic` runs inherit the
group instead of the writer's primary group. Without it the next deploy returns 403s
on exactly the assets that changed. Directories are `750` rather than `740` because
the group needs `x` to traverse, and `<run>` and `<run>/persist` are `710` so the web
server can reach the two served trees without listing anything else.

The portal writes with the umask of whatever launched it, inherited into the
container, so set it where the container starts: `umask 0027` in the launching shell,
or `UMask=0027` in the systemd unit. At the usual `0022` files land `644`
world-readable and the group grants nothing. (The dev script exposes the same thing as
`PORTAL_GROUP` and `PORTAL_UMASK`; those belong to `run_portal.sh` and do not exist in
production.)

The umask does not govern what `collectstatic` writes. Django sets those modes from
`FILE_UPLOAD_PERMISSIONS`, default `0o644`, so static and media come out
world-readable whatever the umask. To restrict them, set it in `portal_config.yml` and
fix up what already exists:

```yaml
settings:
  FILE_UPLOAD_PERMISSIONS: 0o640
```

```bash
find <run>/persist/static <run>/persist/media -type f -exec chmod 640 {} +
```

The setting applies only to files `collectstatic` rewrites, so without that one-time
`chmod` the unchanged majority keeps its old mode.

## Portal configuration

Settings live in `conf/portal_config.yml`, baked to `/config/portal_config.yml` in the
image. `portal-config.sh` copies that source over `$TETHYS_HOME/portal_config.yml` at
every start, then injects the secret key and database connection from the environment.
Three ways to change a setting, in increasing order of permanence.

**While the container runs.** Writes into the rendered copy, which the next start
overwrites, so it is not durable:

```bash
apptainer exec instance://firo_portal tethys settings \
  --set TETHYS_PORTAL_CONFIG.STATIC_ROOT /srv/firo/static
```

**Without rebuilding.** Bind a config file from the host so the source of truth is a
file you can edit. Add these to the `instance start` in step 5, keeping its existing
binds and `--env-file`:

```bash
-B /srv/firo/config:/hostconfig:ro
--env PORTAL_CONFIG_SRC=/hostconfig/portal_config.yml
```

The host file must be a **complete** `portal_config.yml`, not a fragment. Anything
absent from it is simply gone. Start from `conf/portal_config.yml` and edit that copy.
A partial file does not fail loudly: dropping `PREFIX_URL` moves the portal from
`/firo_apps/` to `/`, so the proxy 404s every path while the container reports a
healthy start, and dropping `TETHYS_PORTAL_CONFIG` silently loses `STATIC_ROOT` and
`MEDIA_ROOT`. Keep `PREFIX_URL` matching the image; it is compiled into the React
bundle at build time and cannot be changed from config alone. The database block is
the one exception that survives omission, because the connection and secrets are
injected from the environment afterwards.

Applying a later edit to that file needs a real restart, since the config is rendered
once at startup:

```bash
apptainer instance stop firo_portal
apptainer instance start ...same arguments as step 5... firo-portal.sif firo_portal
```

`apptainer instance start` is not a restart. Against a name that is already running it
refuses with `FATAL: instance <name> already exists` and changes nothing.

Do not shortcut that by running `portal-config.sh` against the live instance. It
copies the source over the rendered config *before* injecting secrets, and an
`apptainer exec` does not inherit the instance's `--env-file`, so it fails at
`TETHYS_SECRET_KEY is required` having already overwritten the working config. The
portal serves until the next restart and then cannot start. Stop and start the
instance to recover.

**Permanently.** Edit `conf/portal_config.yml` and rebuild.

### Applying a config change without downtime

There is no supervisord in this image. Gunicorn's control interface replaces it:
`gunicornc` talks to the running master over a unix socket, so a change is applied by
reloading the workers rather than restarting the container.

A reload re-reads the **rendered** config, so that is the file to edit for the change
to take effect. Startup overwrites it from `PORTAL_CONFIG_SRC`, so make the same edit
there or the change lasts only until the next restart. If `PORTAL_CONFIG_SRC` is still
the baked path inside the image there is nothing to edit for durability; bind a host
file first, or treat the change as temporary until the next rebuild.

```bash
# 1a. the rendered config, which is what a reload re-reads
vi <run>/portal/portal_config.yml

# 1b. the same edit in PORTAL_CONFIG_SRC, or the next restart reverts it
vi /srv/firo/config/portal_config.yml

# 2. check both parse. A typo in the source would not surface until the next
#    restart, when it is copied in wholesale
apptainer exec instance://firo_portal /opt/conda/envs/tethys/bin/python \
  -c 'import yaml; yaml.safe_load(open("/home/tethys/portal/portal_config.yml"))'
python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' \
  /srv/firo/config/portal_config.yml

# 3. record the current worker PIDs
apptainer exec instance://firo_portal /opt/conda/envs/tethys/bin/gunicornc \
  -s /home/tethys/portal/gunicorn.ctl -c "show workers"

# 4. reload
apptainer exec instance://firo_portal /opt/conda/envs/tethys/bin/gunicornc \
  -s /home/tethys/portal/gunicorn.ctl -c "reload"

# 5. wait until no PID from step 3 remains, then verify HTTP
apptainer exec instance://firo_portal /opt/conda/envs/tethys/bin/gunicornc \
  -s /home/tethys/portal/gunicorn.ctl -c "show workers"
curl -so /dev/null -w '%{http_code}\n' http://localhost/firo_apps/
```

**Step 5 is required, and step 3 is what makes it meaningful.** `reload` returns
`{"status": "reloading"}` immediately; it does not wait, and does not report whether
the new workers came up. Gunicorn also keeps the old worker serving until the new one
is ready, so an HTTP check on its own reads the old worker and returns 200 for a portal
about to go down. Confirm every PID from step 3 is gone before trusting it. A worker's
`BOOTED` column reads `no` on a healthy serving worker, so it is not a health signal.

If a reload leaves the portal down, restore the config and restart. A failed reload has
no automatic rollback and the master may be gone:

```bash
apptainer instance stop firo_portal
apptainer instance start ... firo-portal.sif firo_portal
```

Other `gunicornc` commands: `show workers`, `show stats`, `show config`,
`show listeners`, `worker add N`, `worker remove N`, `reopen`, `shutdown graceful`.
Add `-j` for JSON.

`DEBUG` cannot be reloaded. `serve.sh` reads it before exec to choose between
`runserver` and gunicorn, so changing it needs a full restart, and under `runserver`
there is no gunicorn master to reload at all. The same applies to anything in the env
file and to any change in bind mounts.

Static and media paths (`STATIC_ROOT`, `MEDIA_ROOT`, `TETHYS_WORKSPACES_ROOT`) are set
under `settings.TETHYS_PORTAL_CONFIG`. Serve those directories from the web server.
