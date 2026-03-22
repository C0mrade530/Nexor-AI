"""Processing trigger endpoints — kick off AI pipeline on sessions."""

import os
from datetime import datetime

from fastapi import APIRouter, HTTPException

from app.core import store
from app.core.config import settings
from app.services.processing import processing_service

router = APIRouter(prefix="/process", tags=["processing"])


@router.post("/session/{session_id}")
async def process_session(session_id: str):
    """Trigger AI processing on a finished session.

    Runs: transcription -> event segmentation -> memory indexing -> calendar sync.
    """
    session_dir = os.path.join(settings.storage_path, session_id)
    if not os.path.exists(session_dir):
        raise HTTPException(status_code=404, detail="Session audio not found")

    audio_files = sorted(
        os.path.join(session_dir, f)
        for f in os.listdir(session_dir)
        if f.endswith((".wav", ".m4a", ".mp3", ".webm", ".ogg", ".flac"))
    )

    if not audio_files:
        raise HTTPException(status_code=404, detail="No audio files found in session")

    # Get session start time from store
    session_data = store.sessions.get(session_id, {})
    started_at_str = session_data.get("started_at")
    if started_at_str:
        session_start = datetime.fromisoformat(started_at_str)
    else:
        session_start = datetime.utcnow()

    user_id = session_data.get("user_id", "demo-user")

    result = await processing_service.process_session(
        user_id=user_id,
        session_id=session_id,
        audio_paths=audio_files,
        session_start=session_start,
    )

    return {
        "session_id": session_id,
        "chunks_processed": result["chunks_processed"],
        "events_extracted": len(result["events"]),
        "events": result["events"],
        "calendar_sync": result.get("calendar_sync"),
    }


@router.post("/daily-summary")
async def generate_daily_summary(date: str | None = None):
    """Generate end-of-day summary with mentor feedback, meetings, commitments, tasks."""
    if date is None:
        date = datetime.utcnow().strftime("%Y-%m-%d")

    user_id = "demo-user"

    date_events = [
        e for e in store.events.values()
        if e.get("started_at", "").startswith(date)
    ]

    if not date_events:
        return {
            "date": date,
            "error": f"No events found for {date}. Upload and process audio first.",
            "events_count": 0,
        }

    summary = await processing_service.generate_daily_summary(user_id, date)
    return summary


@router.get("/mentor/{date}")
async def get_mentor_feedback(date: str):
    """Get AI mentor feedback for a specific date."""
    feedback = store.mentor_feedback.get(date)
    if not feedback:
        raise HTTPException(
            status_code=404,
            detail="No mentor feedback for this date. Generate daily summary first."
        )
    return feedback


@router.post("/mentor/{date}")
async def generate_mentor_feedback(date: str):
    """Generate or regenerate AI mentor feedback for a date."""
    date_events = [
        e for e in store.events.values()
        if e.get("started_at", "").startswith(date)
    ]

    if not date_events:
        raise HTTPException(status_code=404, detail="No events found for this date")

    from app.services.ai_pipeline import ai_pipeline
    mentor = await ai_pipeline.generate_mentor_feedback(date_events, date)
    store.mentor_feedback[date] = mentor
    return mentor
