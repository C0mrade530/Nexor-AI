"""Database engine, session, and initialization."""

from typing import AsyncGenerator

engine = None
async_session_factory = None


def _ensure_engine():
    """Lazily create engine and session factory (only when DB is actually needed)."""
    global engine, async_session_factory
    if engine is not None:
        return

    from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
    from sqlalchemy.pool import NullPool

    from app.core.config import settings

    engine = create_async_engine(
        settings.database_url,
        poolclass=NullPool,
        echo=settings.debug,
    )
    async_session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )


async def get_db() -> AsyncGenerator:
    """FastAPI dependency for database sessions."""
    _ensure_engine()
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def init_db() -> None:
    """Create all tables on startup (dev mode). Use Alembic for production."""
    _ensure_engine()
    from app.models.base import Base

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def close_db() -> None:
    """Dispose engine on shutdown."""
    if engine is not None:
        await engine.dispose()
