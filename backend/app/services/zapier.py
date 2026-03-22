"""Zapier webhook integration — trigger external automations.

Sends webhooks when key LifeOS events happen:
- New recording processed
- Daily summary generated
- New commitment/task/follow-up extracted
- Health goal achieved
- Finance alert triggered
"""

import logging
import uuid
from datetime import datetime

import httpx

logger = logging.getLogger(__name__)

# In-memory webhook registry
webhooks: dict[str, list[dict]] = {}  # {user_id: [webhook_config, ...]}
webhook_log: dict[str, list[dict]] = {}  # {user_id: [delivery_record, ...]}


class ZapierService:
    """Manages outgoing webhooks for Zapier/Make/n8n automations."""

    TRIGGER_TYPES = [
        "recording_processed",
        "daily_summary_generated",
        "new_commitment",
        "new_task",
        "new_follow_up",
        "new_idea",
        "health_goal_achieved",
        "finance_alert",
        "mentor_feedback_ready",
    ]

    async def register_webhook(
        self,
        user_id: str,
        webhook_url: str,
        triggers: list[str],
        name: str = "",
    ) -> dict:
        """Register a webhook URL to receive events.

        triggers: list of event types from TRIGGER_TYPES.
        """
        invalid = [t for t in triggers if t not in self.TRIGGER_TYPES]
        if invalid:
            return {"error": f"Invalid triggers: {invalid}", "valid_triggers": self.TRIGGER_TYPES}

        webhook = {
            "id": str(uuid.uuid4()),
            "user_id": user_id,
            "name": name or f"Webhook {len(webhooks.get(user_id, [])) + 1}",
            "url": webhook_url,
            "triggers": triggers,
            "active": True,
            "created_at": datetime.utcnow().isoformat(),
            "deliveries": 0,
            "last_delivery": None,
        }

        webhooks.setdefault(user_id, [])
        webhooks[user_id].append(webhook)

        return webhook

    async def list_webhooks(self, user_id: str) -> list[dict]:
        return webhooks.get(user_id, [])

    async def delete_webhook(self, user_id: str, webhook_id: str) -> dict:
        if user_id in webhooks:
            webhooks[user_id] = [
                w for w in webhooks[user_id] if w["id"] != webhook_id
            ]
        return {"deleted": True}

    async def toggle_webhook(self, user_id: str, webhook_id: str, active: bool) -> dict:
        for w in webhooks.get(user_id, []):
            if w["id"] == webhook_id:
                w["active"] = active
                return w
        return {"error": "Webhook not found"}

    async def fire_trigger(
        self,
        user_id: str,
        trigger_type: str,
        payload: dict,
    ) -> dict:
        """Fire a trigger — sends payload to all matching webhooks."""
        matching = [
            w for w in webhooks.get(user_id, [])
            if trigger_type in w.get("triggers", []) and w.get("active", True)
        ]

        if not matching:
            return {"triggered": 0, "no_matching_webhooks": True}

        envelope = {
            "trigger": trigger_type,
            "user_id": user_id,
            "timestamp": datetime.utcnow().isoformat(),
            "data": payload,
        }

        results = []
        for webhook in matching:
            delivery = await self._deliver(webhook, envelope)
            results.append(delivery)

        return {
            "triggered": len(results),
            "deliveries": results,
        }

    async def _deliver(self, webhook: dict, payload: dict) -> dict:
        """Deliver a webhook payload via HTTP POST."""
        delivery = {
            "id": str(uuid.uuid4()),
            "webhook_id": webhook["id"],
            "webhook_name": webhook.get("name", ""),
            "trigger": payload.get("trigger", ""),
            "attempted_at": datetime.utcnow().isoformat(),
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    webhook["url"],
                    json=payload,
                    headers={"Content-Type": "application/json"},
                )
                delivery["status_code"] = response.status_code
                delivery["success"] = 200 <= response.status_code < 300
        except Exception as e:
            delivery["success"] = False
            delivery["error"] = str(e)
            logger.error(f"Webhook delivery failed for {webhook['id']}: {e}")

        # Update webhook stats
        webhook["deliveries"] = webhook.get("deliveries", 0) + 1
        webhook["last_delivery"] = delivery["attempted_at"]

        # Store log
        user_id = webhook.get("user_id", "")
        webhook_log.setdefault(user_id, [])
        webhook_log[user_id].append(delivery)

        return delivery

    async def get_delivery_log(
        self, user_id: str, webhook_id: str | None = None, limit: int = 50
    ) -> list[dict]:
        log = webhook_log.get(user_id, [])
        if webhook_id:
            log = [l for l in log if l["webhook_id"] == webhook_id]
        return sorted(log, key=lambda l: l["attempted_at"], reverse=True)[:limit]


zapier_service = ZapierService()
