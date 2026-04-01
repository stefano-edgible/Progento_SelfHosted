# Host embedding service (GPU)

Native **FastAPI + sentence-transformers + PyTorch** so **Metal (macOS)** or **CUDA (Linux)** can run embeddings. This folder is a **copy** of `Progento/embedding_service`; refresh it when you upgrade Progento if behavior diverges.

## Setup

**Automatic (recommended):** from repo root, set `PROGENTO_EMBEDDING_START_CMD=./scripts/start-embedding-host.sh` in `.env`. The script **creates `embedding_service/.venv`** if needed and **`pip install -r requirements.txt`** if `fastapi` is missing, then starts the server.

**Manual one-time:**

```bash
cd embedding_service
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Run

From repo root (or use `./scripts/start-embedding-host.sh`):

```bash
cd embedding_service && source .venv/bin/activate && python main.py
```

Listens on **0.0.0.0:8002**. By default **logging is WARNING** (quiet stdout). **`LOG_LEVEL` in `../.env` is not read** (that setting is for the API container and would force noisy INFO here if inherited). Use **`EMBEDDING_LOG_LEVEL`**, **`UVICORN_LOG_LEVEL`**, and **`EMBEDDING_ACCESS_LOG`** only—see `../.env.example`.
