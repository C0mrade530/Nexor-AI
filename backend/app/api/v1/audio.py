"""Audio upload and session management endpoints."""

import os
import uuid
from datetime import datetime

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.core import store
from app.core.config import settings
from app.schemas.audio import AudioSessionCreate, AudioSessionFinish

router = APIRouter(prefix="/audio", tags=["audio"])


@router.post("/sessions")
async def create_session(session: AudioSessionCreate):
    """Start a new audio recording session."""
    session_id = str(uuid.uuid4())
    now = datetime.utcnow()
    record = {
        "id": session_id,
        "user_id": "demo-user",
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
    store.sessions[session_id] = record
    store.chunks[session_id] = []
    return record


@router.post("/sessions/{session_id}/chunks")
async def upload_chunk(session_id: str, file: UploadFile = File(...)):
    """Upload an audio chunk for a session."""
    if session_id not in store.sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    session_dir = os.path.join(settings.storage_path, session_id)
    os.makedirs(session_dir, exist_ok=True)

    chunk_index = len(store.chunks[session_id])
    chunk_id = str(uuid.uuid4())
    file_path = os.path.join(session_dir, f"chunk_{chunk_index:04d}.wav")

    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    chunk_record = {
        "id": chunk_id,
        "session_id": session_id,
        "chunk_index": chunk_index,
        "file_path": file_path,
        "file_size_bytes": len(content),
        "duration_seconds": 0.0,
        "status": "pending",
        "created_at": datetime.utcnow().isoformat(),
    }
    store.chunks[session_id].append(chunk_record)
    return chunk_record


@router.post("/sessions/{session_id}/finish")
async def finish_session(session_id: str, body: AudioSessionFinish):
    """Mark a session as finished and trigger processing."""
    if session_id not in store.sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    session = store.sessions[session_id]
    session["ended_at"] = body.ended_at.isoformat()
    session["status"] = "uploaded"

    start = datetime.fromisoformat(session["started_at"])
    session["duration_seconds"] = (body.ended_at - start).total_seconds()
    return session


@router.get("/sessions")
async def list_sessions(limit: int = 20, offset: int = 0):
    """List recording sessions for current user."""
    sessions = list(store.sessions.values())
    sessions.sort(key=lambda s: s["created_at"], reverse=True)
    return sessions[offset : offset + limit]


@router.get("/sessions/{session_id}")
async def get_session(session_id: str):
    """Get a specific session."""
    if session_id not in store.sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    return store.sessions[session_id]


@router.delete("/sessions/{session_id}")
async def delete_session(session_id: str):
    """Delete a session and its audio data (privacy)."""
    if session_id not in store.sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    session_dir = os.path.join(settings.storage_path, session_id)
    if os.path.exists(session_dir):
        import shutil
        shutil.rmtree(session_dir)

    del store.sessions[session_id]
    store.chunks.pop(session_id, None)
    return {"status": "deleted"}
