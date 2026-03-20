"""User model with privacy preferences."""

from sqlalchemy import Boolean, Enum, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimestampMixin, UUIDMixin


class User(UUIDMixin, TimestampMixin, Base):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)

    # Privacy preferences
    audio_retention_policy: Mapped[str] = mapped_column(
        Enum("keep_all", "after_transcription", "summaries_only", name="retention_policy"),
        default="after_transcription",
    )
    default_consent_mode: Mapped[str] = mapped_column(
        Enum("private", "meeting", "public", name="consent_mode"),
        default="private",
    )
    audio_retention_days: Mapped[int] = mapped_column(default=30)
    encrypt_audio: Mapped[bool] = mapped_column(Boolean, default=True)

    # Settings
    timezone: Mapped[str] = mapped_column(String(50), default="UTC")
    language: Mapped[str] = mapped_column(String(10), default="ru")
    coaching_enabled: Mapped[bool] = mapped_column(Boolean, default=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Relationships
    audio_sessions = relationship("AudioSession", back_populates="user", lazy="selectin")
    events = relationship("Event", back_populates="user", lazy="selectin")
    daily_summaries = relationship("DailySummary", back_populates="user", lazy="selectin")
