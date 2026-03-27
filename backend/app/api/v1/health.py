"""Health & HealthKit integration endpoints — Apple Watch data sync & wellness insights."""

from fastapi import APIRouter
from pydantic import BaseModel

from app.services.health import health_service

router = APIRouter(prefix="/health", tags=["health"])


class HealthSyncRequest(BaseModel):
    user_id: str = "demo-user"
    date: str | None = None
    sleep: dict | None = None
    activity: dict | None = None
    workouts: list[dict] | None = None
    heart: dict | None = None
    energy_level: int | None = None


class HealthGoalsRequest(BaseModel):
    user_id: str = "demo-user"
    sleep_hours: float | None = None
    steps: int | None = None
    active_minutes: int | None = None
    workout_days_per_week: int | None = None
    water_liters: float | None = None
    bedtime: str | None = None
    wake_time: str | None = None


@router.post("/sync")
async def sync_health_data(req: HealthSyncRequest):
    """Sync HealthKit data from Apple Watch / iPhone."""
    data = req.model_dump(exclude={"user_id"}, exclude_none=True)
    return await health_service.sync_health_data(req.user_id, data)


@router.get("/today")
async def get_today_snapshot(user_id: str = "demo-user"):
    """Get today's health snapshot (sleep, steps, workouts, energy)."""
    return await health_service.get_today_snapshot(user_id)


@router.get("/history")
async def get_health_history(user_id: str = "demo-user", days: int = 7):
    """Get health data for the last N days."""
    return await health_service.get_health_data(user_id, days=days)


@router.get("/trends")
async def get_weekly_trends(user_id: str = "demo-user"):
    """Get weekly health trends (sleep, steps, HRV trends)."""
    return await health_service.get_weekly_trends(user_id)


@router.post("/goals")
async def set_health_goals(req: HealthGoalsRequest):
    """Set health & energy goals."""
    goals = req.model_dump(exclude={"user_id"}, exclude_none=True)
    return await health_service.set_goals(req.user_id, goals)


@router.get("/goals")
async def get_health_goals(user_id: str = "demo-user"):
    """Get current health goals."""
    return await health_service.get_goals(user_id)


@router.get("/progress")
async def get_goal_progress(user_id: str = "demo-user"):
    """Get today's progress towards health goals."""
    return await health_service.get_goal_progress(user_id)


@router.get("/recovery")
async def get_recovery_analysis(user_id: str = "demo-user"):
    """Athlytic-style recovery score (HRV, sleep, resting HR)."""
    return await health_service.get_recovery_analysis(user_id)


@router.get("/battery")
async def get_battery_readiness(user_id: str = "demo-user"):
    """Battery/readiness gauge — capacity remaining today."""
    return await health_service.get_battery_readiness(user_id)


@router.get("/sleep")
async def get_sleep_analysis(user_id: str = "demo-user"):
    """Detailed sleep analysis with stages, score, insights."""
    return await health_service.get_sleep_analysis(user_id)


@router.get("/strain")
async def get_strain_tracking(user_id: str = "demo-user"):
    """Daily strain tracking with workout breakdown."""
    return await health_service.get_strain_tracking(user_id)


@router.get("/hrv")
async def get_hrv_analysis(user_id: str = "demo-user"):
    """Deep HRV analysis with baseline, trends, interpretation."""
    return await health_service.get_hrv_analysis(user_id)


@router.get("/dashboard")
async def get_full_dashboard(user_id: str = "demo-user"):
    """Complete Athlytic-style dashboard in one call."""
    return await health_service.get_full_dashboard(user_id)
