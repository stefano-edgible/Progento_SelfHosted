# Progento Self-Hosted

Run [Progento](https://github.com/stefano-edgible/Progento) by pulling pre-built images—no build required.

## Prerequisites

- **Docker** and **Docker Compose** (v2)
- Optional: **Ollama** and/or **embedding service** on the host (e.g. GPU); otherwise they run in Docker

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
   chmod +x *.sh
   ./setup-volumes.sh
   ./start.sh
   ```

4. **Open the app** at **http://localhost:3001** (or your host IP).

## Scripts

| Script | Description |
|--------|-------------|
| `setup-volumes.sh` | Create volume directories (run once, or when using a new data root) |
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

By default, data is stored under `./volumes/` (or `PROGENTO_DATA_ROOT` from `.env`). Use a dedicated path (e.g. `/data`) on a server with a data disk.

## Images

Images are pulled from **GitHub Container Registry** (`ghcr.io/stefano-edgible/progento-*`). Ensure `GHCR_OWNER` in `.env` matches (default: `stefano-edgible`).

