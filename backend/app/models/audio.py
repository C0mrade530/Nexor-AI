"""Audio session and chunk models."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimestampMixin, UUIDMixin


class AudioSession(UUIDMixin, TimestampMixin, Base):
    """A recording session — continuous capture period."""

    __tablename__ = "audio_sessions"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    duration_seconds: Mapped[float | None] = mapped_column(Float)

    source: Mapped[str] = mapped_column(
        Enum("iphone_app", "apple_watch", "wearable", "upload", name="audio_source"),
        default="iphone_app",
    )
    consent_mode: Mapped[str] = mapped_column(
        Enum("private", "meeting", "public", name="session_consent_mode"),
        default="private",
    )
    status: Mapped[str] = mapped_column(
        Enum("recording", "uploading", "uploaded", "processing", "processed", "failed",
             name="session_status"),
        default="uploading",
    )
    environment_tag: Mapped[str | None] = mapped_column(String(50))
    location_label: Mapped[str | None] = mapped_column(String(255))

    # Relationships
    user = relationship("User", back_populates="audio_sessions")
    chunks = relationship("AudioChunk", back_populates="session", lazy="selectin")


class AudioChunk(UUIDMixin, TimestampMixin, Base):
    """Individual audio segment within a session."""

    __tablename__ = "audio_chunks"

    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("audio_sessions.id"), nullable=False, index=True
    )
    chunk_index: Mapped[int] = mapped_column(Integer, nullable=False)
    file_path: Mapped[str] = mapped_column(String(500), nullable=False)
    file_size_bytes: Mapped[int | None] = mapped_column(Integer)
    duration_seconds: Mapped[float] = mapped_column(Float, nullable=False)
    start_offset_seconds: Mapped[float] = mapped_column(Float, default=0.0)

    # Processing
    status: Mapped[str] = mapped_column(
        Enum("pending", "transcribing", "transcribed", "failed", name="chunk_status"),
        default="pending",
    )
    transcript: Mapped[str | None] = mapped_column(Text)
    transcript_confidence: Mapped[float | None] = mapped_column(Float)
    language_detected: Mapped[str | None] = mapped_column(String(10))
    has_voice_activity: Mapped[bool | None] = mapped_column(default=True)

    # Relationships
    session = relationship("AudioSession", back_populates="chunks")
