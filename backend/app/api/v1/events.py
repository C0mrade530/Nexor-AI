"""Event endpoints — access extracted events, ideas, meetings, tasks."""

from datetime import datetime

from fastapi import APIRouter, HTTPException, Query

from app.core import store

router = APIRouter(prefix="/events", tags=["events"])


@router.get("")
async def list_events(
    event_type: str | None = Query(None, description="Filter by event type"),
    date_from: str | None = Query(None, description="YYYY-MM-DD"),
    date_to: str | None = Query(None, description="YYYY-MM-DD"),
    tags: str | None = Query(None, description="Comma-separated tags"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """List events with filtering."""
    events = list(store.events.values())

    if event_type:
        events = [e for e in events if e.get("event_type") == event_type]
    if date_from:
        events = [e for e in events if e.get("started_at", "") >= date_from]
    if date_to:
        events = [e for e in events if e.get("started_at", "") <= date_to + "T23:59:59"]
    if tags:
        tag_list = [t.strip() for t in tags.split(",")]
        events = [
            e for e in events
            if e.get("tags") and any(t in e["tags"] for t in tag_list)
        ]

    events.sort(key=lambda e: e.get("started_at", ""), reverse=True)
    total = len(events)
    start = (page - 1) * page_size

    return {
        "events": events[start : start + page_size],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/ideas")
async def list_ideas(
    category: str | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """List all captured ideas."""
    ideas = [e for e in store.events.values() if e.get("event_type") == "idea"]
    if category:
        ideas = [
            e for e in ideas
            if e.get("ideas") and any(
                i.get("category") == category
                for i in (e["ideas"] if isinstance(e["ideas"], list) else [])
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


@router.get("/meetings")
async def list_meetings(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """List all meetings."""
    meetings = [
        e for e in store.events.values()
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
    for event in store.events.values():
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


@router.get("/summaries/daily")
async def list_daily_summaries(limit: int = Query(7, ge=1, le=30)):
    """List recent daily summaries."""
    summaries = list(store.daily_summaries.values())
    summaries.sort(key=lambda s: s.get("date", ""), reverse=True)
    return summaries[:limit]


@router.get("/summaries/daily/{date}")
async def get_daily_summary(date: str):
    """Get daily summary for a specific date (YYYY-MM-DD)."""
    if date not in store.daily_summaries:
        raise HTTPException(status_code=404, detail="Summary not found for this date")
    return store.daily_summaries[date]


@router.get("/{event_id}")
async def get_event(event_id: str):
    """Get a specific event with full details."""
    if event_id not in store.events:
        raise HTTPException(status_code=404, detail="Event not found")
    return store.events[event_id]


@router.delete("/{event_id}")
async def delete_event(event_id: str):
    """Delete an event (privacy)."""
    if event_id not in store.events:
        raise HTTPException(status_code=404, detail="Event not found")
    del store.events[event_id]
    return {"status": "deleted"}
