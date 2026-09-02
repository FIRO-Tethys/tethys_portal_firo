# The production-shaped fixture

There is no access to the FIRO VM and no channel to its operators. Every step of
the tethys-uvx migration therefore has to be proven against something that stands
in for that deployment. This is that something.

## What it is

`apptainer/fixtures/build_fixture.sh` runs the **current** (salt/conda) portal
image against a local Postgres and Redis, then seeds it. The result is a
database, a persist directory, and a media set that the migration steps operate
on exactly as they would on the VM.

The fixture is built by running the real image rather than by hand-constructing a
database. That is deliberate: the schema, the app and extension registrations,
the `tethys_postgis` persistent-store service, the `primary_db` link, and the
salt marker files all have to be real. Hand-rolling them would encode our
assumptions about production into the thing meant to test those assumptions.

It also proves the current image still builds, which is the rollback baseline.

## What it is not

It reproduces the deployment's **shape**, not its **content**. Absent and
unobtainable:

- the operators' real user accounts
- their real dashboards and thumbnails
- their actual settings values, including the live `portal_config.yml`
- their actual superuser name

The fixture proves the migration *procedure*. It does not author the production
config — `apptainer/scripts/preflight.sh` does that, on their machine, at cutover.

The weakest assumption in the whole plan is that this fixture's shape matches
production's, and nothing here can fully close that. Preflight prints every
difference it finds between the shipped config and the live one, so a mismatch
surfaces to the operator before they commit to the switch.

## Running it

```bash
apptainer/scripts/build_image.sh firo_portal.def ../firo-portal-fixture.sif
apptainer/fixtures/build_fixture.sh
```

Phases run individually so a late failure does not cost the whole build:

```bash
apptainer/fixtures/build_fixture.sh services env   # containers + env file
apptainer/fixtures/build_fixture.sh start          # instance + salt provisioning
apptainer/fixtures/build_fixture.sh seed capture verify
```

`teardown` stops everything and keeps the data; `clean` also deletes
`FIXTURE_ROOT`. Neither uses `sudo` — under this layout every path is owned by
the invoking user, so if a teardown seems to need elevation, the bind ownership
is wrong and that is the thing to fix.

Overridable: `SIF`, `FIXTURE_ROOT`, `INSTANCE`, `PG_NAME`, `REDIS_NAME`, `SEED_ENV`.

## The seeds are deliberately awkward

`apptainer/fixtures/seed.env` sets values chosen to make the fixture wrong in the
ways production might be wrong. Convenient defaults would make the migration pass
without proving anything.

**The superuser must not be named `admin`.** This is the load-bearing one. The
`tethys-uvx` provision verb defaults to creating `admin` / `pass`, and Tethys's
`create_portal_superuser` only skips the creation when the name collides and
raises `IntegrityError`. Seed the fixture as `admin` and the collision is caught,
no account is created, the migration passes — and the hole stays invisible until
production, where the superuser may well be named something else. The fixture is
seeded `firoadmin`, and both the script and its verify phase refuse to proceed if
that ever becomes `admin`.

Note that an unmodified `dev.env` produces exactly the hidden case: it sets no
`PORTAL_SUPERUSER_*` at all, so salt calls `tethys db createsuperuser` bare and
Tethys's own defaults create `admin`. The fixture env adds those variables.

**Media must include real tethysdash output.** The script writes fixed-content
filler files so checksums are stable across rebuilds, but filler alone does not
prove the end-to-end thumbnail check. After `start`, log in as the seeded
superuser and create one dashboard so a genuine thumbnail is written under
`MEDIA_ROOT`, then re-run `capture`.

**Branding must be non-default.** `site_settings` rows with known non-default
values are what make the "`tethys site -f` leaves undeclared settings alone"
check meaningful. Against default values the check passes vacuously.

## Artifacts

`capture` writes to `$FIXTURE_ROOT/artifacts/`:

| File | Consumed by |
|---|---|
| `portal_config.yml` | U4 — the settings the salt states actually produced |
| `tethys_platform.dump` | U5 — provisioning is run twice against a restore of this |
| `media.manifest` | U10 — backup and restore verify against it |
| `site_settings.tsv` | U5 — the before side of the branding check |
| `versions.txt` | U8 — recorded in the migration document |
| `migrations.txt` | U8 — the before side of the migration record |

## Verification

`verify` asserts the fixture is production-shaped *and* correctly awkward:
marker files present, artifacts non-empty, the superuser is not `admin`, the
second user exists, `primary_db` is linked to the persistent-store service,
branding carries non-default values, and the dump restores into a scratch
database. An unverified dump is not a baseline.
