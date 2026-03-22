"""Telegram bot integration — reminders, voice message processing, daily summaries.

Bot capabilities:
- /start — welcome and link account
- /summary — get today's daily summary
- /tasks — list pending tasks and commitments
- /ideas — list recent ideas
- Voice messages → auto-transcribe and process through Nexor AI pipeline
- Push reminders for commitments, follow-ups, daily summary

Uses aiogram 3.x with webhook support for FastAPI integration.
"""

import io
import logging
import uuid
from datetime import datetime

import httpx

from app.core import store
from app.core.config import settings

logger = logging.getLogger(__name__)

# In-memory Telegram user mapping
telegram_users: dict[int, str] = {}  # {telegram_chat_id: nexor_user_id}
telegram_settings: dict[str, dict] = {}  # {user_id: {chat_id, enabled, ...}}


class TelegramBotService:
    """Manages Telegram bot interactions via Bot API."""

    def __init__(self):
        self.token = settings.telegram_bot_token
        self.api_base = "https://api.telegram.org/bot"

    @property
    def is_configured(self) -> bool:
        return bool(self.token)

    def _url(self, method: str) -> str:
        return f"{self.api_base}{self.token}/{method}"

    async def send_message(
        self,
        chat_id: int,
        text: str,
        parse_mode: str = "Markdown",
    ) -> dict:
        """Send a text message to a Telegram chat."""
        if not self.is_configured:
            return {"error": "Telegram bot not configured"}

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                self._url("sendMessage"),
                json={
                    "chat_id": chat_id,
                    "text": text,
                    "parse_mode": parse_mode,
                },
            )
            return response.json()

    async def download_voice(self, file_id: str) -> tuple[bytes, str]:
        """Download a voice message from Telegram servers."""
        if not self.is_configured:
            raise ValueError("Telegram bot not configured")

        async with httpx.AsyncClient(timeout=60.0) as client:
            # Get file path
            response = await client.get(
                self._url("getFile"),
                params={"file_id": file_id},
            )
            data = response.json()
            file_path = data["result"]["file_path"]

            # Download file
            file_url = f"https://api.telegram.org/file/bot{self.token}/{file_path}"
            response = await client.get(file_url)
            response.raise_for_status()

            ext = file_path.split(".")[-1] if "." in file_path else "ogg"
            filename = f"tg_voice_{uuid.uuid4().hex[:8]}.{ext}"

            return response.content, filename

    async def handle_update(self, update: dict) -> dict:
        """Process an incoming Telegram update (message, command, voice)."""
        message = update.get("message", {})
        chat_id = message.get("chat", {}).get("id")
        text = message.get("text", "")
        voice = message.get("voice")

        if not chat_id:
            return {"status": "ignored"}

        # Handle commands
        if text.startswith("/start"):
            return await self._handle_start(chat_id, text)
        elif text.startswith("/summary"):
            return await self._handle_summary(chat_id)
        elif text.startswith("/tasks"):
            return await self._handle_tasks(chat_id)
        elif text.startswith("/ideas"):
            return await self._handle_ideas(chat_id)
        elif text.startswith("/commitments"):
            return await self._handle_commitments(chat_id)
        elif text.startswith("/help"):
            return await self._handle_help(chat_id)
        elif voice:
            return await self._handle_voice(chat_id, voice)
        else:
            # Treat as a note/thought
            return await self._handle_text_note(chat_id, text)

    async def _handle_start(self, chat_id: int, text: str) -> dict:
        """Link Telegram account to Nexor user."""
        # Parse user_id from /start payload (e.g., /start demo-user)
        parts = text.split()
        user_id = parts[1] if len(parts) > 1 else "demo-user"

        telegram_users[chat_id] = user_id
        telegram_settings[user_id] = {
            "chat_id": chat_id,
            "enabled": True,
            "reminders": True,
            "daily_summary": True,
            "voice_processing": True,
        }

        await self.send_message(
            chat_id,
            "*Nexor connected!* 🔗\n\n"
            "I'm your AI memory assistant. Here's what I can do:\n\n"
            "📝 Send me *voice messages* — I'll transcribe and analyze them\n"
            "📊 /summary — today's daily summary\n"
            "✅ /tasks — pending tasks\n"
            "💡 /ideas — recent ideas\n"
            "🤝 /commitments — your promises\n"
            "❓ /help — all commands\n\n"
            f"Linked to user: `{user_id}`"
        )
        return {"status": "started", "user_id": user_id}

    async def _handle_summary(self, chat_id: int) -> dict:
        """Send today's daily summary."""
        user_id = telegram_users.get(chat_id)
        if not user_id:
            await self.send_message(chat_id, "Not linked. Use /start to connect.")
            return {"status": "not_linked"}

        today = datetime.utcnow().strftime("%Y-%m-%d")
        summary = store.daily_summaries.get(today)

        if not summary:
            await self.send_message(
                chat_id,
                "No summary for today yet.\n"
                "Record some audio first, then generate a summary in the app."
            )
            return {"status": "no_summary"}

        headline = summary.get("headline", "No headline")
        score = summary.get("effectiveness_score", "—")
        total_events = summary.get("total_events", 0)
        total_meetings = summary.get("total_meetings", 0)
        total_tasks = summary.get("total_tasks", 0)
        one_thing = summary.get("one_thing_for_tomorrow", "")

        text = (
            f"*📊 Daily Summary — {today}*\n\n"
            f"_{headline}_\n\n"
            f"📈 Effectiveness: *{score}/10*\n"
            f"📅 Events: {total_events}\n"
            f"🤝 Meetings: {total_meetings}\n"
            f"✅ Tasks: {total_tasks}\n"
        )
        if one_thing:
            text += f"\n🎯 *Tomorrow's focus:*\n_{one_thing}_"

        await self.send_message(chat_id, text)
        return {"status": "sent"}

    async def _handle_tasks(self, chat_id: int) -> dict:
        """Send pending tasks list."""
        user_id = telegram_users.get(chat_id)
        if not user_id:
            await self.send_message(chat_id, "Not linked. Use /start to connect.")
            return {"status": "not_linked"}

        tasks = []
        for event in store.events.values():
            for item in event.get("action_items", []):
                tasks.append(item)

        if not tasks:
            await self.send_message(chat_id, "No pending tasks. 🎉")
            return {"status": "empty"}

        text = "*✅ Pending Tasks:*\n\n"
        for i, task in enumerate(tasks[:15], 1):
            t = task.get("task", "")
            assignee = task.get("assignee", "")
            deadline = task.get("deadline", "")
            line = f"{i}. {t}"
            if assignee:
                line += f" → _{assignee}_"
            if deadline:
                line += f" (by {deadline})"
            text += line + "\n"

        await self.send_message(chat_id, text)
        return {"status": "sent", "count": len(tasks)}

    async def _handle_ideas(self, chat_id: int) -> dict:
        """Send recent ideas."""
        ideas = []
        for event in store.events.values():
            for idea in event.get("ideas", []):
                ideas.append(idea)
            if event.get("event_type") == "idea":
                ideas.append({"text": event.get("summary", event.get("title", ""))})

        if not ideas:
            await self.send_message(chat_id, "No ideas captured yet.")
            return {"status": "empty"}

        text = "*💡 Recent Ideas:*\n\n"
        for i, idea in enumerate(ideas[:10], 1):
            t = idea.get("text", "")
            text += f"{i}. {t}\n"

        await self.send_message(chat_id, text)
        return {"status": "sent"}

    async def _handle_commitments(self, chat_id: int) -> dict:
        """Send pending commitments."""
        commitments = []
        for event in store.events.values():
            for c in event.get("commitments", []):
                commitments.append(c)

        if not commitments:
            await self.send_message(chat_id, "No pending commitments. 👍")
            return {"status": "empty"}

        text = "*🤝 Your Commitments:*\n\n"
        for i, c in enumerate(commitments[:10], 1):
            promise = c.get("promise", "")
            to_whom = c.get("to_whom", "")
            deadline = c.get("deadline", "")
            line = f"{i}. {promise}"
            if to_whom:
                line += f" → _{to_whom}_"
            if deadline:
                line += f" (by {deadline})"
            text += line + "\n"

        await self.send_message(chat_id, text)
        return {"status": "sent"}

    async def _handle_help(self, chat_id: int) -> dict:
        await self.send_message(
            chat_id,
            "*Nexor Bot Commands:*\n\n"
            "🎤 *Voice message* — transcribe & process\n"
            "📝 *Text message* — save as a thought/note\n\n"
            "/summary — today's daily summary\n"
            "/tasks — pending tasks\n"
            "/ideas — recent ideas\n"
            "/commitments — your promises\n"
            "/help — this message\n"
        )
        return {"status": "sent"}

    async def _handle_voice(self, chat_id: int, voice: dict) -> dict:
        """Download voice message, save, and queue for processing."""
        user_id = telegram_users.get(chat_id)
        if not user_id:
            await self.send_message(chat_id, "Not linked. Use /start to connect.")
            return {"status": "not_linked"}

        await self.send_message(chat_id, "🎤 Processing voice message...")

        try:
            file_id = voice.get("file_id", "")
            audio_bytes, filename = await self.download_voice(file_id)

            # Save to session
            session_id = str(uuid.uuid4())
            session_dir = f"./audio_storage/{session_id}"
            import os
            os.makedirs(session_dir, exist_ok=True)

            audio_path = os.path.join(session_dir, filename)
            with open(audio_path, "wb") as f:
                f.write(audio_bytes)

            now = datetime.utcnow().isoformat()
            store.sessions[session_id] = {
                "id": session_id,
                "user_id": user_id,
                "source": "telegram_voice",
                "consent_mode": "private",
                "status": "uploaded",
                "started_at": now,
                "created_at": now,
            }
            store.chunks.setdefault(session_id, []).append({
                "id": str(uuid.uuid4()),
                "session_id": session_id,
                "chunk_index": 0,
                "filename": filename,
                "size_bytes": len(audio_bytes),
                "status": "uploaded",
                "created_at": now,
            })

            await self.send_message(
                chat_id,
                f"✅ Voice saved! Session: `{session_id[:8]}...`\n"
                f"📁 {len(audio_bytes) // 1024} KB, {voice.get('duration', 0)}s\n\n"
                "Processing through AI pipeline... "
                "Check the app for results."
            )

            return {
                "status": "voice_saved",
                "session_id": session_id,
                "filename": filename,
                "size_bytes": len(audio_bytes),
            }

        except Exception as e:
            logger.error(f"Voice processing failed: {e}")
            await self.send_message(chat_id, f"❌ Failed to process voice: {e}")
            return {"status": "error", "error": str(e)}

    async def _handle_text_note(self, chat_id: int, text: str) -> dict:
        """Save a text message as a personal thought/note."""
        user_id = telegram_users.get(chat_id)
        if not user_id:
            await self.send_message(chat_id, "Not linked. Use /start to connect.")
            return {"status": "not_linked"}

        if not text.strip():
            return {"status": "empty"}

        event_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()
        store.events[event_id] = {
            "id": event_id,
            "event_type": "personal_thought",
            "title": text[:50] + ("..." if len(text) > 50 else ""),
            "summary": text,
            "source": "telegram",
            "started_at": now,
            "created_at": now,
            "tags": ["telegram", "note"],
        }

        await self.send_message(
            chat_id,
            f"📝 Saved as note!\n_{text[:100]}_"
        )
        return {"status": "saved", "event_id": event_id}

    # MARK: - Outgoing Reminders

    async def send_reminder(
        self,
        user_id: str,
        title: str,
        body: str,
    ) -> dict:
        """Send a reminder to user's Telegram."""
        settings_data = telegram_settings.get(user_id)
        if not settings_data or not settings_data.get("enabled"):
            return {"sent": False, "reason": "not_configured"}

        chat_id = settings_data["chat_id"]
        text = f"*🔔 {title}*\n\n{body}"
        result = await self.send_message(chat_id, text)
        return {"sent": True, "chat_id": chat_id, "result": result}

    async def send_daily_summary_notification(self, user_id: str) -> dict:
        """Send daily summary to Telegram."""
        settings_data = telegram_settings.get(user_id)
        if not settings_data or not settings_data.get("daily_summary"):
            return {"sent": False}

        chat_id = settings_data["chat_id"]
        today = datetime.utcnow().strftime("%Y-%m-%d")
        summary = store.daily_summaries.get(today)

        if summary:
            return await self._handle_summary(chat_id)
        else:
            await self.send_message(
                chat_id,
                "🌙 *End of day!*\n\n"
                "Open Nexor to generate your daily summary "
                "and review today's events."
            )
            return {"sent": True, "type": "nudge"}

    async def send_commitment_reminders(self, user_id: str) -> dict:
        """Send upcoming commitment reminders via Telegram."""
        settings_data = telegram_settings.get(user_id)
        if not settings_data or not settings_data.get("reminders"):
            return {"sent": False}

        chat_id = settings_data["chat_id"]
        today = datetime.utcnow().strftime("%Y-%m-%d")
        sent = 0

        for event in store.events.values():
            for c in event.get("commitments", []):
                deadline = c.get("deadline", "")
                if deadline and today in deadline:
                    await self.send_message(
                        chat_id,
                        f"🤝 *Commitment due today!*\n\n"
                        f"_{c.get('promise', '')}_\n"
                        f"To: {c.get('to_whom', 'someone')}"
                    )
                    sent += 1

            for f in event.get("follow_ups", []):
                by_when = f.get("by_when", "")
                if by_when and today in by_when:
                    await self.send_message(
                        chat_id,
                        f"📋 *Follow-up reminder!*\n\n"
                        f"_{f.get('action', '')}_\n"
                        f"With: {f.get('whom', 'someone')}"
                    )
                    sent += 1

        return {"sent": True, "reminders_count": sent}


telegram_service = TelegramBotService()
