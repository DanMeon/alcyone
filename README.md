<!--
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at
  http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
-->

# Alcyone

[![License](https://img.shields.io/:license-Apache%202-green.svg)](https://www.apache.org/licenses/LICENSE-2.0.txt)

[Apache Atlas 2.5.0-rc0](https://github.com/apache/atlas) fork with PostgreSQL backend bug fixes for production use.

## What's Different from Upstream

| Severity | File | Fix |
|----------|------|-----|
| CRITICAL | `RdbmsUniqueKeyHandler.java` | INSERT to upsert (ON CONFLICT DO UPDATE) for all 4 unique key tables |
| CRITICAL | `RdbmsStore.java` | `getStoreIdOrCreate()` race condition: re-query before create, catch Exception |
| CRITICAL | `RdbmsStore.java` | `getKeyIdOrCreate()` race condition: same pattern |
| HIGH | `RdbmsStore.java` | `storeId` field marked `volatile` for thread visibility |
| HIGH | `atlas.sh` | DB connection values parameterized via environment variables |
| MEDIUM | `DbEntityAuditDao.java` | JPQL injection fix: whitelist validation + parameterized queries |
| BUG | `AtlasJanusGraphDatabase.java` | Java 17 compatibility: VarHandle-based `removeFinalModifier()` with legacy fallback |

## Quick Start

```bash
# 1. Configure
cp .env.example .env
# Edit .env as needed (DB host, credentials, etc.)

# 2. Build (30min~1hr on first run)
./setup.sh

# 3. Run
docker compose up -d

# 4. Access
# http://localhost:21000
# Default: admin / atlasR0cks!
```

## Environment Variables

### PostgreSQL
| Variable | Default | Description |
|----------|---------|-------------|
| `ATLAS_DB_HOST` | `atlas-db` | PostgreSQL host |
| `ATLAS_DB_PORT` | `5432` | PostgreSQL port |
| `ATLAS_DB_NAME` | `atlas` | Database name |
| `ATLAS_DB_USER` | `atlas` | Database user |
| `ATLAS_DB_PASSWORD` | `atlasR0cks!` | Database password |

### Atlas Admin
| Variable | Default | Description |
|----------|---------|-------------|
| `ATLAS_ADMIN_USER` | `admin` | Web UI admin username |
| `ATLAS_ADMIN_PASSWORD` | `atlasR0cks!` | Web UI admin password |

### Build
| Variable | Default | Description |
|----------|---------|-------------|
| `ATLAS_BASE_JAVA_VERSION` | `11` | Java version for base image |
| `ATLAS_BUILD_JAVA_VERSION` | `11` | Java version for Maven build |
| `ATLAS_SERVER_JAVA_VERSION` | `11` | Java version for runtime |

## Known Limitations

1. **PostgreSQL only** -- ON CONFLICT syntax is PostgreSQL-specific
2. **Java 11 recommended** -- Java 17 works with graceful fallback but requires `--add-opens` flag
3. **React UI incomplete** -- Legacy UI (`/index.html`) only; new UI (`/n/index.html`) not functional

## License

Apache License 2.0. Forked from [Apache Atlas](https://github.com/apache/atlas) `release-2.5.0-rc0`.
