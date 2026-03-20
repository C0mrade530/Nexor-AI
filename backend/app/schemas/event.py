"""Request/response schemas for events."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class ActionItem(BaseModel):
    task: str
    assignee: str | None = None
    deadline: str | None = None


class Idea(BaseModel):
    text: str
    category: str | None = None  # content | startup | sales | personal | product
    value_score: int | None = Field(None, ge=1, le=5)


class CalendarSuggestion(BaseModel):
    title: str
    datetime_str: str | None = None
    participants: list[str] = []
    notes: str | None = None
    reminder_minutes: int = 15


class EventResponse(BaseModel):
    id: uuid.UUID
    event_type: str
    title: str
    summary: str
    started_at: datetime
    ended_at: datetime | None
    duration_seconds: float | None
    participants: list[str] | None
    action_items: list[ActionItem] | None
    ideas: list[Idea] | None
    decisions: list[dict] | None
    commitments: list[dict] | None
    follow_ups: list[dict] | None
    emotional_tone: str | None
    urgency: int | None
    importance: int | None
    tags: list[str] | None
    confidence_score: float | None
    suggested_calendar_event: CalendarSuggestion | None
    transcript_excerpt: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class EventListResponse(BaseModel):
    events: list[EventResponse]
    total: int
    page: int
    page_size: int


class DailySummaryResponse(BaseModel):
    id: uuid.UUID
    date: datetime
    headline: str
    summary: str
    key_events: list[dict] | None
    key_ideas: list[dict] | None
    key_decisions: list[dict] | None
    new_tasks: list[dict] | None
    commitments_made: list[dict] | None
    follow_ups_needed: list[dict] | None
    emotional_state_summary: str | None
    coaching_feedback: str | None
    one_thing_for_tomorrow: str | None
    effectiveness_score: float | None
    total_events: int | None
    total_meetings: int | None
    total_ideas: int | None
    total_recording_minutes: float | None
    created_at: datetime

    model_config = {"from_attributes": True}
