"""Audio upload and session management endpoints."""

import os
import uuid
from datetime import datetime

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.core.config import settings
from app.schemas.audio import (
    AudioChunkUploadResponse,
    AudioSessionCreate,
    AudioSessionFinish,
    AudioSessionResponse,
)

router = APIRouter(prefix="/audio", tags=["audio"])

# In-memory store for MVP — replace with DB in production
_sessions: dict[str, dict] = {}
_chunks: dict[str, list[dict]] = {}


@router.post("/sessions", response_model=AudioSessionResponse)
async def create_session(session: AudioSessionCreate):
    """Start a new audio recording session."""
    session_id = str(uuid.uuid4())
    now = datetime.utcnow()
    record = {
        "id": session_id,
        "user_id": "demo-user",  # TODO: auth
        "started_at": session.started_at.isoformat(),
        "ended_at": None,
        "duration_seconds": None,
        "source": session.source,
        "consent_mode": session.consent_mode,
        "status": "recording",
        "environment_tag": session.environment_tag,
        "location_label": session.location_label,
        "created_at": now.isoformat(),
    }
    _sessions[session_id] = record
    _chunks[session_id] = []
    return record


@router.post("/sessions/{session_id}/chunks", response_model=AudioChunkUploadResponse)
async def upload_chunk(session_id: str, file: UploadFile = File(...)):
    """Upload an audio chunk for a session."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    # Ensure storage directory exists
    session_dir = os.path.join(settings.storage_path, session_id)
    os.makedirs(session_dir, exist_ok=True)

    chunk_index = len(_chunks[session_id])
    chunk_id = str(uuid.uuid4())
    file_path = os.path.join(session_dir, f"chunk_{chunk_index:04d}.wav")

    # Save file
    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    chunk_record = {
        "id": chunk_id,
        "session_id": session_id,
        "chunk_index": chunk_index,
        "file_path": file_path,
        "file_size_bytes": len(content),
        "duration_seconds": 0.0,  # TODO: extract from audio metadata
        "status": "pending",
        "created_at": datetime.utcnow().isoformat(),
    }
    _chunks[session_id].append(chunk_record)

    return chunk_record


@router.post("/sessions/{session_id}/finish", response_model=AudioSessionResponse)
async def finish_session(session_id: str, body: AudioSessionFinish):
    """Mark a session as finished and trigger processing."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    session = _sessions[session_id]
    session["ended_at"] = body.ended_at.isoformat()
    session["status"] = "uploaded"

    start = datetime.fromisoformat(session["started_at"])
    end = body.ended_at
    session["duration_seconds"] = (end - start).total_seconds()

    # TODO: trigger async processing via Celery/background task
    return session


@router.get("/sessions", response_model=list[AudioSessionResponse])
async def list_sessions(limit: int = 20, offset: int = 0):
    """List recording sessions for current user."""
    sessions = list(_sessions.values())
    sessions.sort(key=lambda s: s["created_at"], reverse=True)
    return sessions[offset : offset + limit]


@router.get("/sessions/{session_id}", response_model=AudioSessionResponse)
async def get_session(session_id: str):
    """Get a specific session."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    return _sessions[session_id]


@router.delete("/sessions/{session_id}")
async def delete_session(session_id: str):
    """Delete a session and its audio data (privacy)."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    # Delete audio files
    session_dir = os.path.join(settings.storage_path, session_id)
    if os.path.exists(session_dir):
        import shutil
        shutil.rmtree(session_dir)

    del _sessions[session_id]
    if session_id in _chunks:
        del _chunks[session_id]

    return {"status": "deleted"}
