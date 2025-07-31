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

This repository comes with an example on the folder `custom_themes/firo_theme`, and **Note** *the variable `THEME_NAME`, this variable needs to be the name of the theme directory*

```bash
singularity instance start --env-file dev.env -B custom_themes/firo_theme:/usr/lib/tethys/firo_theme --writable-tmpfs ../firo-portal-singularity_latest.sif firo_portal
 
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

