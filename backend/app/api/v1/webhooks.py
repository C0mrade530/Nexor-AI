"""Zapier / webhook integration endpoints — outgoing automation triggers."""

from fastapi import APIRouter
from pydantic import BaseModel

from app.services.zapier import zapier_service

router = APIRouter(prefix="/webhooks", tags=["webhooks"])


class WebhookRegisterRequest(BaseModel):
    user_id: str = "demo-user"
    webhook_url: str
    triggers: list[str]
    name: str = ""


class WebhookToggleRequest(BaseModel):
    user_id: str = "demo-user"
    webhook_id: str
    active: bool


@router.get("/triggers")
async def list_trigger_types():
    """List all available webhook trigger types."""
    return {"triggers": zapier_service.TRIGGER_TYPES}


@router.post("/register")
async def register_webhook(req: WebhookRegisterRequest):
    """Register a webhook URL to receive LifeOS events.

    Works with Zapier, Make (Integromat), n8n, or any webhook receiver.
    """
    return await zapier_service.register_webhook(
        req.user_id, req.webhook_url, req.triggers, req.name
    )


@router.get("/list")
async def list_webhooks(user_id: str = "demo-user"):
    """List all registered webhooks."""
    hooks = await zapier_service.list_webhooks(user_id)
    return {"webhooks": hooks, "total": len(hooks)}


@router.delete("/{webhook_id}")
async def delete_webhook(webhook_id: str, user_id: str = "demo-user"):
    """Delete a webhook."""
    return await zapier_service.delete_webhook(user_id, webhook_id)


@router.post("/toggle")
async def toggle_webhook(req: WebhookToggleRequest):
    """Enable or disable a webhook."""
    return await zapier_service.toggle_webhook(req.user_id, req.webhook_id, req.active)


@router.get("/log")
async def get_delivery_log(
    user_id: str = "demo-user",
    webhook_id: str | None = None,
    limit: int = 50,
):
    """Get webhook delivery log."""
    log = await zapier_service.get_delivery_log(user_id, webhook_id=webhook_id, limit=limit)
    return {"deliveries": log, "total": len(log)}
