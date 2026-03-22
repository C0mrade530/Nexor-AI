"""Plaud NotePin integration endpoints — sync recordings from Plaud device."""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.core import store
from app.services.plaud_sync import plaud_service
from app.services.processing import processing_service

router = APIRouter(prefix="/plaud", tags=["plaud"])


class PlaudConnectRequest(BaseModel):
    token: str
    region: str = "us"  # "us" or "eu"
    user_id: str = "demo-user"


class PlaudSyncRequest(BaseModel):
    user_id: str = "demo-user"


class PlaudSyncOneRequest(BaseModel):
    file_id: str
    auto_process: bool = True
    user_id: str = "demo-user"


@router.post("/connect")
async def connect_plaud(req: PlaudConnectRequest):
    """Connect Plaud NotePin by providing Bearer token from plaud.ai.

    How to get token:
    1. Log into web.plaud.ai
    2. Open DevTools (F12) → Network tab
    3. Refresh page, find request to api.plaud.ai
    4. Copy Authorization header value (without 'Bearer ' prefix)
    """
    # Test connection
    result = await plaud_service.test_connection(req.token, req.region)
    if not result["connected"]:
        raise HTTPException(
            status_code=401,
            detail=f"Failed to connect to Plaud: {result.get('error', 'Invalid token')}"
        )

    # Store token
    store.calendar_tokens.setdefault(req.user_id, {})
    store.calendar_tokens[req.user_id]["plaud_token"] = req.token
    store.calendar_tokens[req.user_id]["plaud_region"] = req.region

    return {"status": "connected", "message": "Plaud NotePin connected successfully"}


@router.delete("/disconnect")
async def disconnect_plaud(user_id: str = "demo-user"):
    """Disconnect Plaud NotePin integration."""
    if user_id in store.calendar_tokens:
        store.calendar_tokens[user_id].pop("plaud_token", None)
        store.calendar_tokens[user_id].pop("plaud_region", None)
    return {"status": "disconnected"}


@router.get("/status")
async def plaud_status(user_id: str = "demo-user"):
    """Check Plaud NotePin connection status."""
    tokens = store.calendar_tokens.get(user_id, {})
    connected = bool(tokens.get("plaud_token"))
    return {
        "connected": connected,
        "region": tokens.get("plaud_region", "us") if connected else None,
    }


@router.get("/recordings")
async def list_plaud_recordings(user_id: str = "demo-user", limit: int = 50):
    """List available recordings from connected Plaud device."""
    tokens = store.calendar_tokens.get(user_id, {})
    token = tokens.get("plaud_token")
    if not token:
        raise HTTPException(status_code=401, detail="Plaud not connected")

    region = tokens.get("plaud_region", "us")
    recordings = await plaud_service.list_recordings(token, region=region, limit=limit)

    # Mark which ones are already synced
    synced_ids = {
        s.get("plaud_file_id")
        for s in store.sessions.values()
        if s.get("source") == "plaud_notepin"
    }

    for rec in recordings:
        rec["synced"] = rec["id"] in synced_ids

    return {"recordings": recordings, "total": len(recordings)}


@router.post("/sync")
async def sync_all_recordings(req: PlaudSyncRequest):
    """Sync all new recordings from Plaud NotePin.

    Downloads audio files that haven't been synced yet.
    """
    tokens = store.calendar_tokens.get(req.user_id, {})
    token = tokens.get("plaud_token")
    if not token:
        raise HTTPException(status_code=401, detail="Plaud not connected")

    region = tokens.get("plaud_region", "us")
    result = await plaud_service.sync_all_new(
        token=token,
        user_id=req.user_id,
        region=region,
    )

    return result


@router.post("/sync/one")
async def sync_one_recording(req: PlaudSyncOneRequest):
    """Sync a specific Plaud recording and optionally process it.

    Flow: Download audio → Save → (optional) Transcribe + AI Pipeline.
    """
    tokens = store.calendar_tokens.get(req.user_id, {})
    token = tokens.get("plaud_token")
    if not token:
        raise HTTPException(status_code=401, detail="Plaud not connected")

    region = tokens.get("plaud_region", "us")

    # Sync recording
    sync_result = await plaud_service.sync_recording(
        token=token,
        file_id=req.file_id,
        user_id=req.user_id,
        region=region,
    )

    # Auto-process if requested
    if req.auto_process:
        import os
        session_id = sync_result["session_id"]
        session_dir = os.path.join("./audio_storage", session_id)

        audio_files = sorted(
            os.path.join(session_dir, f)
            for f in os.listdir(session_dir)
            if f.endswith((".opus", ".mp3", ".wav", ".m4a", ".webm", ".ogg", ".flac"))
        )

        if audio_files:
            from datetime import datetime
            process_result = await processing_service.process_session(
                user_id=req.user_id,
                session_id=session_id,
                audio_paths=audio_files,
                session_start=datetime.utcnow(),
            )
            sync_result["processing"] = {
                "events_extracted": len(process_result.get("events", [])),
                "chunks_processed": process_result.get("chunks_processed", 0),
            }

    return sync_result


@router.post("/sync-and-process")
async def sync_and_process_all(req: PlaudSyncRequest):
    """One-button sync: Download all new Plaud recordings and run AI pipeline.

    This is the main endpoint for the "sync from Plaud" button in the app.
    """
    tokens = store.calendar_tokens.get(req.user_id, {})
    token = tokens.get("plaud_token")
    if not token:
        raise HTTPException(status_code=401, detail="Plaud not connected")

    region = tokens.get("plaud_region", "us")

    # Step 1: Sync all new recordings
    sync_result = await plaud_service.sync_all_new(
        token=token,
        user_id=req.user_id,
        region=region,
    )

    # Step 2: Process each synced session
    processed = []
    for session in sync_result.get("synced_sessions", []):
        session_id = session["session_id"]
        try:
            import os
            from datetime import datetime

            session_dir = os.path.join("./audio_storage", session_id)
            audio_files = sorted(
                os.path.join(session_dir, f)
                for f in os.listdir(session_dir)
                if f.endswith((".opus", ".mp3", ".wav", ".m4a", ".webm", ".ogg", ".flac"))
            )

            if audio_files:
                result = await processing_service.process_session(
                    user_id=req.user_id,
                    session_id=session_id,
                    audio_paths=audio_files,
                    session_start=datetime.utcnow(),
                )
                processed.append({
                    "session_id": session_id,
                    "events_extracted": len(result.get("events", [])),
                })
        except Exception as e:
            processed.append({
                "session_id": session_id,
                "error": str(e),
            })

    sync_result["processed"] = processed
    return sync_result
