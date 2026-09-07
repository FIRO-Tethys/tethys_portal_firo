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

**1. Get the image** — build it, or pull one CI already built.

```bash
apptainer build --fakeroot --fix-perms firo-portal.sif firo_portal.def
```

Apptainer stages the build in `APPTAINER_TMPDIR`, which defaults to `/tmp`. This
image needs roughly 15G of scratch, so set it to a filesystem with room or the
build fails at the squashfs step after everything else has succeeded.

Pulling avoids that entirely. CI publishes to GHCR: pushing a tag runs
`apptainer_tag_publish.yml`, and pushing a `.def` change to `main` runs
`apptainer_dev_publish.yml`.

```bash
echo "$GITHUB_TOKEN" | apptainer registry login -u <user> --password-stdin oras://ghcr.io
apptainer pull firo-portal.sif \
  oras://ghcr.io/firo-tethys/tethys-portal-firo-apptainer:<tag>-x86
apptainer verify firo-portal.sif
```

Tagged builds are signed before they are pushed, so `apptainer verify` can confirm
the image is the artifact CI produced rather than something substituted in transit
— worth running, since a pulled image is the one case where you did not build what
you are about to run. `verify` needs the corresponding public key: the workflow does
not publish it to a keyserver, so import it once with `apptainer key import`, or
treat a "no public key" result as unverified rather than as a failure.
Untagged builds from `main` are not signed and are tagged `<sha7>-x86-x86` (the
suffix is applied twice), so prefer a tagged release for anything but testing.

A pulled image does not have to be built by the account that runs it. Apptainer
runs the container as whoever invokes it and ignores any user baked into the image,
and the definition ends with `chmod -R a+rX` over everything the portal needs, so
the image *contents* are readable whatever uid you run as. CI builds as root and a
local `--fakeroot` build does not; neither changes that.

One thing to check before committing to a role account: `/home/tethys` is mode
`0700` owned by uid 1000 in the base image, and it is the parent of all three bind
targets. A `0700` parent blocks path traversal for any other uid, so a role account
that is not uid 1000 may not be able to reach its own bind mounts. Confirm it under
the real account before cutover rather than assuming:

```bash
apptainer exec -B <run>/persist:/home/tethys/persist firo-portal.sif \
  ls /home/tethys/persist
```

**2. Create the bind directories**

```bash
mkdir -p <run>/portal/keys <run>/persist/{static,media,workspaces/tethysdash} <run>/log
```

Three binds: `<run>/portal` is `TETHYS_HOME` (the rendered config), `<run>/persist`
is `TETHYS_PERSIST` (static, media, workspaces), `<run>/log` is the portal log.

If you are replacing an existing deployment, this is the only step that carries
anything over. **Move the existing media directory in as `<run>/persist/media`**
and it is reused as it is - media is the one thing here that cannot be
regenerated. Everything else takes care of itself: the databases are reused
untouched and nothing migrates them, static is rebuilt by step 3, and the portal
config is authored once in `conf/portal_config.yml` and baked into the image.

**3. Write `portal.env` and make sure the database is reachable**

Every command below passes `--env-file portal.env`. Create it first — nothing in
the image or the repo generates it:

```bash
TETHYS_SECRET_KEY=<50+ random characters, keep it stable across restarts>
TETHYS_DB_ENGINE=django.db.backends.postgresql
TETHYS_DB_HOST=127.0.0.1
TETHYS_DB_PORT=5432
TETHYS_DB_NAME=tethys_platform
TETHYS_DB_USERNAME=tethys_default
TETHYS_DB_PASSWORD=<the database password>
TETHYS_PORT=8000
PREFIX_URL=/firo_apps
PORTAL_ALLOWED_HOSTS=portal.example.org
CREATE_SUPERUSER=false
ASGI_PROCESSES=4
```

Keep this file outside any directory you might delete, and readable only by the
account that runs the portal — it holds the secret key and the database password.
Changing `TETHYS_SECRET_KEY` later invalidates every existing session.

Postgres (with PostGIS) and Redis must already be running and reachable before the
next step; see *Services the portal depends on*. Step 4 has no readiness wait, so
`tethys db migrate` fails outright if the database is not up.

**4. Provision** (once per release; the portal need not be running)

```bash
apptainer exec -B <run>/portal:/home/tethys/portal -B <run>/persist:/home/tethys/persist \
  --env-file portal.env --env CREATE_SUPERUSER=false firo-portal.sif \
  bash -c 'portal-config.sh && tethys db migrate'

apptainer exec --writable-tmpfs -B <run>/portal:/home/tethys/portal \
  -B <run>/persist:/home/tethys/persist --env-file portal.env firo-portal.sif \
  bash -c 'publish-static.sh && tethys db sync && tethys syncstores tethysdash'
```

`--writable-tmpfs` is required for the static step only: it writes into the
package directory, which a SIF makes read-only. `CREATE_SUPERUSER=false` in `portal.env` keeps the
image's own `provision.sh` from adding an `admin` account to an existing portal; the
two commands above never call that script, so the setting matters at `instance
start`, not here.

**5. Serve**

```bash
apptainer instance start -B <run>/portal:/home/tethys/portal \
  -B <run>/persist:/home/tethys/persist -B <run>/log:/home/tethys/log \
  --env-file portal.env --env SERVER=gunicorn \
  --env GUNICORN_CMD_ARGS="--control-socket /home/tethys/portal/gunicorn.ctl" \
  firo-portal.sif firo_portal
```

`GUNICORN_CMD_ARGS` pins gunicorn's control socket to a known path. Without it the
socket lands under `$XDG_RUNTIME_DIR` or `$HOME`, which is per user rather than per
instance, and every `gunicornc` command in *Applying a config change without
downtime* is written against the pinned path.

`SERVER=gunicorn` is required. Plain uvicorn cannot start this portal: Tethys
queries the database in `AppConfig.ready()`, which raises `SynchronousOnlyOperation`
in an async worker.

No `--fakeroot` and no `--writable-tmpfs`. The container runs as the invoking
user, so a role account can own and run it with no image change.

**6. Serve static and media from the web server**

The portal does not serve them. Point the web server at the directories from
step 2 and exclude them from the proxy pass, or every asset is forwarded to the
application and 404s.

### Services the portal depends on

The portal needs a **PostgreSQL database with PostGIS**, and **Redis**. In a
migration both already exist and are reused as they are - the swap replaces the
container, not the data.

Redis is not optional: `CHANNEL_LAYERS` uses `channels_redis.core.RedisChannelLayer`,
which is what carries websocket messages between workers. With `ASGI_PROCESSES`
greater than 1 an in-memory layer cannot work, because a message published by the
worker handling a request would never reach a socket held by another worker. If
Redis is unreachable the HTTP portal still serves normally and only websockets
fail, so check it explicitly rather than inferring it from the pages loading.

For a throwaway local stack:

```bash
docker run --name=firo_postgis --env=POSTGRES_PASSWORD=pass -p 5432:5432 -d postgis/postgis:17-3.5
docker run --name=firo_redis -p 6379:6379 -d redis:7
```

Set the `TETHYS_DB_*` variables in `portal.env` to wherever Postgres actually runs
— they are environment variables read at startup, not keys in `portal_config.yml`,
and `TETHYS_DB_PASSWORD` is injected over whatever the YAML says. Redis is the other
way round: point `settings.CHANNEL_LAYERS.default.CONFIG.hosts` in
`portal_config.yml` at its host and port.

### File ownership

Files are created by the invoking user with its primary group. The portal writes
them; the web server only reads them. Grant the shared group **only the two trees
the web server actually serves**, and leave the rest owner-only - `<run>/portal`
holds the rendered `portal_config.yml`, which carries the Django secret key and the
database password after startup injects them.

```bash
chgrp -R <group> <run>/persist/static <run>/persist/media
find <run>/persist/static <run>/persist/media -type d -exec chmod 2750 {} +

chgrp <group> <run> <run>/persist
chmod 710 <run> <run>/persist

chmod 700 <run>/portal <run>/log <run>/persist/workspaces
```

The setgid bit (the `2`) makes files written by later `collectstatic` runs inherit
the group instead of the writer's primary group - without it the next deploy
silently returns 403s on exactly the assets that changed. Directories are `750`
rather than `740` because the group needs `x` to traverse, and `<run>` and
`<run>/persist` are `710` so the web server can reach `static/` and `media/`
without being able to list anything else.

The portal writes with the umask of whatever launched it, and that is inherited
into the container, so set it where the container is started rather than inside
it - `umask 0027` in the launching shell, or `UMask=0027` in the systemd unit if
a role account runs it as a service. At the usual `0022` files land `644`
world-readable, and the group grants nothing the rest of the machine does not
already have. (The dev script exposes the same thing as `PORTAL_GROUP` and
`PORTAL_UMASK`; those variables belong to `apptainer/dev/scripts/run_portal.sh`
and do not exist in a production deployment.)

The umask does **not** govern what `collectstatic` writes. Django sets those
modes explicitly from `FILE_UPLOAD_PERMISSIONS`, which defaults to `0o644`, so
static and media come out world-readable whatever the umask is. To restrict them
to the group, set it in `portal_config.yml` and fix up what already exists:

```yaml
settings:
  FILE_UPLOAD_PERMISSIONS: 0o640
```

```bash
find <run>/persist/static <run>/persist/media -type f -exec chmod 640 {} +
```

The setting only applies to files `collectstatic` actually rewrites, so without
that one-time `chmod` the unchanged majority keeps its old mode.

To exercise all of this before production, note that the dev Apache container
serves as `www-data` (uid 33), not root - so it enforces the same permission
rules a real server does. Add the host group's gid to the proxy service
(`group_add: ["<gid>"]` in `apptainer/dev/docker-compose.yml`) and the local
stack reproduces this setup end to end; without it, tightening to `2750`
correctly produces 403s. That rehearsal uses the dev script, so there
`PORTAL_GROUP=<group> PORTAL_UMASK=0027 run_portal.sh dirs` applies everything
above in one step.

## Portal configuration

Settings live in `conf/portal_config.yml`, which is baked to `/config/portal_config.yml`
in the image. Three ways to change one, in increasing order of permanence:

**While the container runs** - takes effect on the next reload (see *Applying a config
change without downtime* below). Note this writes into the live copy, which is
overwritten from `PORTAL_CONFIG_SRC` on every restart, so the change is not durable:

```bash
apptainer exec instance://firo_portal tethys settings \
  --set TETHYS_PORTAL_CONFIG.STATIC_ROOT /srv/firo/static
```

**Without rebuilding** - bind a config file from the host and point the portal at
it, so the source of truth is a file you can edit instead of the baked one. Add
these two arguments to the `instance start` in step 4 of *Deploying*, keeping the
binds and `--env-file` it already has:

```bash
-B /srv/firo/config:/hostconfig:ro
--env PORTAL_CONFIG_SRC=/hostconfig/portal_config.yml
```

A later edit to that file is **not** picked up by `gunicornc reload`. The reload
re-reads the *rendered* config in `TETHYS_HOME`; nothing re-copies the source over
it, because `portal-config.sh` runs only at startup. Editing the source alone and
reloading leaves the portal on the old settings with no error.

To apply a change with no downtime, edit **both** files and reload - the rendered
one for immediate effect, the source so it survives the next restart:

```bash
vi /srv/firo/config/portal_config.yml          # the source, for durability
vi <run>/portal/portal_config.yml              # the rendered copy, for effect now
apptainer exec instance://firo_portal /opt/conda/envs/tethys/bin/gunicornc \
  -s /home/tethys/portal/gunicorn.ctl -c "reload"
```

Editing the rendered file directly is safe: it keeps the `SECRET_KEY` and database
password that startup injected, which is exactly what running `portal-config.sh`
by hand would destroy.

Editing only the source is fine too, if you would rather take the restart:

```bash
apptainer instance stop firo_portal
apptainer instance start ...same arguments as step 4... firo-portal.sif firo_portal
```

`apptainer instance start` is not a restart. Run against a name that is already
running it refuses with `FATAL: instance <name> already exists` and changes
nothing, so the stop is required.

Do not try to shortcut that by running `portal-config.sh` against the live
instance. It copies the source over the rendered config *before* it injects
secrets, and an `apptainer exec` does not inherit the instance's `--env-file`, so it
fails at `TETHYS_SECRET_KEY is required` having already overwritten the working
config - leaving a portal that serves until the next
restart and then cannot start. If that happens, stop and start the instance and
it re-renders correctly.

The host file must be a **complete** `portal_config.yml`, not a fragment of overrides:
`portal-config.sh` copies it over the baked one, so anything absent from it is simply gone.
Start from `conf/portal_config.yml` and edit that copy. A partial file does not fail
loudly - dropping `PREFIX_URL` moves the whole portal from `/firo_apps/` to `/`, so the
proxy returns 404 for every path while the container reports a healthy start, and dropping
`TETHYS_PORTAL_CONFIG` silently loses `STATIC_ROOT` and `MEDIA_ROOT`. Keep `PREFIX_URL`
matching the image: it is compiled into the React bundle at build time and cannot be
changed from config alone. The database block is the one exception that survives omission,
because the DB connection and secrets are injected from the environment afterwards.

**Permanently** - edit `conf/portal_config.yml` and rebuild with
`apptainer/dev/scripts/build_image.sh`.

### Applying a config change without downtime

There is no supervisord in this image. Gunicorn's own control interface replaces it:
`gunicornc` talks to the running master over a unix socket, so a config change is applied
by reloading the workers rather than restarting the container.

A reload re-reads the **rendered** config in `TETHYS_HOME`, so that is the file to edit
for the change to take effect. Startup overwrites that file from `PORTAL_CONFIG_SRC`,
so make the same edit there as well or the change lasts only until the next restart -
step 1b below. If `PORTAL_CONFIG_SRC` is still the baked `/config/portal_config.yml`
inside the image there is nothing to edit for durability: bind a host file first (see
*Portal configuration* above), or treat the change as temporary until the next rebuild.

```bash
# 1a. edit the rendered config, which is what a reload re-reads
vi <run>/portal/portal_config.yml

# 1b. make the same edit in PORTAL_CONFIG_SRC, or the next restart reverts it
vi /srv/firo/config/portal_config.yml

# 2. check BOTH files parse before signalling anything - a typo in the source
#    would not surface until the next restart, when it is copied in wholesale
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

**Step 5 is required, and step 3 is what makes it meaningful.** `gunicornc -c "reload"` returns
`{"status": "reloading"}` immediately; it does not wait and does not report whether the new
workers came up. Gunicorn also keeps the old worker serving until the new one is ready, so
an HTTP check on its own reads the *old* worker and returns 200 for a portal that is about
to be down. Record the worker PIDs **before** reloading, confirm every one of them has been
replaced, and only then check HTTP.

In the dev stack `apptainer/dev/scripts/run_portal.sh reload` performs exactly this
sequence - validate, record PIDs, reload, wait for full replacement, then verify HTTP - and
fails loudly if the workers are never replaced or the portal stops answering. The manual
steps above are the same procedure for a host that does not have that script.

Note that a worker's `BOOTED` column reads `no` on a healthy, serving worker, so it is not
a health signal. Use the HTTP check.

If the reload leaves the portal down, restore the config and restart the instance -
a failed reload has no automatic rollback, and the master may be gone:

```bash
apptainer instance stop firo_portal
apptainer instance start ... firo-portal.sif firo_portal
```

Other `gunicornc` commands: `show workers`, `show stats`, `show config`, `show listeners`,
`worker add N`, `worker remove N`, `reopen` (reopen log files), `shutdown graceful`.
Add `-j` for JSON.

**What a reload cannot do.** `DEBUG` is read by `serve.sh` before it execs, to choose
between `runserver` and gunicorn, so changing it needs a full restart - under `runserver`
there is no gunicorn master to reload at all. The same applies to anything in the env file
(`SERVER`, ports) and to any change in bind mounts.

**One caveat beyond the two files above.** The control socket must be pinned per
instance. Gunicorn's default is `$XDG_RUNTIME_DIR/gunicorn.ctl` when that variable is set
and is a directory, otherwise `$HOME/.gunicorn/gunicorn.ctl` - either way it is **per user,
not per instance**, so a second portal started by the same account overwrites the first
one's socket and deletes it on exit, leaving the first portal serving but permanently
unable to reload. Pass `GUNICORN_CMD_ARGS="--control-socket /home/tethys/portal/gunicorn.ctl"` at
start and `gunicornc -s` that same path; `run_portal.sh` does this for you.

Static and media paths (`STATIC_ROOT`, `MEDIA_ROOT`, `TETHYS_WORKSPACES_ROOT`) are set
under `settings.TETHYS_PORTAL_CONFIG`. Serve those directories from the web server;
the portal does not serve them itself.
