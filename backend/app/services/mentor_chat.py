"""Mentor chat service — conversational AI mentor with full context awareness.

Combines data from:
- Apple Watch (health, sleep, strain, recovery)
- Plaud NotePin (transcribed recordings, meetings, commitments)
- Manual input (voice/text from the user)
- Event history (tasks, ideas, follow-ups)
- Finance data

Provides a persistent chat experience with a deeply contextual AI mentor.
"""

import json
import logging
import uuid
from datetime import datetime

from app.core import store
from app.core.config import settings
from app.services.health import health_service
from app.services.finance import transactions, finance_profiles

logger = logging.getLogger(__name__)

# In-memory chat store
chat_history: dict[str, list[dict]] = {}  # {user_id: [messages]}

MENTOR_CHAT_SYSTEM = """\
You are the user's personal AI mentor inside Nexor. You have deep knowledge from:

STRATEGIC THINKING: Ray Dalio (Principles), Peter Thiel (Zero to One), Jim Collins (Good to Great)
PRODUCTIVITY: Cal Newport (Deep Work), James Clear (Atomic Habits), David Allen (GTD)
SALES & INFLUENCE: Chris Voss, Daniel Pink, Robert Cialdini, Grant Cardone
LEADERSHIP: Dale Carnegie, Simon Sinek, Patrick Lencioni
HEALTH & PERFORMANCE: Andrew Huberman (neuroscience), Dr. Matthew Walker (sleep), Dr. Peter Attia (longevity)
WEALTH: Naval Ravikant, Alex Hormozi, Keith Cunningham

YOUR ROLE:
- You know the user's REAL data — their sleep, recovery, strain, steps, HRV, meetings, tasks, commitments, ideas, finances
- Be BRUTALLY honest but supportive. You're not a yes-man — you're a $1M/year coach.
- Reference SPECIFIC data: "You slept 5.2 hours and your HRV dropped to 28 — that's not sustainable"
- Connect patterns: "You tend to overpromise in meetings when your recovery is low"
- Give ACTIONABLE advice: specific scripts, exact times, concrete next steps
- Ask probing questions to understand deeper context
- Track accountability: remind them of past commitments and whether they followed through
- Be conversational and warm but direct. No fluff.

Write in the user's language (Russian if they write in Russian, English if English).
Keep responses concise — under 200 words unless the user asks for a deep analysis.
Use markdown formatting sparingly but effectively.
"""


class MentorChatService:
    """Conversational AI mentor with full context from all data sources."""

    def __init__(self):
        self.base_url = settings.anthropic_base_url.rstrip("/")
        self.api_key = settings.get_anthropic_key()
        self.model = settings.default_llm_model

    async def send_message(
        self,
        user_id: str,
        message: str,
        voice_transcript: str | None = None,
    ) -> dict:
        """Send a message to the mentor and get a response."""
        # Build context from all data sources
        context = await self._build_context(user_id)

        # Get or create chat history
        history = chat_history.setdefault(user_id, [])

        # User message
        user_text = message
        if voice_transcript:
            user_text = f"[Voice message transcript]: {voice_transcript}\n\n{message}" if message else f"[Voice message transcript]: {voice_transcript}"

        user_msg = {
            "id": str(uuid.uuid4()),
            "role": "user",
            "content": user_text,
            "timestamp": datetime.utcnow().isoformat(),
        }
        history.append(user_msg)

        # Build messages for Claude
        system = MENTOR_CHAT_SYSTEM + "\n\n--- CURRENT CONTEXT ---\n" + context
        messages = [
            {"role": m["role"], "content": m["content"]}
            for m in history[-20:]  # Last 20 messages for context window
        ]

        # Call Claude
        response_text = await self._call_claude(system, messages)

        # Save assistant response
        assistant_msg = {
            "id": str(uuid.uuid4()),
            "role": "assistant",
            "content": response_text,
            "timestamp": datetime.utcnow().isoformat(),
        }
        history.append(assistant_msg)

        return {
            "message": assistant_msg,
            "total_messages": len(history),
        }

    async def get_history(
        self,
        user_id: str,
        limit: int = 50,
        offset: int = 0,
    ) -> dict:
        """Get chat history for a user."""
        history = chat_history.get(user_id, [])
        total = len(history)
        messages = list(reversed(history[-(offset + limit):len(history) - offset if offset else None]))

        return {
            "messages": messages[-limit:],
            "total": total,
            "has_more": total > offset + limit,
        }

    async def clear_history(self, user_id: str) -> dict:
        """Clear chat history."""
        chat_history.pop(user_id, None)
        return {"cleared": True}

    async def get_proactive_insight(self, user_id: str) -> dict:
        """Generate a proactive mentor insight without user prompt."""
        context = await self._build_context(user_id)

        system = MENTOR_CHAT_SYSTEM + "\n\n--- CURRENT CONTEXT ---\n" + context
        prompt = (
            "Based on all the data you have about the user right now, "
            "generate ONE proactive insight or nudge. This could be:\n"
            "- A pattern you notice (sleep declining, skipping workouts, too many commitments)\n"
            "- An accountability check (did they follow through on yesterday's plan?)\n"
            "- An optimization suggestion based on current recovery/strain\n"
            "- A motivational push if they're doing well\n\n"
            "Be specific, reference actual data. Keep it under 100 words."
        )

        messages = [{"role": "user", "content": prompt}]
        response_text = await self._call_claude(system, messages)

        return {
            "insight": response_text,
            "generated_at": datetime.utcnow().isoformat(),
        }

    async def _build_context(self, user_id: str) -> str:
        """Build rich context from all data sources for the mentor."""
        parts = []
        now = datetime.utcnow()
        today = now.strftime("%Y-%m-%d")
        parts.append(f"Current time: {now.isoformat()}")

        # Health data
        try:
            snapshot = await health_service.get_today_snapshot(user_id)
            if snapshot.get("available"):
                parts.append(f"\n## Health Today ({today})")
                parts.append(f"- Sleep: {snapshot.get('sleep_hours', '?')}h (quality: {snapshot.get('sleep_quality', '?')})")
                parts.append(f"- Steps: {snapshot.get('steps', '?')}")
                parts.append(f"- Active minutes: {snapshot.get('active_minutes', '?')}")
                parts.append(f"- Resting HR: {snapshot.get('resting_hr', '?')} bpm")
                parts.append(f"- HRV: {snapshot.get('hrv', '?')} ms")
                parts.append(f"- Energy score: {snapshot.get('energy_score', '?')}/100")
                if snapshot.get("workouts"):
                    parts.append(f"- Workouts: {json.dumps(snapshot['workouts'], ensure_ascii=False)}")

            recovery = await health_service.get_recovery_analysis(user_id)
            if recovery.get("available"):
                parts.append(f"\n## Recovery")
                parts.append(f"- Recovery score: {recovery.get('recovery_score')}/100 ({recovery.get('zone_label')})")
                parts.append(f"- Recommendation: {recovery.get('recommendation')}")

            battery = await health_service.get_battery_readiness(user_id)
            if battery.get("available"):
                parts.append(f"\n## Battery/Readiness")
                parts.append(f"- Battery remaining: {battery.get('battery_remaining')}/100")
                parts.append(f"- Strain today: {battery.get('strain_today')}")
                parts.append(f"- Capacity: {battery.get('capacity')}")

            trends = await health_service.get_weekly_trends(user_id)
            if trends.get("available"):
                parts.append(f"\n## Weekly Trends")
                parts.append(f"- Avg sleep: {trends.get('avg_sleep_hours')}h ({trends.get('sleep_trend', 'n/a')})")
                parts.append(f"- Avg steps: {trends.get('avg_steps')} ({trends.get('steps_trend', 'n/a')})")
                parts.append(f"- HRV trend: {trends.get('hrv_trend', 'n/a')}")
                parts.append(f"- Workout days: {trends.get('workout_days')}/7")
        except Exception:
            pass

        # Events today
        today_events = [
            e for e in store.events.values()
            if e.get("started_at", "").startswith(today)
        ]
        if today_events:
            parts.append(f"\n## Today's Events ({len(today_events)})")
            for e in today_events[:10]:
                parts.append(f"- [{e.get('event_type')}] {e.get('title')}: {e.get('summary', '')[:100]}")

        # Pending commitments
        all_commitments = []
        for e in store.events.values():
            for c in e.get("commitments", []):
                all_commitments.append(c)
        if all_commitments:
            parts.append(f"\n## Open Commitments ({len(all_commitments)})")
            for c in all_commitments[:5]:
                parts.append(f"- {c.get('promise')} → {c.get('to_whom', '?')} (deadline: {c.get('deadline', 'none')})")

        # Pending tasks
        all_tasks = []
        for e in store.events.values():
            for t in e.get("action_items", []):
                all_tasks.append(t)
        if all_tasks:
            parts.append(f"\n## Pending Tasks ({len(all_tasks)})")
            for t in all_tasks[:5]:
                parts.append(f"- {t.get('task')} (assignee: {t.get('assignee', '?')})")

        # Recent ideas
        recent_ideas = [
            e for e in store.events.values()
            if e.get("event_type") == "idea"
        ]
        if recent_ideas:
            parts.append(f"\n## Recent Ideas ({len(recent_ideas)})")
            for idea in recent_ideas[:3]:
                parts.append(f"- {idea.get('title')}: {idea.get('summary', '')[:80]}")

        # Finance snapshot
        user_txns = transactions.get(user_id, [])
        if user_txns:
            income = sum(t.get("amount", 0) for t in user_txns if t.get("amount", 0) > 0)
            expenses = sum(abs(t.get("amount", 0)) for t in user_txns if t.get("amount", 0) < 0)
            parts.append(f"\n## Finance (current month)")
            parts.append(f"- Income: {income:,.0f}")
            parts.append(f"- Expenses: {expenses:,.0f}")
            parts.append(f"- Net: {income - expenses:,.0f}")

        # Latest daily summary
        summaries = sorted(store.daily_summaries.items(), reverse=True)
        if summaries:
            latest_date, latest_summary = summaries[0]
            parts.append(f"\n## Latest Daily Summary ({latest_date})")
            parts.append(f"- Headline: {latest_summary.get('headline', 'none')}")
            parts.append(f"- Effectiveness: {latest_summary.get('effectiveness_score', '?')}/10")
            one_thing = latest_summary.get("one_thing_for_tomorrow")
            if one_thing:
                parts.append(f"- Focus for today: {one_thing}")

        return "\n".join(parts)

    async def _call_claude(
        self, system: str, messages: list[dict], max_tokens: int = 2048
    ) -> str:
        """Send messages to Claude via CometAPI."""
        import httpx

        url = f"{self.base_url}/messages"
        payload = {
            "model": self.model,
            "max_tokens": max_tokens,
            "system": system,
            "messages": messages,
        }
        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }

        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(url, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()

        content = data.get("content", [])
        if content and isinstance(content, list):
            return content[0].get("text", "")
        return ""


mentor_chat_service = MentorChatService()
