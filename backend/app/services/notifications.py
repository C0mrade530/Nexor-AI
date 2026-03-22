"""Push notifications service — APNs integration for LifeOS.

Sends reminders for:
- Daily summary generation ("Your day is ready for review")
- Commitment deadlines ("You promised X to Y by tomorrow")
- Follow-up reminders ("Time to follow up with Z")
- Health coaching ("You haven't moved in 2 hours")
- Financial alerts ("Unusual spending detected")
"""

import json
import logging
import uuid
from datetime import datetime

from app.core import store

logger = logging.getLogger(__name__)

# In-memory notification stores
device_tokens: dict[str, list[str]] = {}  # {user_id: [apns_device_token, ...]}
notification_preferences: dict[str, dict] = {}  # {user_id: {preferences}}
notification_history: dict[str, list[dict]] = {}  # {user_id: [notification, ...]}
scheduled_notifications: list[dict] = []  # Pending notifications


class NotificationService:
    """Manages push notifications via APNs."""

    async def register_device(self, user_id: str, device_token: str, platform: str = "ios") -> dict:
        """Register a device for push notifications."""
        device_tokens.setdefault(user_id, [])
        if device_token not in device_tokens[user_id]:
            device_tokens[user_id].append(device_token)

        return {"registered": True, "devices": len(device_tokens[user_id])}

    async def unregister_device(self, user_id: str, device_token: str) -> dict:
        """Remove a device from push notifications."""
        if user_id in device_tokens:
            device_tokens[user_id] = [
                t for t in device_tokens[user_id] if t != device_token
            ]
        return {"unregistered": True}

    async def set_preferences(self, user_id: str, prefs: dict) -> dict:
        """Set notification preferences.

        {
            "daily_summary_reminder": true,
            "daily_summary_time": "21:00",
            "commitment_reminders": true,
            "follow_up_reminders": true,
            "health_nudges": true,
            "finance_alerts": true,
            "quiet_hours_start": "23:00",
            "quiet_hours_end": "07:00"
        }
        """
        notification_preferences[user_id] = {
            "user_id": user_id,
            "updated_at": datetime.utcnow().isoformat(),
            **prefs,
        }
        return notification_preferences[user_id]

    async def get_preferences(self, user_id: str) -> dict:
        return notification_preferences.get(user_id, {
            "daily_summary_reminder": True,
            "daily_summary_time": "21:00",
            "commitment_reminders": True,
            "follow_up_reminders": True,
            "health_nudges": True,
            "finance_alerts": True,
            "quiet_hours_start": "23:00",
            "quiet_hours_end": "07:00",
        })

    async def send_notification(
        self,
        user_id: str,
        title: str,
        body: str,
        category: str = "general",
        data: dict | None = None,
    ) -> dict:
        """Send a push notification to user's devices.

        In production, this would use APNs (Apple Push Notification Service).
        For now, we log and store it.
        """
        tokens = device_tokens.get(user_id, [])

        notification = {
            "id": str(uuid.uuid4()),
            "user_id": user_id,
            "title": title,
            "body": body,
            "category": category,
            "data": data or {},
            "sent_at": datetime.utcnow().isoformat(),
            "devices_targeted": len(tokens),
            "delivered": len(tokens) > 0,
        }

        # Store in history
        notification_history.setdefault(user_id, [])
        notification_history[user_id].append(notification)

        if tokens:
            # In production: send via APNs
            logger.info(
                f"PUSH [{category}] -> {user_id} ({len(tokens)} devices): "
                f"{title} — {body}"
            )
        else:
            logger.info(f"PUSH [{category}] -> {user_id} (no devices registered): {title}")

        return notification

    async def get_history(self, user_id: str, limit: int = 50) -> list[dict]:
        """Get notification history."""
        history = notification_history.get(user_id, [])
        return sorted(history, key=lambda n: n["sent_at"], reverse=True)[:limit]

    async def check_and_send_reminders(self, user_id: str) -> dict:
        """Check for pending reminders and send notifications.

        Called periodically or on app background refresh.
        """
        sent = []
        now = datetime.utcnow()
        today = now.strftime("%Y-%m-%d")

        # 1. Check for commitments with approaching deadlines
        for event in store.events.values():
            for commitment in event.get("commitments", []):
                deadline = commitment.get("deadline", "")
                if deadline and deadline.startswith(today):
                    notif = await self.send_notification(
                        user_id=user_id,
                        title="Commitment Reminder",
                        body=f"You promised: {commitment.get('promise', '')}",
                        category="commitment",
                        data={"event_id": event.get("id")},
                    )
                    sent.append(notif)

        # 2. Check for follow-ups
        for event in store.events.values():
            for follow_up in event.get("follow_ups", []):
                by_when = follow_up.get("by_when", "")
                if by_when and by_when.startswith(today):
                    notif = await self.send_notification(
                        user_id=user_id,
                        title="Follow-up Reminder",
                        body=f"Follow up: {follow_up.get('action', '')}",
                        category="follow_up",
                        data={"event_id": event.get("id")},
                    )
                    sent.append(notif)

        # 3. Daily summary reminder (check if summary exists for today)
        prefs = await self.get_preferences(user_id)
        if prefs.get("daily_summary_reminder"):
            if today not in store.daily_summaries:
                if now.hour >= 20:  # After 8 PM
                    notif = await self.send_notification(
                        user_id=user_id,
                        title="Your day is ready for review",
                        body="Generate your daily summary to capture today's insights",
                        category="daily_summary",
                    )
                    sent.append(notif)

        return {"reminders_sent": len(sent), "notifications": sent}

    async def schedule_notification(
        self,
        user_id: str,
        title: str,
        body: str,
        send_at: str,
        category: str = "scheduled",
    ) -> dict:
        """Schedule a notification for future delivery."""
        scheduled = {
            "id": str(uuid.uuid4()),
            "user_id": user_id,
            "title": title,
            "body": body,
            "category": category,
            "send_at": send_at,
            "created_at": datetime.utcnow().isoformat(),
            "status": "pending",
        }
        scheduled_notifications.append(scheduled)
        return scheduled


notification_service = NotificationService()
