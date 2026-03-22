"""Telegram bot endpoints — webhook receiver, settings, manual triggers."""

from fastapi import APIRouter, Request
from pydantic import BaseModel

from app.services.telegram_bot import telegram_service, telegram_users, telegram_settings

router = APIRouter(prefix="/telegram", tags=["telegram"])


class TelegramLinkRequest(BaseModel):
    user_id: str = "demo-user"
    chat_id: int


class TelegramSettingsRequest(BaseModel):
    user_id: str = "demo-user"
    enabled: bool | None = None
    reminders: bool | None = None
    daily_summary: bool | None = None
    voice_processing: bool | None = None


@router.post("/webhook")
async def telegram_webhook(request: Request):
    """Receive Telegram Bot API updates (set this URL as webhook).

    Set webhook via: https://api.telegram.org/bot<TOKEN>/setWebhook?url=<YOUR_SERVER>/api/v1/telegram/webhook
    """
    update = await request.json()
    result = await telegram_service.handle_update(update)
    return result


@router.get("/status")
async def telegram_status(user_id: str = "demo-user"):
    """Check if Telegram bot is connected for this user."""
    settings = telegram_settings.get(user_id)
    return {
        "configured": telegram_service.is_configured,
        "linked": settings is not None,
        "chat_id": settings.get("chat_id") if settings else None,
        "enabled": settings.get("enabled", False) if settings else False,
    }


@router.post("/link")
async def link_telegram(req: TelegramLinkRequest):
    """Manually link a Telegram chat to a Nexor user."""
    telegram_users[req.chat_id] = req.user_id
    telegram_settings[req.user_id] = {
        "chat_id": req.chat_id,
        "enabled": True,
        "reminders": True,
        "daily_summary": True,
        "voice_processing": True,
    }
    return {"linked": True, "user_id": req.user_id, "chat_id": req.chat_id}


@router.delete("/unlink")
async def unlink_telegram(user_id: str = "demo-user"):
    """Unlink Telegram from Nexor user."""
    settings = telegram_settings.pop(user_id, None)
    if settings:
        telegram_users.pop(settings.get("chat_id", 0), None)
    return {"unlinked": True}


@router.post("/settings")
async def update_telegram_settings(req: TelegramSettingsRequest):
    """Update Telegram notification preferences."""
    current = telegram_settings.get(req.user_id, {})
    updates = req.model_dump(exclude={"user_id"}, exclude_none=True)
    current.update(updates)
    telegram_settings[req.user_id] = current
    return current


@router.post("/send-summary")
async def send_summary_to_telegram(user_id: str = "demo-user"):
    """Manually trigger daily summary push to Telegram."""
    return await telegram_service.send_daily_summary_notification(user_id)


@router.post("/send-reminders")
async def send_reminders_to_telegram(user_id: str = "demo-user"):
    """Manually trigger commitment/follow-up reminders via Telegram."""
    return await telegram_service.send_commitment_reminders(user_id)


@router.post("/send")
async def send_message_to_telegram(user_id: str = "demo-user", text: str = ""):
    """Send a custom message to user's Telegram."""
    settings = telegram_settings.get(user_id)
    if not settings:
        return {"sent": False, "reason": "not_linked"}

    result = await telegram_service.send_message(settings["chat_id"], text)
    return {"sent": True, "result": result}
