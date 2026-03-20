"""LifeOS Backend — FastAPI application."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import audio, events, process, search
from app.core.config import settings
from app.core.database import close_db, init_db

logging.basicConfig(level=logging.INFO if not settings.debug else logging.DEBUG)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup/shutdown lifecycle."""
    logger.info("LifeOS starting up...")
    try:
        await init_db()
        logger.info("Database initialized")
    except Exception as e:
        logger.warning(f"Database init skipped (not available): {e}")
        logger.info("Running in in-memory mode — no persistence")
    yield
    await close_db()
    logger.info("LifeOS shut down")


app = FastAPI(
    title="LifeOS API",
    description="AI wearable memory assistant — backend API",
    version=settings.app_version,
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(audio.router, prefix=settings.api_prefix)
app.include_router(events.router, prefix=settings.api_prefix)
app.include_router(search.router, prefix=settings.api_prefix)
app.include_router(process.router, prefix=settings.api_prefix)


@app.get("/health")
async def health():
    return {"status": "ok", "version": settings.app_version}


@app.get("/")
async def root():
    return {
        "name": "LifeOS API",
        "version": settings.app_version,
        "docs": "/docs",
    }
