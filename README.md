# Progento Self-Hosted

Run [Progento](https://github.com/stefano-edgible/Progento) by pulling pre-built images—no build required.

**Platforms:** The same setup works on **Linux** (e.g. EC2) and **macOS** (Docker Desktop). On Linux, `sudo ./setup-volumes.sh` sets correct ownership for Postgres data; `chmod 777` on bind-mounted dirs helps when UIDs don’t match the host. On macOS, a **Postgres entrypoint wrapper** (`scripts/db/postgres-entrypoint-wrapper.sh`) fixes permissions inside the container before Postgres starts.

**GHCR images (api / ui / embedding):** Compose sets **`platform: linux/amd64`** by default so **Apple Silicon can pull `:latest`** (amd64-only manifests) and run via emulation. For **native arm64** images you pushed as `latest-arm64`, set in `.env`: **`PROGENTO_IMAGE_TAG=latest-arm64`** and **`PROGENTO_DOCKER_PLATFORM=linux/arm64`** (see **Images** below).

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

   **Apple Silicon (M1/M2/M3):** With the current compose files you usually **do not** need to change anything: Progento GHCR services default to **`linux/amd64`** so `docker compose pull` succeeds. For **faster native arm64** images, push `latest-arm64` from the Progento repo, then set **`PROGENTO_IMAGE_TAG=latest-arm64`** and **`PROGENTO_DOCKER_PLATFORM=linux/arm64`** in `.env`.

3. **Create volume dirs and start (all services in Docker)**
   ```bash
   chmod +x *.sh
   chmod +x scripts/db/postgres-entrypoint-wrapper.sh
   sudo ./setup-volumes.sh
   ./start.sh
   ```
   `sudo` sets ownership on the Postgres data dir on Linux; it is safe on macOS too. Do not paste comment text after `sudo` on the same line—run each command on its own line.

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

**Apple Silicon:** Default compose uses **`PROGENTO_DOCKER_PLATFORM=linux/amd64`** (implicit) so **`latest`** pulls and runs under emulation. For native arm64, after pushing **`latest-arm64`** with `registry/build-push.sh` and `DOCKER_PLATFORM=linux/arm64`, set **`PROGENTO_IMAGE_TAG=latest-arm64`** and **`PROGENTO_DOCKER_PLATFORM=linux/arm64`** in `.env`.

