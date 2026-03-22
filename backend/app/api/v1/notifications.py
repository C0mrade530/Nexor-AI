"""Push notifications endpoints — device registration, preferences, reminders."""

from fastapi import APIRouter
from pydantic import BaseModel

from app.services.notifications import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])


class DeviceRegisterRequest(BaseModel):
    user_id: str = "demo-user"
    device_token: str
    platform: str = "ios"


class NotificationPrefsRequest(BaseModel):
    user_id: str = "demo-user"
    daily_summary_reminder: bool | None = None
    daily_summary_time: str | None = None
    commitment_reminders: bool | None = None
    follow_up_reminders: bool | None = None
    health_nudges: bool | None = None
    finance_alerts: bool | None = None
    quiet_hours_start: str | None = None
    quiet_hours_end: str | None = None


class SendNotificationRequest(BaseModel):
    user_id: str = "demo-user"
    title: str
    body: str
    category: str = "general"


class ScheduleNotificationRequest(BaseModel):
    user_id: str = "demo-user"
    title: str
    body: str
    send_at: str
    category: str = "scheduled"


@router.post("/register")
async def register_device(req: DeviceRegisterRequest):
    """Register device for push notifications (APNs token)."""
    return await notification_service.register_device(req.user_id, req.device_token, req.platform)


@router.delete("/unregister")
async def unregister_device(user_id: str = "demo-user", device_token: str = ""):
    """Unregister device from push notifications."""
    return await notification_service.unregister_device(user_id, device_token)


@router.post("/preferences")
async def set_preferences(req: NotificationPrefsRequest):
    """Set notification preferences (quiet hours, reminder types)."""
    prefs = req.model_dump(exclude={"user_id"}, exclude_none=True)
    return await notification_service.set_preferences(req.user_id, prefs)


@router.get("/preferences")
async def get_preferences(user_id: str = "demo-user"):
    """Get notification preferences."""
    return await notification_service.get_preferences(user_id)


@router.post("/send")
async def send_notification(req: SendNotificationRequest):
    """Send a push notification (for testing or manual triggers)."""
    return await notification_service.send_notification(
        req.user_id, req.title, req.body, req.category
    )


@router.post("/check-reminders")
async def check_reminders(user_id: str = "demo-user"):
    """Check and send pending reminders (commitments, follow-ups, daily summary)."""
    return await notification_service.check_and_send_reminders(user_id)


@router.get("/history")
async def get_notification_history(user_id: str = "demo-user", limit: int = 50):
    """Get notification history."""
    history = await notification_service.get_history(user_id, limit=limit)
    return {"notifications": history, "total": len(history)}


@router.post("/schedule")
async def schedule_notification(req: ScheduleNotificationRequest):
    """Schedule a notification for future delivery."""
    return await notification_service.schedule_notification(
        req.user_id, req.title, req.body, req.send_at, req.category
    )
