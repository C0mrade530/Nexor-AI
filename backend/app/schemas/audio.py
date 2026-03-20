"""Request/response schemas for audio endpoints."""

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class AudioSessionCreate(BaseModel):
    source: str = Field(default="iphone_app", description="iphone_app | apple_watch | wearable | upload")
    consent_mode: str = Field(default="private", description="private | meeting | public")
    started_at: datetime
    environment_tag: str | None = None
    location_label: str | None = None


class AudioSessionResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    started_at: datetime
    ended_at: datetime | None
    duration_seconds: float | None
    source: str
    consent_mode: str
    status: str
    environment_tag: str | None
    location_label: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class AudioChunkUploadResponse(BaseModel):
    id: uuid.UUID
    session_id: uuid.UUID
    chunk_index: int
    duration_seconds: float
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class AudioSessionFinish(BaseModel):
    ended_at: datetime
