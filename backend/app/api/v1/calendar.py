"""Google Calendar integration endpoints."""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.core import store
from app.services.calendar_sync import calendar_service

router = APIRouter(prefix="/calendar", tags=["calendar"])


class CalendarTokenRequest(BaseModel):
    access_token: str
    refresh_token: str | None = None
    user_id: str = "demo-user"


class CalendarSyncRequest(BaseModel):
    date: str | None = None
    user_id: str = "demo-user"


@router.post("/connect")
async def connect_calendar(req: CalendarTokenRequest):
    """Store Google Calendar OAuth token for auto-sync."""
    store.calendar_tokens[req.user_id] = {
        "access_token": req.access_token,
        "refresh_token": req.refresh_token,
    }
    return {"status": "connected", "user_id": req.user_id}


@router.delete("/disconnect")
async def disconnect_calendar(user_id: str = "demo-user"):
    """Remove Google Calendar integration."""
    store.calendar_tokens.pop(user_id, None)
    return {"status": "disconnected"}


@router.get("/status")
async def calendar_status(user_id: str = "demo-user"):
    """Check if Google Calendar is connected."""
    token_data = store.calendar_tokens.get(user_id)
    return {
        "connected": bool(token_data and token_data.get("access_token")),
        "user_id": user_id,
    }


@router.post("/sync/meetings")
async def sync_meetings_to_calendar(req: CalendarSyncRequest):
    """Manually sync all meetings with calendar suggestions to Google Calendar."""
    token_data = store.calendar_tokens.get(req.user_id)
    if not token_data or not token_data.get("access_token"):
        raise HTTPException(status_code=401, detail="Google Calendar not connected")

    events = list(store.events.values())
    if req.date:
        events = [e for e in events if e.get("started_at", "").startswith(req.date)]

    meetings = [e for e in events if e.get("suggested_calendar_event")]
    if not meetings:
        return {"synced": [], "failed": [], "message": "No meetings to sync"}

    result = await calendar_service.sync_events_to_calendar(
        access_token=token_data["access_token"],
        events=meetings,
    )
    return result


@router.post("/sync/tasks")
async def sync_tasks_to_calendar(req: CalendarSyncRequest):
    """Sync all action items to Google Tasks."""
    token_data = store.calendar_tokens.get(req.user_id)
    if not token_data or not token_data.get("access_token"):
        raise HTTPException(status_code=401, detail="Google Calendar not connected")

    # Collect all action items from events
    tasks = []
    events = list(store.events.values())
    if req.date:
        events = [e for e in events if e.get("started_at", "").startswith(req.date)]

    for event in events:
        for item in event.get("action_items", []):
            tasks.append({
                "task": item.get("task", ""),
                "deadline": item.get("deadline"),
                "event_title": event.get("title", ""),
            })

    if not tasks:
        return {"synced": [], "failed": [], "message": "No tasks to sync"}

    result = await calendar_service.sync_tasks_to_google(
        access_token=token_data["access_token"],
        tasks=tasks,
    )
    return result
