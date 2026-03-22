"""Google Calendar integration — auto-sync meetings and tasks.

Handles OAuth2 flow, event creation, and task list management.
"""

import logging
from datetime import datetime, timedelta

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

GOOGLE_CALENDAR_API = "https://www.googleapis.com/calendar/v3"
GOOGLE_TASKS_API = "https://tasks.googleapis.com/tasks/v1"


class CalendarSyncService:
    """Syncs Nexor events to Google Calendar and Tasks."""

    async def create_calendar_event(
        self,
        access_token: str,
        title: str,
        start_time: str,
        end_time: str | None = None,
        description: str = "",
        participants: list[str] | None = None,
        reminder_minutes: int = 15,
        calendar_id: str = "primary",
    ) -> dict:
        """Create an event in Google Calendar."""
        # Parse start time
        try:
            start_dt = datetime.fromisoformat(start_time)
        except (ValueError, TypeError):
            start_dt = datetime.utcnow() + timedelta(hours=1)

        if end_time:
            try:
                end_dt = datetime.fromisoformat(end_time)
            except (ValueError, TypeError):
                end_dt = start_dt + timedelta(hours=1)
        else:
            end_dt = start_dt + timedelta(hours=1)

        event_body = {
            "summary": title,
            "description": description,
            "start": {
                "dateTime": start_dt.isoformat(),
                "timeZone": "UTC",
            },
            "end": {
                "dateTime": end_dt.isoformat(),
                "timeZone": "UTC",
            },
            "reminders": {
                "useDefault": False,
                "overrides": [
                    {"method": "popup", "minutes": reminder_minutes},
                ],
            },
        }

        if participants:
            event_body["attendees"] = [
                {"email": p} if "@" in p else {"displayName": p}
                for p in participants
            ]

        url = f"{GOOGLE_CALENDAR_API}/calendars/{calendar_id}/events"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, json=event_body, headers=headers)
            response.raise_for_status()
            result = response.json()

        logger.info(f"Created calendar event: {result.get('id')} — {title}")
        return result

    async def create_task(
        self,
        access_token: str,
        title: str,
        notes: str = "",
        due_date: str | None = None,
        task_list_id: str = "@default",
    ) -> dict:
        """Create a task in Google Tasks."""
        task_body = {
            "title": title,
            "notes": notes,
        }

        if due_date:
            try:
                dt = datetime.fromisoformat(due_date)
                task_body["due"] = dt.strftime("%Y-%m-%dT00:00:00.000Z")
            except (ValueError, TypeError):
                pass

        url = f"{GOOGLE_TASKS_API}/lists/{task_list_id}/tasks"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, json=task_body, headers=headers)
            response.raise_for_status()
            result = response.json()

        logger.info(f"Created task: {result.get('id')} — {title}")
        return result

    async def sync_events_to_calendar(
        self,
        access_token: str,
        events: list[dict],
    ) -> dict:
        """Sync all meetings with calendar suggestions to Google Calendar."""
        synced = []
        failed = []

        for event in events:
            cal = event.get("suggested_calendar_event")
            if not cal:
                continue

            try:
                participants = cal.get("participants", [])
                if not participants:
                    participants = event.get("participants", [])

                result = await self.create_calendar_event(
                    access_token=access_token,
                    title=cal.get("title", event.get("title", "Meeting")),
                    start_time=cal.get("datetime_str", ""),
                    description=event.get("summary", ""),
                    participants=participants,
                    reminder_minutes=cal.get("reminder_minutes", 15),
                )
                synced.append({
                    "event_id": event.get("id"),
                    "calendar_event_id": result.get("id"),
                    "title": cal.get("title"),
                })
            except Exception as e:
                logger.error(f"Failed to sync event {event.get('id')}: {e}")
                failed.append({
                    "event_id": event.get("id"),
                    "title": cal.get("title"),
                    "error": str(e),
                })

        return {"synced": synced, "failed": failed}

    async def sync_tasks_to_google(
        self,
        access_token: str,
        tasks: list[dict],
    ) -> dict:
        """Sync all action items to Google Tasks."""
        synced = []
        failed = []

        for task in tasks:
            try:
                result = await self.create_task(
                    access_token=access_token,
                    title=task.get("task", task.get("title", "")),
                    notes=f"From: {task.get('event_title', task.get('source_event', ''))}",
                    due_date=task.get("deadline"),
                )
                synced.append({
                    "task_title": task.get("task", task.get("title", "")),
                    "google_task_id": result.get("id"),
                })
            except Exception as e:
                logger.error(f"Failed to sync task: {e}")
                failed.append({
                    "task_title": task.get("task", task.get("title", "")),
                    "error": str(e),
                })

        return {"synced": synced, "failed": failed}

    async def get_or_create_nexor_tasklist(
        self, access_token: str
    ) -> str:
        """Get or create a Nexor task list in Google Tasks."""
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            # List existing task lists
            response = await client.get(
                f"{GOOGLE_TASKS_API}/users/@me/lists",
                headers=headers,
            )
            response.raise_for_status()
            lists = response.json().get("items", [])

            for tl in lists:
                if tl.get("title") == "Nexor":
                    return tl["id"]

            # Create new list
            response = await client.post(
                f"{GOOGLE_TASKS_API}/users/@me/lists",
                json={"title": "Nexor"},
                headers=headers,
            )
            response.raise_for_status()
            return response.json()["id"]


calendar_service = CalendarSyncService()
