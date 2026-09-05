# FIRO TETHYS PORTAL

The FIRO Tethys portal was developed using the [Tethys Platform](https://www.tethysplatform.org/), and it contains the TethysDash application.

## Checkout

```
git clone --recursive-submodules https://github.com/FIRO-Tethys/tethys_portal_firo.git
```

The FIROH portal can be run using `docker` or `singularity`

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

## Singularity

### Build

Build the sif file from the `firo_portal.def` file 


```bash
singularity build --fakeroot <path_to_where_you_want_to_define_your_sif_file> firo_portal.def
```

e.g.

```bash
singularity build --fakeroot ../firo-portal-singularity_latest.sif firo_portal.def
```

### Extra Containers

The FIRO portal needs to have a PostgreSQL (with postgis extension) database, and a Redis container running, Use the following commands to run them.

```bash
docker run --name=firo_postgis --env=POSTGRES_PASSWORD=pass -p 5437:5432 -d postgis/postgis:12-2.5
```
```bash
docker run --name=firo_redis -p 6379:6379 -d redis:7
```

### Run the FIRO Singularity Container

Run the `Singularity` container with the following command

```bash
singularity instance start --writable-tmpfs <path_to_where_you_want_to_define_your_sif_file> <container_name>
```

e.g
```bash
singularity instance start =--writable-tmpfs ../firo-portal-singularity_latest.sif firo_portal
```

### Customization

if configuration realted to env variables need to be passed you can use the `--env-file` flag. This repo comes with a `dev.env` example to customize.

```bash
singularity instance start --env-file dev.env --writable-tmpfs ../firo-portal-singularity_latest.sif firo_portal
```

**Note** *the variable `SKIP_DB_SETUP` allows the user to skip the db setup. If you have already run the container, and your database has been configured, please set `SKIP_DB_SETUP` to true, so the scripts to configure the db can be skipped.*

Similarly, if the theme needs to be changed at run time, you can do it by mounting a directory containing the theme.

```bash
singularity instance start --env-file dev.env -B <local_path_to_theme_directory>:/usr/lib/tethys/<name_of_theme_directory> --writable-tmpfs ../firo-portal-singularity_latest.sif firo_portal
 
```

This repository comes with an example on the folder `custom_themes/tethysext-default_theme`, and **Note** *the variable `THEME_NAME`, this variable needs to be the name of the theme directory*

```bash
singularity instance start --env-file dev.env -B custom_themes/tethysext-default_theme:/usr/lib/tethys/default_theme --writable-tmpfs ../firo-portal-singularity_latest.sif firo_portal
 
```


### TroubleShooting

If logs related to Tethys need to be seen or persisted. The `salt.log` file can be binded

```bash
singularity instance start --writable-tmpfs -B <path_to_your_salt_log_file>:/var/log/tethys/salt.log <path_to_where_you_want_to_define_your_sif_file> <container_name>
```

For example

```bash
mkdir -p /tmp/logs/tethys
touch /tmp/logs/tethys/salt.log
singularity instance start =--writable-tmpfs -B /tmp/logs/tethys/salt.log:/var/log/tethys/salt.log ../firo-portal-singularity_latest.sif firo_portal
```

On another terminal, you can use `tail` the logs

e.g.

```bash
tail -f -n 100 /tmp/logs/tethys/salt.log
```

## Deploying (production)

The scripts under `apptainer/` are development tooling. Production is four steps.

**1. Build**

```bash
apptainer build --fakeroot --fix-perms firo-portal.sif firo_portal.def
```

Apptainer stages the build in `APPTAINER_TMPDIR`, which defaults to `/tmp`. This
image needs roughly 15G of scratch, so set it to a filesystem with room or the
build fails at the squashfs step after everything else has succeeded.

**2. Provision** (once per release; the portal need not be running)

```bash
apptainer exec -B <run>/portal:/home/tethys/portal -B <run>/persist:/home/tethys/persist \
  --env-file portal.env --env CREATE_SUPERUSER=false firo-portal.sif \
  bash -c 'portal-config.sh && tethys db migrate'

apptainer exec --writable-tmpfs -B <run>/portal:/home/tethys/portal \
  -B <run>/persist:/home/tethys/persist --env-file portal.env firo-portal.sif \
  bash -c 'publish-static.sh && tethys db sync && tethys syncstores tethysdash'
```

`--writable-tmpfs` is required for the static step only: it writes into the
package directory, which a SIF makes read-only. `CREATE_SUPERUSER=false` keeps
provisioning from adding an `admin` account to an existing portal.

**3. Serve**

```bash
apptainer instance start -B <run>/portal:/home/tethys/portal \
  -B <run>/persist:/home/tethys/persist -B <run>/log:/home/tethys/log \
  --env-file portal.env --env SERVER=gunicorn firo-portal.sif firo_portal
```

`SERVER=gunicorn` is required. Plain uvicorn cannot start this portal: Tethys
queries the database in `AppConfig.ready()`, which raises `SynchronousOnlyOperation`
in an async worker.

No `--fakeroot` and no `--writable-tmpfs`. The container runs as the invoking
user, so a role account can own and run it with no image change.

**4. Serve static and media from the web server**

The portal does not serve them. Point the web server at the directories from
step 2 and exclude them from the proxy pass, or every asset is forwarded to the
application and 404s.

### File ownership

Files are created by the invoking user with its primary group. To let the web
server read them via a shared group, set the group on the run root and the
setgid bit on its directories, so files written by later `collectstatic` runs
inherit it:

```bash
chgrp -R <group> <run> && find <run> -type d -exec chmod g+s {} +
```

## Portal configuration

Settings live in `conf/portal_config.yml`, which is baked to `/config/portal_config.yml`
in the image. Three ways to change one, in increasing order of permanence:

**While the container runs** — takes effect on the next restart:

```bash
apptainer exec instance://firo_portal tethys settings \
  --set TETHYS_PORTAL_CONFIG.STATIC_ROOT /srv/firo/static
```

**Without rebuilding** — bind a config file from the host and point the portal at it.
Edit the host file and restart; no image change:

```bash
apptainer instance start -B /srv/firo/config:/hostconfig \
  --env PORTAL_CONFIG_SRC=/hostconfig/portal_config.yml ... firo-portal.sif firo_portal
```

**Permanently** — edit `conf/portal_config.yml` and rebuild with
`apptainer/scripts/build_image.sh`.

Static and media paths (`STATIC_ROOT`, `MEDIA_ROOT`, `TETHYS_WORKSPACES_ROOT`) are set
under `settings.TETHYS_PORTAL_CONFIG`. Serve those directories from the web server;
the portal does not serve them itself.
