"""HealthKit integration service — sync Apple Watch / iPhone health data.

Receives health data from the iOS app and provides Athlytic-style
analytics: recovery score, readiness/battery, sleep analysis, strain tracking,
HRV trends, and AI-powered wellness coaching.
"""

import logging
import math
import uuid
from datetime import datetime, timedelta

from app.core import store
from app.core.config import settings

logger = logging.getLogger(__name__)

# In-memory health data store
health_data: dict[str, list[dict]] = {}  # {user_id: [health_record, ...]}
health_goals: dict[str, dict] = {}  # {user_id: {goals}}


class HealthService:
    """Processes health data from HealthKit and generates Athlytic-style analytics."""

    async def sync_health_data(
        self,
        user_id: str,
        data: dict,
    ) -> dict:
        """Receive and store health data from iOS HealthKit."""
        record = {
            "id": str(uuid.uuid4()),
            "user_id": user_id,
            "date": data.get("date", datetime.utcnow().strftime("%Y-%m-%d")),
            "synced_at": datetime.utcnow().isoformat(),
            **data,
        }

        health_data.setdefault(user_id, [])
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
        records = health_data.get(user_id, [])
        if date:
            return [r for r in records if r["date"] == date]
        records = sorted(records, key=lambda r: r["date"], reverse=True)
        return records[:days]

    async def get_today_snapshot(self, user_id: str) -> dict:
        today = datetime.utcnow().strftime("%Y-%m-%d")
        records = await self.get_health_data(user_id, date=today)
        if not records:
            return {"available": False}

        record = records[0]
        sleep = record.get("sleep", {})
        activity = record.get("activity", {})
        heart = record.get("heart", {})
        workouts = record.get("workouts", [])

        energy_score = self._calc_energy_score(sleep, activity, heart)

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

    # ==================== ATHLYTIC-STYLE ANALYTICS ====================

    async def get_recovery_analysis(self, user_id: str) -> dict:
        """Athlytic-style recovery score based on sleep, HRV, resting HR."""
        today = datetime.utcnow().strftime("%Y-%m-%d")
        records = await self.get_health_data(user_id, date=today)
        history = await self.get_health_data(user_id, days=14)

        if not records:
            return {"available": False}

        record = records[0]
        sleep = record.get("sleep", {})
        heart = record.get("heart", {})

        # HRV baseline (14-day avg)
        hrvs = [r.get("heart", {}).get("hrv", 0) for r in history if r.get("heart", {}).get("hrv")]
        hrv_baseline = sum(hrvs) / len(hrvs) if hrvs else 45
        current_hrv = heart.get("hrv", 0)

        # Resting HR baseline
        rhrs = [r.get("heart", {}).get("resting_hr", 0) for r in history if r.get("heart", {}).get("resting_hr")]
        rhr_baseline = sum(rhrs) / len(rhrs) if rhrs else 65
        current_rhr = heart.get("resting_hr", 0)

        # Recovery components
        hrv_score = min(100, max(0, int((current_hrv / hrv_baseline) * 60))) if hrv_baseline else 50
        rhr_score = min(100, max(0, int((rhr_baseline / max(current_rhr, 40)) * 50))) if current_rhr else 50
        sleep_score = self._calc_sleep_score(sleep)

        recovery_score = int(hrv_score * 0.4 + sleep_score * 0.4 + rhr_score * 0.2)
        recovery_score = min(100, max(0, recovery_score))

        # Recovery zone
        if recovery_score >= 67:
            zone = "green"
            zone_label = "Well Recovered"
            recommendation = "You're well-recovered. Great day for high-intensity training or deep work."
        elif recovery_score >= 34:
            zone = "yellow"
            zone_label = "Moderate Recovery"
            recommendation = "Moderate recovery. Consider lighter training. Focus on steady-state cardio or skill work."
        else:
            zone = "red"
            zone_label = "Low Recovery"
            recommendation = "Recovery is low. Prioritize rest, gentle movement, and sleep tonight."

        return {
            "available": True,
            "date": today,
            "recovery_score": recovery_score,
            "zone": zone,
            "zone_label": zone_label,
            "recommendation": recommendation,
            "components": {
                "hrv": {"score": hrv_score, "current": current_hrv, "baseline": round(hrv_baseline, 1)},
                "resting_hr": {"score": rhr_score, "current": current_rhr, "baseline": round(rhr_baseline, 1)},
                "sleep": {"score": sleep_score, "hours": sleep.get("total_hours", 0), "quality": sleep.get("quality_score", 0)},
            },
        }

    async def get_battery_readiness(self, user_id: str) -> dict:
        """Battery/readiness gauge — how much capacity you have today."""
        recovery = await self.get_recovery_analysis(user_id)
        if not recovery.get("available"):
            return {"available": False}

        today = datetime.utcnow().strftime("%Y-%m-%d")
        records = await self.get_health_data(user_id, date=today)
        record = records[0] if records else {}

        activity = record.get("activity", {})
        workouts = record.get("workouts", [])

        # Strain from today's activity
        strain = self._calc_strain(activity, workouts)

        # Battery = recovery - strain used
        battery_start = recovery["recovery_score"]
        battery_used = min(strain, battery_start)
        battery_remaining = max(0, battery_start - battery_used)

        # Capacity recommendations
        if battery_remaining >= 60:
            capacity = "high"
            advice = "High capacity remaining. Good time for intense workout or demanding mental work."
        elif battery_remaining >= 30:
            capacity = "medium"
            advice = "Moderate capacity. Maintain current pace. Avoid adding major stressors."
        else:
            capacity = "low"
            advice = "Battery low. Wind down activity. Focus on recovery and lighter tasks."

        return {
            "available": True,
            "date": today,
            "battery_start": battery_start,
            "battery_remaining": battery_remaining,
            "battery_used": battery_used,
            "strain_today": strain,
            "capacity": capacity,
            "advice": advice,
            "breakdown": {
                "recovery_contribution": battery_start,
                "activity_drain": battery_used,
                "workout_strain": sum(self._workout_strain(w) for w in workouts),
                "step_strain": min(20, int(activity.get("steps", 0) / 500)),
            },
        }

    async def get_sleep_analysis(self, user_id: str) -> dict:
        """Detailed sleep analysis — Athlytic-style sleep breakdown."""
        today = datetime.utcnow().strftime("%Y-%m-%d")
        records = await self.get_health_data(user_id, date=today)
        history = await self.get_health_data(user_id, days=7)

        if not records:
            return {"available": False}

        sleep = records[0].get("sleep", {})
        if not sleep.get("total_hours"):
            return {"available": False, "reason": "no_sleep_data"}

        total = sleep.get("total_hours", 0)
        deep = sleep.get("deep_hours", 0)
        rem = sleep.get("rem_hours", 0)
        light = sleep.get("light_hours", total - deep - rem)

        # Sleep score
        score = self._calc_sleep_score(sleep)

        # Ideal ranges
        deep_pct = (deep / total * 100) if total else 0
        rem_pct = (rem / total * 100) if total else 0
        light_pct = (light / total * 100) if total else 0

        # Sleep consistency (7-day)
        sleep_times = [r.get("sleep", {}).get("total_hours", 0) for r in history if r.get("sleep", {}).get("total_hours")]
        avg_sleep = sum(sleep_times) / len(sleep_times) if sleep_times else total
        consistency = max(0, 100 - int(abs(total - avg_sleep) / avg_sleep * 100 * 3)) if avg_sleep else 100

        # Insights
        insights = []
        if deep_pct < 15:
            insights.append({"type": "warning", "text": "Deep sleep is low. Avoid alcohol and screens before bed."})
        elif deep_pct >= 20:
            insights.append({"type": "positive", "text": "Excellent deep sleep! Great for physical recovery."})
        if rem_pct < 20:
            insights.append({"type": "warning", "text": "REM sleep is low. This affects memory consolidation and creativity."})
        elif rem_pct >= 25:
            insights.append({"type": "positive", "text": "Strong REM sleep. Great for learning and emotional processing."})
        if total < 7:
            insights.append({"type": "warning", "text": f"Only {total:.1f}h of sleep. Aim for 7-9 hours."})
        elif total >= 7:
            insights.append({"type": "positive", "text": f"Good sleep duration at {total:.1f} hours."})
        if consistency < 70:
            insights.append({"type": "warning", "text": "Sleep schedule is inconsistent. Try a regular bedtime."})

        return {
            "available": True,
            "date": today,
            "score": score,
            "total_hours": total,
            "stages": {
                "deep": {"hours": round(deep, 1), "percent": round(deep_pct, 1), "ideal_range": "15-25%"},
                "rem": {"hours": round(rem, 1), "percent": round(rem_pct, 1), "ideal_range": "20-25%"},
                "light": {"hours": round(light, 1), "percent": round(light_pct, 1), "ideal_range": "50-60%"},
            },
            "bed_time": sleep.get("bed_time"),
            "wake_time": sleep.get("wake_time"),
            "quality_score": sleep.get("quality_score"),
            "consistency": consistency,
            "avg_sleep_7d": round(avg_sleep, 1),
            "insights": insights,
        }

    async def get_strain_tracking(self, user_id: str) -> dict:
        """Daily strain tracking — how hard you pushed today."""
        today = datetime.utcnow().strftime("%Y-%m-%d")
        records = await self.get_health_data(user_id, date=today)
        history = await self.get_health_data(user_id, days=7)

        if not records:
            return {"available": False}

        record = records[0]
        activity = record.get("activity", {})
        workouts = record.get("workouts", [])
        heart = record.get("heart", {})

        strain = self._calc_strain(activity, workouts)

        # Strain by category
        workout_strains = []
        for w in workouts:
            ws = self._workout_strain(w)
            workout_strains.append({
                "type": w.get("type", "unknown"),
                "duration_minutes": w.get("duration_minutes", 0),
                "calories": w.get("calories", 0),
                "strain": ws,
                "avg_hr": w.get("avg_heart_rate"),
            })

        # Weekly strain history
        weekly_strains = []
        for r in sorted(history, key=lambda x: x["date"]):
            a = r.get("activity", {})
            w = r.get("workouts", [])
            weekly_strains.append({
                "date": r["date"],
                "strain": self._calc_strain(a, w),
            })

        # Optimal strain zone based on recovery
        recovery = await self.get_recovery_analysis(user_id)
        recovery_score = recovery.get("recovery_score", 50)
        optimal_max = int(recovery_score * 0.8)

        if strain > optimal_max:
            strain_status = "overreaching"
            strain_advice = "You've exceeded optimal strain. Prioritize recovery."
        elif strain >= optimal_max * 0.5:
            strain_status = "optimal"
            strain_advice = "Great balance of effort and recovery."
        else:
            strain_status = "under_trained"
            strain_advice = "Room for more activity. Consider adding a workout."

        return {
            "available": True,
            "date": today,
            "strain_score": strain,
            "max_hr_today": heart.get("max_hr"),
            "avg_hr_today": heart.get("avg_hr"),
            "strain_status": strain_status,
            "strain_advice": strain_advice,
            "optimal_strain_range": [int(optimal_max * 0.4), optimal_max],
            "workouts": workout_strains,
            "steps": activity.get("steps", 0),
            "active_calories": activity.get("active_calories", 0),
            "active_minutes": activity.get("active_minutes", 0),
            "weekly_strain": weekly_strains,
        }

    async def get_hrv_analysis(self, user_id: str) -> dict:
        """Deep HRV analysis with trends and insights."""
        history = await self.get_health_data(user_id, days=30)
        hrvs = []
        for r in sorted(history, key=lambda x: x["date"]):
            hrv = r.get("heart", {}).get("hrv")
            if hrv:
                hrvs.append({"date": r["date"], "hrv": hrv, "resting_hr": r.get("heart", {}).get("resting_hr")})

        if not hrvs:
            return {"available": False}

        values = [h["hrv"] for h in hrvs]
        current = values[-1] if values else 0
        baseline = sum(values) / len(values) if values else 0
        high = max(values)
        low = min(values)

        # Variability (CV)
        if len(values) >= 2:
            mean = sum(values) / len(values)
            variance = sum((v - mean) ** 2 for v in values) / len(values)
            cv = (math.sqrt(variance) / mean * 100) if mean else 0
        else:
            cv = 0

        # Trend
        trend_7d = self._trend(values[-7:]) if len(values) >= 7 else None
        trend_30d = self._trend(values) if len(values) >= 8 else None

        # Status
        if current >= baseline * 1.1:
            status = "above_baseline"
            interpretation = "HRV is above your baseline. Your body is well-recovered and adapting positively."
        elif current >= baseline * 0.9:
            status = "at_baseline"
            interpretation = "HRV is normal. You're in a balanced state."
        else:
            status = "below_baseline"
            interpretation = "HRV is below baseline. This may indicate accumulated stress, poor sleep, or overtraining."

        return {
            "available": True,
            "current": current,
            "baseline": round(baseline, 1),
            "high_30d": high,
            "low_30d": low,
            "coefficient_of_variation": round(cv, 1),
            "status": status,
            "interpretation": interpretation,
            "trend_7d": trend_7d,
            "trend_30d": trend_30d,
            "history": hrvs[-14:],  # Last 14 data points
        }

    async def get_full_dashboard(self, user_id: str) -> dict:
        """Complete Athlytic-style dashboard in one call."""
        recovery = await self.get_recovery_analysis(user_id)
        battery = await self.get_battery_readiness(user_id)
        sleep = await self.get_sleep_analysis(user_id)
        strain = await self.get_strain_tracking(user_id)
        hrv = await self.get_hrv_analysis(user_id)
        snapshot = await self.get_today_snapshot(user_id)
        goals = await self.get_goal_progress(user_id)
        trends = await self.get_weekly_trends(user_id)

        return {
            "available": recovery.get("available", False),
            "date": datetime.utcnow().strftime("%Y-%m-%d"),
            "recovery": recovery,
            "battery": battery,
            "sleep": sleep,
            "strain": strain,
            "hrv": hrv,
            "snapshot": snapshot,
            "goals": goals,
            "trends": trends,
        }

    # ==================== EXISTING METHODS ====================

    async def get_weekly_trends(self, user_id: str) -> dict:
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

    # ==================== SCORING HELPERS ====================

    def _calc_energy_score(self, sleep: dict, activity: dict, heart: dict) -> int | None:
        factors = []
        if sleep.get("total_hours"):
            factors.append(min(100, (sleep["total_hours"] / 8.0) * 100))
        if sleep.get("quality_score"):
            factors.append(sleep["quality_score"])
        if activity.get("steps"):
            factors.append(min(100, (activity["steps"] / 10000) * 100))
        if heart.get("hrv"):
            factors.append(min(100, (heart["hrv"] / 60) * 100))
        return int(sum(factors) / len(factors)) if factors else None

    def _calc_sleep_score(self, sleep: dict) -> int:
        """Calculate sleep score 0-100 based on duration, stages, quality."""
        score = 0
        total = sleep.get("total_hours", 0)

        # Duration (40 pts)
        if total >= 8:
            score += 40
        elif total >= 7:
            score += 35
        elif total >= 6:
            score += 25
        elif total >= 5:
            score += 15
        else:
            score += 5

        # Quality (30 pts)
        quality = sleep.get("quality_score", 0)
        score += int(quality * 0.3)

        # Deep sleep (15 pts)
        deep = sleep.get("deep_hours", 0)
        if total > 0:
            deep_pct = deep / total * 100
            if deep_pct >= 20:
                score += 15
            elif deep_pct >= 15:
                score += 10
            elif deep_pct >= 10:
                score += 5

        # REM (15 pts)
        rem = sleep.get("rem_hours", 0)
        if total > 0:
            rem_pct = rem / total * 100
            if rem_pct >= 25:
                score += 15
            elif rem_pct >= 20:
                score += 10
            elif rem_pct >= 15:
                score += 5

        return min(100, max(0, score))

    def _calc_strain(self, activity: dict, workouts: list) -> int:
        """Calculate daily strain score 0-100."""
        strain = 0

        # Steps contribution (max 20)
        steps = activity.get("steps", 0)
        strain += min(20, int(steps / 500))

        # Active calories (max 20)
        cals = activity.get("active_calories", 0)
        strain += min(20, int(cals / 25))

        # Active minutes (max 15)
        mins = activity.get("active_minutes", 0)
        strain += min(15, int(mins / 4))

        # Workouts (max 45)
        for w in workouts:
            strain += self._workout_strain(w)

        return min(100, strain)

    def _workout_strain(self, workout: dict) -> int:
        """Calculate strain from a single workout."""
        duration = workout.get("duration_minutes", 0)
        calories = workout.get("calories", 0)
        avg_hr = workout.get("avg_heart_rate", 0)

        # Base strain from duration
        base = min(15, int(duration / 5))

        # Intensity multiplier from HR
        if avg_hr >= 160:
            multiplier = 1.5
        elif avg_hr >= 140:
            multiplier = 1.3
        elif avg_hr >= 120:
            multiplier = 1.1
        else:
            multiplier = 1.0

        return min(20, int(base * multiplier))

    def _trend(self, values: list) -> str | None:
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
