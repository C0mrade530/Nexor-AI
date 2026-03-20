"""Event model — semantic scene extracted from audio."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .base import Base, TimestampMixin, UUIDMixin


class Event(UUIDMixin, TimestampMixin, Base):
    """A semantic event extracted from audio — meeting, idea, task, etc."""

    __tablename__ = "events"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    session_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("audio_sessions.id"), index=True
    )

    # Classification
    event_type: Mapped[str] = mapped_column(
        Enum(
            "meeting", "idea", "task", "commitment", "personal_thought",
            "planning", "sales_call", "casual_conversation", "emotional_episode",
            "follow_up", "decision", "other",
            name="event_type",
        ),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(500), nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False)

    # Timing
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    duration_seconds: Mapped[float | None] = mapped_column(Float)

    # Structured extraction (JSONB for flexibility)
    participants: Mapped[dict | None] = mapped_column(JSONB)  # ["name1", "name2"]
    action_items: Mapped[dict | None] = mapped_column(JSONB)  # [{"task": "...", "assignee": "..."}]
    ideas: Mapped[dict | None] = mapped_column(JSONB)  # [{"text": "...", "category": "..."}]
    decisions: Mapped[dict | None] = mapped_column(JSONB)  # [{"decision": "...", "context": "..."}]
    commitments: Mapped[dict | None] = mapped_column(JSONB)  # [{"promise": "...", "by": "..."}]
    follow_ups: Mapped[dict | None] = mapped_column(JSONB)  # [{"action": "...", "deadline": "..."}]
    objections: Mapped[dict | None] = mapped_column(JSONB)  # for sales calls

    # Metadata
    emotional_tone: Mapped[str | None] = mapped_column(String(50))
    urgency: Mapped[int | None] = mapped_column(Integer)  # 1-5
    importance: Mapped[int | None] = mapped_column(Integer)  # 1-5
    tags: Mapped[dict | None] = mapped_column(JSONB)  # ["tag1", "tag2"]
    confidence_score: Mapped[float | None] = mapped_column(Float)

    # Calendar suggestion
    suggested_calendar_event: Mapped[dict | None] = mapped_column(JSONB)
    # {"title": "...", "datetime": "...", "participants": [...], "notes": "..."}

    # Source reference
    transcript_excerpt: Mapped[str | None] = mapped_column(Text)
    source_chunk_ids: Mapped[dict | None] = mapped_column(JSONB)

    # Relationships
    user = relationship("User", back_populates="events")
    session = relationship("AudioSession")


class DailySummary(UUIDMixin, TimestampMixin, Base):
    """AI-generated daily summary with coaching feedback."""

    __tablename__ = "daily_summaries"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True
    )
    date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)

    # Summary content
    headline: Mapped[str] = mapped_column(String(500), nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    key_events: Mapped[dict | None] = mapped_column(JSONB)
    key_ideas: Mapped[dict | None] = mapped_column(JSONB)
    key_decisions: Mapped[dict | None] = mapped_column(JSONB)
    new_tasks: Mapped[dict | None] = mapped_column(JSONB)
    commitments_made: Mapped[dict | None] = mapped_column(JSONB)
    follow_ups_needed: Mapped[dict | None] = mapped_column(JSONB)

    # Coaching
    emotional_state_summary: Mapped[str | None] = mapped_column(Text)
    blind_spots: Mapped[dict | None] = mapped_column(JSONB)
    coaching_feedback: Mapped[str | None] = mapped_column(Text)
    one_thing_for_tomorrow: Mapped[str | None] = mapped_column(String(500))
    effectiveness_score: Mapped[float | None] = mapped_column(Float)

    # Stats
    total_events: Mapped[int | None] = mapped_column(Integer)
    total_meetings: Mapped[int | None] = mapped_column(Integer)
    total_ideas: Mapped[int | None] = mapped_column(Integer)
    total_recording_minutes: Mapped[float | None] = mapped_column(Float)

    # Relationships
    user = relationship("User", back_populates="daily_summaries")
