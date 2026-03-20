"""Processing trigger endpoints — kick off AI pipeline on sessions."""

import os
from datetime import datetime

from fastapi import APIRouter, HTTPException

from app.core.config import settings
from app.services.processing import processing_service

router = APIRouter(prefix="/process", tags=["processing"])


@router.post("/session/{session_id}")
async def process_session(session_id: str):
    """Trigger AI processing on a finished session.

    Runs: transcription → event segmentation → memory indexing.
    """
    # Find audio files for the session
    session_dir = os.path.join(settings.storage_path, session_id)
    if not os.path.exists(session_dir):
        raise HTTPException(status_code=404, detail="Session audio not found")

    audio_files = sorted(
        [
            os.path.join(session_dir, f)
            for f in os.listdir(session_dir)
            if f.endswith((".wav", ".m4a", ".mp3", ".webm", ".ogg"))
        ]
    )

    if not audio_files:
        raise HTTPException(status_code=404, detail="No audio files found in session")

    user_id = "demo-user"  # TODO: auth
    result = await processing_service.process_session(
        user_id=user_id,
        session_id=session_id,
        audio_paths=audio_files,
        session_start=datetime.utcnow(),  # TODO: from session record
    )

    return {
        "session_id": session_id,
        "chunks_processed": result["chunks_processed"],
        "events_extracted": len(result["events"]),
        "events": result["events"],
    }


@router.post("/daily-summary")
async def generate_daily_summary(date: str | None = None):
    """Generate daily summary for a given date (default: today)."""
    if date is None:
        date = datetime.utcnow().strftime("%Y-%m-%d")

    user_id = "demo-user"  # TODO: auth

    # TODO: fetch events from DB for this date
    # For now, return placeholder
    return {
        "date": date,
        "status": "Daily summary generation requires processed events. "
        "Upload and process audio sessions first.",
    }
