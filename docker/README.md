# Docker Compose Build and Run

## Build

```
docker build -t tethys-portal-docker-firo .
gcloud auth print-access-token | docker login -u oauth2accesstoken --password-stdin https://us-central1-docker.pkg.dev
docker tag tethys-portal-docker-firo ghcr.io/firo-tethys/tethys_portal_firo:main
docker push ghcr.io/firo-tethys/tethys_portal_firo:main
```

## Run

1. Create Data Directories

```
cd docker
mkdir -p data/db
mkdir -p data/tethys
```

1. Create copies of the `.env` files in the `env` directory and modify the settings appropriately.

2. Update `env_file` sections in the `docker-compose.yml` to point to your copies of the `.env` files.

3. Start supporting containers:

```
docker compose up -d db redis
```

4. Start the web container:

```
docker compose up -d web
```

5. Check web container status:

```
docker compose logs -f web
```
