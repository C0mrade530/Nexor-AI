"""Event endpoints — access extracted events, ideas, meetings, tasks."""

import uuid
from datetime import datetime

from fastapi import APIRouter, HTTPException, Query

from app.schemas.event import DailySummaryResponse, EventListResponse, EventResponse

router = APIRouter(prefix="/events", tags=["events"])

# In-memory store for MVP
_events: dict[str, dict] = {}
_daily_summaries: dict[str, dict] = {}


@router.get("", response_model=EventListResponse)
async def list_events(
    event_type: str | None = Query(None, description="Filter by event type"),
    date_from: datetime | None = Query(None),
    date_to: datetime | None = Query(None),
    tags: str | None = Query(None, description="Comma-separated tags"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """List events with filtering."""
    events = list(_events.values())

    if event_type:
        events = [e for e in events if e.get("event_type") == event_type]
    if tags:
        tag_list = [t.strip() for t in tags.split(",")]
        events = [
            e for e in events
            if e.get("tags") and any(t in e["tags"] for t in tag_list)
        ]

    events.sort(key=lambda e: e.get("started_at", ""), reverse=True)
    total = len(events)
    start = (page - 1) * page_size
    page_events = events[start : start + page_size]

    return {
        "events": page_events,
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/ideas", response_model=EventListResponse)
async def list_ideas(
    category: str | None = Query(None, description="content | startup | sales | personal | product"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """List all captured ideas."""
    ideas = [e for e in _events.values() if e.get("event_type") == "idea"]
    if category:
        ideas = [
            e for e in ideas
            if e.get("ideas") and any(
                i.get("category") == category for i in (e["ideas"] if isinstance(e["ideas"], list) else [])
            )
        ]

    ideas.sort(key=lambda e: e.get("started_at", ""), reverse=True)
    total = len(ideas)
    start = (page - 1) * page_size

    return {
        "events": ideas[start : start + page_size],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/meetings", response_model=EventListResponse)
async def list_meetings(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """List all meetings with intelligence."""
    meetings = [
        e for e in _events.values()
        if e.get("event_type") in ("meeting", "sales_call")
    ]
    meetings.sort(key=lambda e: e.get("started_at", ""), reverse=True)
    total = len(meetings)
    start = (page - 1) * page_size

    return {
        "events": meetings[start : start + page_size],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/tasks")
async def list_action_items():
    """Extract all action items across events."""
    items = []
    for event in _events.values():
        if event.get("action_items"):
            for item in event["action_items"]:
                items.append({
                    "event_id": event["id"],
                    "event_title": event.get("title", ""),
                    "task": item.get("task", ""),
                    "assignee": item.get("assignee"),
                    "deadline": item.get("deadline"),
                    "event_date": event.get("started_at"),
                })
    return {"action_items": items, "total": len(items)}


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(event_id: str):
    """Get a specific event with full details."""
    if event_id not in _events:
        raise HTTPException(status_code=404, detail="Event not found")
    return _events[event_id]


@router.delete("/{event_id}")
async def delete_event(event_id: str):
    """Delete an event (privacy)."""
    if event_id not in _events:
        raise HTTPException(status_code=404, detail="Event not found")
    del _events[event_id]
    return {"status": "deleted"}


@router.get("/summaries/daily", response_model=list[DailySummaryResponse])
async def list_daily_summaries(limit: int = Query(7, ge=1, le=30)):
    """List recent daily summaries."""
    summaries = list(_daily_summaries.values())
    summaries.sort(key=lambda s: s.get("date", ""), reverse=True)
    return summaries[:limit]


@router.get("/summaries/daily/{date}", response_model=DailySummaryResponse)
async def get_daily_summary(date: str):
    """Get daily summary for a specific date (YYYY-MM-DD)."""
    if date not in _daily_summaries:
        raise HTTPException(status_code=404, detail="Summary not found for this date")
    return _daily_summaries[date]
