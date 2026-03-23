# Progento Self-Hosted

Run [Progento](https://github.com/stefano-edgible/Progento) by pulling pre-built images—no build required.

**Platforms:** The same setup works on **Linux** (e.g. EC2) and **macOS** (Docker Desktop). On Linux, `sudo ./setup-volumes.sh` sets correct ownership for Postgres data; `chmod 777` on bind-mounted dirs helps when UIDs don’t match the host. On macOS, a **Postgres entrypoint wrapper** (`scripts/db/postgres-entrypoint-wrapper.sh`) fixes permissions inside the container before Postgres starts. Use **`PROGENTO_IMAGE_TAG=latest-arm64`** on Apple Silicon if you only use arm64-built images (see **Images** below).

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
   # Edit .env if needed (e.g. PROGENTO_DATA_ROOT=/data, POSTGRES_PASSWORD)
   ```

3. **Create volume dirs and start (all services in Docker)**
   ```bash
   chmod +x *.sh scripts/db/*.sh
   sudo ./setup-volumes.sh   # so Postgres (UID 999) can use the data dir on Linux; safe on macOS too
   ./start.sh
   ```

4. **Open the app** at **http://localhost:3001** (or your host IP).

## Scripts

| Script | Description |
|--------|-------------|
| `setup-volumes.sh` | Create `volumes/*` under `PROGENTO_DATA_ROOT`. Run with **`sudo`** so Postgres can write; run once or after `rm -rf volumes`. |
| `start.sh` | Start full stack (Ollama + embedding + Weaviate + Postgres + API + UI) in Docker |
| `start-external-ollama.sh` | Same but **Ollama runs on the host** (e.g. native install for GPU). Set `OLLAMA_URL` in `.env` (e.g. `http://host.docker.internal:11434`) |
| `start-external-embedding.sh` | Same but **embedding service runs on the host** (e.g. GPU). Set `EMBEDDING_SERVICE_URL` in `.env` (e.g. `http://host.docker.internal:8002`) |
| `start-external-both.sh` | Both Ollama and embedding on the host |
| `stop.sh` | Stop all Progento containers |

## Ports

- **3001** – UI (web)
- **8001** – API
- **11434** – Ollama (if in Docker)
- **8002** – Embedding service (if in Docker)
- **8080** – Weaviate
- **5433** – Postgres (host; 5432 inside container)

## Data

By default, data is stored under `./volumes/` (or `PROGENTO_DATA_ROOT` from `.env`). Use a dedicated path (e.g. `/data` on EC2) and set `PROGENTO_DATA_ROOT=/data` in `.env`; run **`sudo ./setup-volumes.sh`** from the repo so it creates `/data/volumes/...` with usable permissions.

## Images

Images are pulled from **GitHub Container Registry** (`ghcr.io/stefano-edgible/progento-*`). Ensure `GHCR_OWNER` in `.env` matches (default: `stefano-edgible`).

**Apple Silicon:** default images are tagged `latest` (amd64). If you build/push with `DOCKER_PLATFORM=linux/arm64` from the Progento repo (`registry/build-push.sh`), set **`PROGENTO_IMAGE_TAG=latest-arm64`** in `.env` before `docker compose pull`.

