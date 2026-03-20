"""User schemas."""

import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    full_name: str


class UserUpdate(BaseModel):
    full_name: str | None = None
    timezone: str | None = None
    language: str | None = None
    coaching_enabled: bool | None = None


class UserPrivacySettings(BaseModel):
    audio_retention_policy: str = Field(
        default="after_transcription",
        description="keep_all | after_transcription | summaries_only",
    )
    audio_retention_days: int = Field(default=30, ge=1, le=365)
    encrypt_audio: bool = True
    default_consent_mode: str = Field(default="private", description="private | meeting | public")


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    full_name: str
    timezone: str
    language: str
    coaching_enabled: bool
    audio_retention_policy: str
    default_consent_mode: str
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
