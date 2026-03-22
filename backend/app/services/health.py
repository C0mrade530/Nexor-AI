"""HealthKit integration service — sync Apple Watch / iPhone health data.

Receives health data from the iOS app and provides AI-powered
wellness recommendations based on sleep, activity, workouts, and energy levels.
"""

import logging
import uuid
from datetime import datetime

from app.core import store
from app.core.config import settings

logger = logging.getLogger(__name__)

# In-memory health data store
health_data: dict[str, list[dict]] = {}  # {user_id: [health_record, ...]}
health_goals: dict[str, dict] = {}  # {user_id: {goals}}


class HealthService:
    """Processes health data from HealthKit and generates wellness insights."""

    async def sync_health_data(
        self,
        user_id: str,
        data: dict,
    ) -> dict:
        """Receive and store health data from iOS HealthKit.

        Expected data format:
        {
            "date": "2026-03-22",
            "sleep": {
                "total_hours": 7.2,
                "deep_hours": 1.5,
                "rem_hours": 1.8,
                "light_hours": 3.9,
                "awake_minutes": 15,
                "bed_time": "23:30",
                "wake_time": "06:45",
                "quality_score": 78  # 0-100
            },
            "activity": {
                "steps": 8432,
                "distance_km": 6.1,
                "active_calories": 420,
                "total_calories": 2100,
                "active_minutes": 45,
                "stand_hours": 10
            },
            "workouts": [
                {
                    "type": "running",
                    "duration_minutes": 35,
                    "calories": 320,
                    "avg_heart_rate": 145,
                    "distance_km": 5.2
                }
            ],
            "heart": {
                "resting_hr": 62,
                "avg_hr": 75,
                "max_hr": 155,
                "hrv": 42
            },
            "energy_level": 7  # 1-10 self-reported
        }
        """
        record = {
            "id": str(uuid.uuid4()),
            "user_id": user_id,
            "date": data.get("date", datetime.utcnow().strftime("%Y-%m-%d")),
            "synced_at": datetime.utcnow().isoformat(),
            **data,
        }

        health_data.setdefault(user_id, [])

        # Replace existing record for same date
        health_data[user_id] = [
            r for r in health_data[user_id]
            if r["date"] != record["date"]
        ]
        health_data[user_id].append(record)

        return {"status": "synced", "record_id": record["id"], "date": record["date"]}

    async def get_health_data(
        self,
        user_id: str,
        date: str | None = None,
        days: int = 7,
    ) -> list[dict]:
        """Get health records, optionally filtered by date or last N days."""
        records = health_data.get(user_id, [])
        if date:
            return [r for r in records if r["date"] == date]
        # Sort by date descending, return last N days
        records = sorted(records, key=lambda r: r["date"], reverse=True)
        return records[:days]

    async def get_today_snapshot(self, user_id: str) -> dict:
        """Get today's health snapshot for the daily summary."""
        today = datetime.utcnow().strftime("%Y-%m-%d")
        records = await self.get_health_data(user_id, date=today)
        if not records:
            return {"available": False}

        record = records[0]
        sleep = record.get("sleep", {})
        activity = record.get("activity", {})
        heart = record.get("heart", {})
        workouts = record.get("workouts", [])

        # Calculate simple energy score
        energy_factors = []
        if sleep.get("total_hours"):
            sleep_score = min(100, (sleep["total_hours"] / 8.0) * 100)
            energy_factors.append(sleep_score)
        if sleep.get("quality_score"):
            energy_factors.append(sleep["quality_score"])
        if activity.get("steps"):
            steps_score = min(100, (activity["steps"] / 10000) * 100)
            energy_factors.append(steps_score)
        if heart.get("hrv"):
            hrv_score = min(100, (heart["hrv"] / 60) * 100)
            energy_factors.append(hrv_score)

        energy_score = int(sum(energy_factors) / len(energy_factors)) if energy_factors else None

        return {
            "available": True,
            "date": today,
            "sleep_hours": sleep.get("total_hours"),
            "sleep_quality": sleep.get("quality_score"),
            "steps": activity.get("steps"),
            "active_minutes": activity.get("active_minutes"),
            "active_calories": activity.get("active_calories"),
            "resting_hr": heart.get("resting_hr"),
            "hrv": heart.get("hrv"),
            "workouts_count": len(workouts),
            "workouts": [
                {
                    "type": w.get("type"),
                    "duration_minutes": w.get("duration_minutes"),
                    "calories": w.get("calories"),
                }
                for w in workouts
            ],
            "energy_score": energy_score,
            "self_reported_energy": record.get("energy_level"),
        }

    async def get_weekly_trends(self, user_id: str) -> dict:
        """Calculate weekly health trends for coaching insights."""
        records = await self.get_health_data(user_id, days=7)
        if not records:
            return {"available": False}

        sleep_hours = [r.get("sleep", {}).get("total_hours", 0) for r in records if r.get("sleep")]
        steps = [r.get("activity", {}).get("steps", 0) for r in records if r.get("activity")]
        active_mins = [r.get("activity", {}).get("active_minutes", 0) for r in records if r.get("activity")]
        hrvs = [r.get("heart", {}).get("hrv", 0) for r in records if r.get("heart", {}).get("hrv")]
        workout_days = sum(1 for r in records if r.get("workouts"))

        def avg(lst):
            return round(sum(lst) / len(lst), 1) if lst else None

        return {
            "available": True,
            "days_tracked": len(records),
            "avg_sleep_hours": avg(sleep_hours),
            "avg_steps": int(avg(steps)) if steps else None,
            "avg_active_minutes": int(avg(active_mins)) if active_mins else None,
            "avg_hrv": int(avg(hrvs)) if hrvs else None,
            "workout_days": workout_days,
            "sleep_trend": self._trend(sleep_hours),
            "steps_trend": self._trend(steps),
            "hrv_trend": self._trend(hrvs),
        }

    async def set_goals(self, user_id: str, goals: dict) -> dict:
        """Set health & energy goals.

        Example:
        {
            "sleep_hours": 8,
            "steps": 10000,
            "active_minutes": 60,
            "workout_days_per_week": 4,
            "water_liters": 2.5,
            "bedtime": "23:00",
            "wake_time": "06:30"
        }
        """
        health_goals[user_id] = {
            "user_id": user_id,
            "updated_at": datetime.utcnow().isoformat(),
            **goals,
        }
        return health_goals[user_id]

    async def get_goals(self, user_id: str) -> dict:
        return health_goals.get(user_id, {
            "sleep_hours": 8,
            "steps": 10000,
            "active_minutes": 60,
            "workout_days_per_week": 4,
        })

    async def get_goal_progress(self, user_id: str) -> dict:
        """Compare today's data vs goals."""
        today = await self.get_today_snapshot(user_id)
        goals = await self.get_goals(user_id)

        if not today.get("available"):
            return {"available": False}

        progress = {}
        if today.get("sleep_hours") and goals.get("sleep_hours"):
            progress["sleep"] = {
                "current": today["sleep_hours"],
                "goal": goals["sleep_hours"],
                "percent": min(100, int((today["sleep_hours"] / goals["sleep_hours"]) * 100)),
            }
        if today.get("steps") and goals.get("steps"):
            progress["steps"] = {
                "current": today["steps"],
                "goal": goals["steps"],
                "percent": min(100, int((today["steps"] / goals["steps"]) * 100)),
            }
        if today.get("active_minutes") and goals.get("active_minutes"):
            progress["active_minutes"] = {
                "current": today["active_minutes"],
                "goal": goals["active_minutes"],
                "percent": min(100, int((today["active_minutes"] / goals["active_minutes"]) * 100)),
            }

        total_percent = 0
        count = 0
        for v in progress.values():
            total_percent += v["percent"]
            count += 1

        progress["overall_percent"] = int(total_percent / count) if count else 0
        progress["available"] = True

        return progress

    def _trend(self, values: list) -> str | None:
        """Simple trend: compare first half vs second half averages."""
        if len(values) < 4:
            return None
        mid = len(values) // 2
        first_half = sum(values[:mid]) / mid
        second_half = sum(values[mid:]) / (len(values) - mid)
        diff_pct = ((second_half - first_half) / first_half * 100) if first_half else 0
        if diff_pct > 5:
            return "improving"
        elif diff_pct < -5:
            return "declining"
        return "stable"


health_service = HealthService()
