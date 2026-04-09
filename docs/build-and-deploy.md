# Build and Deploy Guide

## Quick Reference

| Command | Purpose |
|---------|---------|
| `just build` | Full Maven build (first time, ~30min) |
| `just rebuild` | Incremental Maven build (changes only) |
| `./build_push.sh arm` | Docker images for local testing (arm64) |
| `./build_push.sh --push` | Docker images for remote deploy (amd64) + push to NCR |
| `./build_push.sh --push atlas` | Rebuild & push atlas image only |
| `./build_push.sh prod --push` | Push to production registry |

## 1. Maven Build

Maven produces architecture-independent Java bytecode (`.jar`/`.tar.gz`). Build once, use for both arm and amd Docker images.

```bash
cd ~/Desktop/kevin/Alcyone

# First build (full, ~30min)
just build

# Subsequent builds (incremental, faster)
just rebuild
```

Prerequisites: JDK 8, Maven 3.x

## 2. Local Testing

Build arm64 Docker images and test with Alcyone's own `docker-compose.yml` (uses local image names like `atlas:latest`, not registry):

```bash
cd ~/Desktop/kevin/Alcyone

# Build local images
./build_push.sh arm

# Start containers
docker compose down -v
docker compose up -d

# Initialize Atlas (enum values + admin profile)
# (copy atlas-init.sh from jadx-sis or run manually)
curl -s -X POST -u admin:datahub -H "Content-Type: application/json" \
  -d '{"enumDefs":[{"name":"updateFrequencyEnum","elementDefs":[{"value":"NONE","ordinal":1},{"value":"DAILY","ordinal":2},{"value":"WEEKLY","ordinal":3},{"value":"MONTHLY","ordinal":4},{"value":"YEARLY","ordinal":5},{"value":"REALTIME","ordinal":6},{"value":"ADHOC","ordinal":7},{"value":"ONEOFF","ordinal":8},{"value":"FIVEYEARS","ordinal":9},{"value":"HOURLY","ordinal":10},{"value":"ETC","ordinal":11},{"value":"PER_3_MINUTES","ordinal":12},{"value":"TEST","ordinal":13}]}]}' \
  "http://localhost:21000/api/atlas/v2/types/typedefs"

# Import data (first time only)
curl -X POST -u admin:datahub \
  -F "data=@/Volumes/External-SSD/kevin/data/atlas/atlas-import.zip" \
  "http://localhost:21000/api/atlas/admin/import"

# Verify
curl -s -u admin:datahub \
  -H "Content-Type: application/json" \
  -d '{"typeName":"JadxDataset","query":"감귤","limit":3}' \
  "http://localhost:21000/api/atlas/v2/search/basic"
```

Note: local `.env` uses `POSTGRES_HOST=host.docker.internal`. Ensure the `atlas` database exists: `createdb -U kevin atlas`.

jadx-sis compose uses registry images (`${REGISTRY_ENDPOINT}/atlas:latest`), so it requires `./build_push.sh --push` first. Use Alcyone's own compose for local arm64 testing.

## 3. Remote Deploy

Build amd64 images and push to NCR registry:

```bash
cd ~/Desktop/kevin/Alcyone
./build_push.sh --push
```

On the remote server:

```bash
# Pull images
docker pull jadx-registry.ncr.gov-ntruss.com/atlas:latest
docker pull jadx-registry.ncr.gov-ntruss.com/atlas-zk:latest
docker pull jadx-registry.ncr.gov-ntruss.com/atlas-solr:latest
docker pull jadx-registry.ncr.gov-ntruss.com/atlas-kafka:latest

# Deploy
cd ~/jadx-sis
./run_docker.sh down middleware
./run_docker.sh up -d middleware

# Initialize
./scripts/atlas-init.sh

# Reindex (if needed)
./scripts/atlas-reindex.sh http://localhost:21000 --full
```

## 4. Common Scenarios

### Changed only `atlas.sh` or `Dockerfile.atlas`

No Maven rebuild needed:

```bash
./build_push.sh arm atlas        # local test
./build_push.sh --push atlas     # remote deploy
```

### Changed Java source code

Maven rebuild required:

```bash
just rebuild                      # incremental Maven build
./build_push.sh arm               # local images
./build_push.sh --push            # remote images
```

### Changed only jadx-sis compose/scripts

No build needed, just restart:

```bash
./run_docker.sh down middleware
./run_docker.sh up -d middleware
```

## 5. Registries

| Environment | Registry | Flag |
|-------------|----------|------|
| Dev (default) | `jadx-registry.ncr.gov-ntruss.com` | `dev` or omit |
| Production | `jadx-si-registry.ncr.gov-ntruss.com` | `prod` |

```bash
./build_push.sh prod --push      # push to production registry
```

## 6. Deprecated

`./setup.sh build` / `rebuild` / `all` are deprecated. Use `just build` + `./build_push.sh` instead. Only `./setup.sh download` remains available for downloading dependency archives.
