# Host embedding service (GPU)

Native **FastAPI + sentence-transformers + PyTorch** so **Metal (macOS)** or **CUDA (Linux)** can run embeddings. This folder is a **copy** of `Progento/embedding_service`; refresh it when you upgrade Progento if behavior diverges.

## One-time setup

```bash
cd embedding_service
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Use the same venv whenever you start the service (or install into a global env you prefer).

## Run

From repo root (or use `./scripts/start-embedding-host.sh`, which `cd`s here):

```bash
cd embedding_service && source .venv/bin/activate && python main.py
```

Listens on **0.0.0.0:8002**. Env vars: `PROGENTO_EMBEDDING_MODEL`, `EMBEDDING_ACCESS_LOG`, `EMBEDDING_LOG_LEVEL`, `UVICORN_LOG_LEVEL` (see main.py and `../.env.example`).
