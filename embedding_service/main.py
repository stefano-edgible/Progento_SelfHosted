"""Standalone Embedding Service for Progento.
Runs natively on macOS to leverage M4 chip GPU via Metal Performance Shaders (MPS).
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import logging
import torch
from sentence_transformers import SentenceTransformer
import gc


def _configure_logging():
    """EMBEDDING_LOG_LEVEL or LOG_LEVEL: DEBUG, INFO, WARNING, ERROR (default WARNING for quiet stdout)."""
    import os as _os
    level_name = (
        _os.getenv("EMBEDDING_LOG_LEVEL")
        or _os.getenv("LOG_LEVEL")
        or "WARNING"
    ).upper()
    level = getattr(logging, level_name, logging.WARNING)
    logging.basicConfig(
        level=level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        force=True,
    )
    for name in (
        "uvicorn",
        "uvicorn.error",
        "uvicorn.access",
        "fastapi",
        "httpx",
        "httpcore",
        "sentence_transformers",
        "transformers",
        "torch",
    ):
        logging.getLogger(name).setLevel(level)


import os
_configure_logging()
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Progento Embedding Service",
    description="Embedding generation service using Metal Performance Shaders (MPS) on M4 chip",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global model instance
model = None
# Default model - should match PROGENTO_EMBEDDING_MODEL env var or config default
# Default to all-mpnet-base-v2 (768 dim) to match Progento config default
model_name = os.getenv("PROGENTO_EMBEDDING_MODEL", "all-mpnet-base-v2")  # Match Progento config default
device = None  # Store device for model reloading

# Pre-configured available models
AVAILABLE_MODELS = [
    "all-MiniLM-L6-v2",  # Default, small, fast (22MB, 384 dimensions)
    "all-mpnet-base-v2",  # Larger, better quality (420MB, 768 dimensions)
    "sentence-transformers/all-MiniLM-L12-v2",  # Medium size (134MB, 384 dimensions)
]

# Request/Response models
class EmbedRequest(BaseModel):
    text: str

class EmbedBatchRequest(BaseModel):
    texts: List[str]

class EmbedResponse(BaseModel):
    embedding: List[float]

class EmbedBatchResponse(BaseModel):
    embeddings: List[List[float]]

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    device: str
    model_name: Optional[str] = None

class ModelInfo(BaseModel):
    name: str
    description: str

class ModelsAvailableResponse(BaseModel):
    models: List[ModelInfo]

class ModelCurrentResponse(BaseModel):
    model_name: str
    device: str

class ModelSetRequest(BaseModel):
    model_name: str

def _get_device():
    """Get the appropriate device for model loading."""
    if torch.backends.mps.is_available():
        return "mps"
    elif torch.cuda.is_available():
        return "cuda"
    else:
        return "cpu"

def _load_model(model_name_to_load: str):
    """Load or reload embedding model."""
    global model, model_name, device
    
    # Unload existing model if different
    if model is not None and model_name != model_name_to_load:
        logger.info(f"Unloading current model: {model_name}")
        del model
        gc.collect()
        model = None
    
    # Load new model if not already loaded
    if model is None:
        device = _get_device()
        if device == "mps":
            logger.info("Metal Performance Shaders (MPS) available - Using M4 GPU")
        elif device == "cuda":
            logger.info("CUDA available - Using GPU")
        else:
            logger.info("No GPU available - Using CPU")
        
        try:
            logger.info(f"Loading embedding model: {model_name_to_load} on device: {device}")
            model = SentenceTransformer(model_name_to_load, device=device)
            model_name = model_name_to_load
            logger.info(f"Embedding model loaded successfully on {device}")
        except Exception as e:
            logger.error(f"Failed to load embedding model: {e}")
            raise

@app.on_event("startup")
async def startup_event():
    """Load embedding model on startup with Metal/MPS support."""
    logger.info("Starting Progento Embedding Service...")
    _load_model(model_name)

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    global model
    logger.info("Shutting down Embedding Service...")
    if model is not None:
        del model
        gc.collect()

@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint."""
    global model, model_name, device
    
    if model is None:
        return HealthResponse(
            status="unhealthy",
            model_loaded=False,
            device="unknown",
            model_name=None
        )
    
    # Get device from model
    current_device = str(next(model.parameters()).device)
    
    return HealthResponse(
        status="healthy",
        model_loaded=True,
        device=current_device,
        model_name=model_name
    )

@app.get("/models/available", response_model=ModelsAvailableResponse)
async def list_available_models():
    """List available pre-configured embedding models."""
    model_descriptions = {
        "all-MiniLM-L6-v2": "Default, small, fast (22MB, 384 dimensions)",
        "all-mpnet-base-v2": "Larger, better quality (420MB, 768 dimensions)",
        "sentence-transformers/all-MiniLM-L12-v2": "Medium size (134MB, 384 dimensions)",
    }
    
    models = [
        ModelInfo(
            name=name,
            description=model_descriptions.get(name, "Pre-configured embedding model")
        )
        for name in AVAILABLE_MODELS
    ]
    
    return ModelsAvailableResponse(models=models)

@app.get("/models/current", response_model=ModelCurrentResponse)
async def get_current_model():
    """Get currently loaded model."""
    global model, model_name, device
    
    if model is None:
        raise HTTPException(status_code=503, detail="No model loaded")
    
    current_device = str(next(model.parameters()).device)
    
    return ModelCurrentResponse(
        model_name=model_name,
        device=current_device
    )

@app.post("/models/set")
async def set_model(request: ModelSetRequest):
    """Set the embedding model (reload if different)."""
    global model, model_name
    
    if request.model_name not in AVAILABLE_MODELS:
        raise HTTPException(
            status_code=400,
            detail=f"Model '{request.model_name}' not in available models. Available: {', '.join(AVAILABLE_MODELS)}"
        )
    
    # Load model if different from current
    if model_name != request.model_name:
        logger.info(f"Switching embedding model from {model_name} to {request.model_name}")
        _load_model(request.model_name)
    else:
        logger.info(f"Model {request.model_name} is already loaded")
    
    return {
        "message": f"Model set to {model_name}",
        "model_name": model_name
    }

@app.post("/embed", response_model=EmbedResponse)
async def embed(request: EmbedRequest):
    """Generate embedding for a single text."""
    global model
    
    if model is None:
        raise HTTPException(status_code=503, detail="Embedding model not loaded")
    
    try:
        logger.debug(f"Generating embedding for text (length: {len(request.text)})")
        
        embedding = model.encode(
            request.text,
            normalize_embeddings=True,
            show_progress_bar=False,
            convert_to_numpy=True
        )
        
        result = embedding.tolist()
        del embedding
        gc.collect()
        
        return EmbedResponse(embedding=result)
    except Exception as e:
        logger.error(f"Error generating embedding: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to generate embedding: {str(e)}")

@app.post("/embed_batch", response_model=EmbedBatchResponse)
async def embed_batch(request: EmbedBatchRequest):
    """Generate embeddings for multiple texts."""
    global model
    
    if model is None:
        raise HTTPException(status_code=503, detail="Embedding model not loaded")
    
    try:
        logger.debug(f"Generating embeddings for {len(request.texts)} texts...")
        
        embeddings = model.encode(
            request.texts,
            normalize_embeddings=True,
            show_progress_bar=False,
            batch_size=min(32, len(request.texts)),  # Reasonable batch size
            convert_to_numpy=True
        )
        
        result = embeddings.tolist()
        del embeddings
        gc.collect()
        
        return EmbedBatchResponse(embeddings=result)
    except Exception as e:
        logger.error(f"Error generating batch embeddings: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to generate embeddings: {str(e)}")

if __name__ == "__main__":
    import uvicorn

    # Access logs off by default (API polls /health, /models/* often). EMBEDDING_ACCESS_LOG=1 to enable.
    _al = os.getenv("EMBEDDING_ACCESS_LOG", "0").lower() in ("1", "true", "yes")
    _lv = (os.getenv("UVICORN_LOG_LEVEL") or os.getenv("EMBEDDING_LOG_LEVEL") or "warning").lower()
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8002,
        log_level=_lv,
        access_log=_al,
    )

