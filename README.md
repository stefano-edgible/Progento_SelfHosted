# Progento Self-Hosted

Run [Progento](https://github.com/stefano-edgible/Progento) by pulling pre-built images—no build required.

**Platforms:** The same setup works on **Linux** (e.g. EC2) and **macOS** (Docker Desktop). On Linux, `sudo ./setup-volumes.sh` sets correct ownership for Postgres data; `chmod 777` on bind-mounted dirs helps when UIDs don’t match the host. On macOS, a **Postgres entrypoint wrapper** (`scripts/db/postgres-entrypoint-wrapper.sh`) fixes permissions inside the container before Postgres starts.

**GHCR images (api / ui / embedding):** Compose uses the image tag **`PROGENTO_IMAGE_TAG`** (default **`latest`**). For **Apple Silicon** and **Intel/AMD64** servers to use the same tag, publish **`latest` as a multi-arch manifest** (linux/amd64 + linux/arm64) with the **[Progento](https://github.com/stefano-edgible/Progento) `registry/build-push.sh`** script (default behaviour there). Then **`docker compose pull`** picks the right architecture automatically. If your registry only offers amd64 on **`latest`**, either re-push with multi-arch or set **`PROGENTO_IMAGE_TAG=latest-arm64`** after publishing an arm64-only tag.

## Prerequisites

- **Docker** and **Docker Compose** (v2)
- Optional: **Ollama** and/or **embedding service** on the host (e.g. GPU); otherwise they run in Docker

**Suggested minimum hardware (full stack in Docker)**

- **RAM:** 8 GB minimum; **16 GB** recommended. Containers (Ollama, embedding, Weaviate, Postgres, API, UI) can use ~10 GB in total; extra headroom avoids OOM.
- **Disk (for Docker images and overlay):** At least **25–30 GB** free on the partition where Docker stores data (e.g. root or `/var/lib/docker`). Large images include Ollama and the embedding model. If you see “no space left on device” during `docker compose pull`, free space or resize the volume.
- **Disk (for data):** At least **10 GB** for `volumes/` (repos, knowledge base, Weaviate, Postgres, Ollama models). Use a dedicated disk (e.g. EBS at `/data`) and set `PROGENTO_DATA_ROOT=/data` for production.
- **CPU:** 2+ cores; 4+ recommended if Ollama and embedding run in Docker (no GPU).

## Quick start

1. **Clone this repo**
   ```bash
   git clone https://github.com/stefano-edgible/Progento_SelfHosted.git
   cd Progento_SelfHosted
   ```

2. **Create `.env`**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` if needed (`PROGENTO_DATA_ROOT`, `POSTGRES_PASSWORD`, etc.).

3. **Create volume dirs and start (all services in Docker)**
   ```bash
   chmod +x *.sh
   chmod +x scripts/db/postgres-entrypoint-wrapper.sh
   sudo ./setup-volumes.sh
   ./start.sh
   ```
   `sudo` sets ownership on the Postgres data dir on Linux; it is safe on macOS too. Do not paste comment text after `sudo` on the same line—run each command on its own line.

4. **Open the app** at **http://localhost:3001** (or your host IP).

5. **Finish setup (required to query):** load Ollama models and configure a KBase — see **[After installation: models and KBase](#after-installation-models-and-kbase)** below.

## After installation: models and KBase

Pre-built images **do not** include Ollama LLM weights, and **no documents are indexed** until you scan. After `start.sh` (or `start-external-ollama.sh`, etc.), do the following.

### 1) Load Ollama LLM models

Pull at least one model into the **same** Ollama instance the API uses (`OLLAMA_URL` in `.env`).

| How you run Ollama | Example: pull `phi` |
|--------------------|---------------------|
| **In Docker** (default `./start.sh` — service `ollama`, container **`progento-ollama`**) | `docker exec -it progento-ollama ollama pull phi` |
| **From the compose project directory** (alternative) | `docker compose exec ollama ollama pull phi` |
| **On the host** (`./start-external-ollama.sh`, with `OLLAMA_URL=http://host.docker.internal:11434` on macOS/Windows, or your host LAN IP on Linux) | On the host: `ollama pull phi` |
| **Remote URL** (`OLLAMA_URL=https://…`) | Pull on that server or follow the provider’s docs; set **`OLLAMA_API_KEY`** in `.env` if required |

Use any name from the [Ollama library](https://ollama.com/library); align with **`OLLAMA_MODEL`** in `.env` if you set a default. Check **`GET http://localhost:8001/api/health/ollama`** (or your API port) — `models` should list the tags you pulled.

### 2) Set up a KBase

1. **Bind-mount content** the API can read: copy **`kbase.volumes.example`** → **`kbase.volumes`** and add lines `host_path:/kbase/your_name:ro` (see **[KBase bind mounts](#kbase-bind-mounts-one-list-for-every-compose-scenario)** above). Restart the stack so the generated compose includes those mounts.
2. In the UI (**Repositories**), **Add repository** with path **`/kbase/your_name`** (matching the container path).
3. **Scan** the repository and wait for it to finish.

Without mounted paths + scan, queries have no indexed context. Optional: also add repos under **`volumes/code_repos`** if your compose exposes them at a known in-container path.

## Scripts

| Script | Description |
|--------|-------------|
| `setup-volumes.sh` | Create `volumes/*` under `PROGENTO_DATA_ROOT`. Run with **`sudo`** so Postgres can write; run once or after `rm -rf volumes`. |
| `start.sh` | Start full stack (Ollama + embedding + Weaviate + Postgres + API + UI) in Docker |
| `start-external-ollama.sh` | Same but **Ollama runs on the host** (e.g. native install for GPU). Set `OLLAMA_URL` in `.env` (e.g. `http://host.docker.internal:11434`) |
| `start-external-embedding.sh` | Same but **embedding service runs on the host** (e.g. GPU). Set `EMBEDDING_SERVICE_URL` in `.env` (e.g. `http://host.docker.internal:8002`) |
| `start-external-both.sh` | Both Ollama and embedding on the host |
| `stop.sh` | Stop all Progento containers |
| `sync-from-progento.sh` | Maintainer: copy `scripts/db/postgres-entrypoint-wrapper.sh` from the Progento repo (see **Maintainers** below) |
| `scripts/gen-kbase-compose.sh` | Build `docker-compose.kbase.generated.yml` from `kbase.volumes` (see **KBase bind mounts** above) |
| `scripts/progento-compose.sh` | Sourced by `start*.sh`; merges `docker-compose.kbase.generated.yml` when present |

## Ports

- **3001** – UI (web)
- **8001** – API
- **11434** – Ollama (if in Docker)
- **8002** – Embedding service (if in Docker)
- **8080** – Weaviate
- **5433** – Postgres (host; 5432 inside container)

## Data

By default, data is stored under `./volumes/` (or `PROGENTO_DATA_ROOT` from `.env`). Use a dedicated path (e.g. `/data` on EC2) and set `PROGENTO_DATA_ROOT=/data` in `.env`; run **`sudo ./setup-volumes.sh`** from the repo so it creates `/data/volumes/...` with usable permissions.

## KBase bind mounts (one list for every compose scenario)

You may have several compose files (`docker-compose.yml`, `docker-compose.external-ollama.yml`, …). To avoid duplicating **`api`** volume lines in each file, use a **single mount list** and a **generated fragment**:

1. Copy the example list:
   ```bash
   cp kbase.volumes.example kbase.volumes
   ```
2. Edit **`kbase.volumes`**: one line per bind mount, Docker-style. The **container** path must include **`:/kbase/`** (Progento’s KBase root inside the API container).
   ```text
   /absolute/path/on/host:/kbase/my_docs:ro
   ```

3. Start as usual: **`./start.sh`** or **`./start-external-ollama.sh`** (etc.). Each script **`source`s `scripts/progento-compose.sh`**, which **runs `gen-kbase-compose.sh` first** (so you do **not** need to run the generator by hand after every edit). That writes **`docker-compose.kbase.generated.yml`** (gitignored) when **`kbase.volumes`** exists and has valid lines, then runs:
   ```bash
   docker compose -f <scenario>.yml -f docker-compose.kbase.generated.yml ...
   ```
   when the generated file exists. Docker Compose **merges** `api.volumes` from both files.

4. In the Progento UI, add a repository whose path is **`/kbase/my_docs`** (or whatever suffix you used), then scan.

- No **`kbase.volumes`** file → generator removes any stale **`docker-compose.kbase.generated.yml`**; behaviour matches stock compose.
- To regenerate without starting the stack: **`./scripts/gen-kbase-compose.sh`**
- Env **`KBASE_VOLUMES_FILE`** points to an alternate list path for **`gen-kbase-compose.sh`**.

## PostgreSQL schema (no SQL bootstrap in this repo)

There are **no** SQL init scripts in this repo for Postgres. Schema is applied when the API starts:

- The **`postgres:15`** image creates an empty database **`progento`** from `POSTGRES_DB` / user / password in compose.
- On startup, **`progento-api`** runs **`init_db()`** (SQLAlchemy **`create_all`** plus small migrations). That logic lives **inside the published API image**, so you do not copy `.sql` files into self-hosted.

**`scripts/db/postgres-entrypoint-wrapper.sh`** only fixes bind-mount ownership on macOS/Linux; it does not load schema.

## Maintainers: `sync-from-progento.sh`

If you develop **[Progento](https://github.com/stefano-edgible/Progento)** and change **`scripts/db/postgres-entrypoint-wrapper.sh`** there, run **`./sync-from-progento.sh`** from this repo to refresh the copy here (default source: **`../Progento`**). Cloners who only use released images do **not** need this script.

## Images

Images are pulled from **GitHub Container Registry** (`ghcr.io/stefano-edgible/progento-*`). Ensure `GHCR_OWNER` in `.env` matches (default: `stefano-edgible`).

**Multi-arch `latest` (recommended):** From the Progento repo, run **`registry/build-push.sh`** with default settings — it pushes **`linux/amd64` and `linux/arm64`** under **`latest`**. Then **`docker compose pull`** works on typical cloud VMs and Apple Silicon without setting `platform:` in compose.

**Legacy:** If `latest` is amd64-only, set **`PROGENTO_IMAGE_TAG=latest-arm64`** in `.env` after you have pushed that tag.

