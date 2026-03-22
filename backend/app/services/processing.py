"""Audio processing orchestrator — ties transcription, AI pipeline, calendar, and memory together."""

import logging
import uuid
from datetime import datetime

from app.core import store
from app.services.ai_pipeline import ai_pipeline
from app.services.calendar_sync import calendar_service
from app.services.memory import memory_service
from app.services.transcription import transcription_service

logger = logging.getLogger(__name__)


class ProcessingService:
    """Orchestrates the full pipeline: audio -> transcript -> events -> memory -> calendar."""

    async def process_session(
        self,
        user_id: str,
        session_id: str,
        audio_paths: list[str],
        session_start: datetime,
        language_hint: str = "ru",
    ) -> dict:
        """Process an entire audio session end-to-end."""
        logger.info(f"Processing session {session_id} for user {user_id}")

        # Step 1: Transcribe all chunks
        full_transcript_parts = []
        chunk_results = []

        for i, audio_path in enumerate(audio_paths):
            logger.info(f"Transcribing chunk {i + 1}/{len(audio_paths)}")
            result = await transcription_service.transcribe(audio_path, language_hint)
            full_transcript_parts.append(result.text)
            chunk_results.append({
                "chunk_index": i,
                "text": result.text,
                "language": result.language,
                "confidence": result.confidence,
                "speakers": result.speakers,
            })

        full_transcript = "\n\n".join(full_transcript_parts)

        if not full_transcript.strip():
            logger.info(f"Session {session_id}: no speech detected")
            return {
                "transcript": "",
                "events": [],
                "chunks_processed": len(audio_paths),
            }

        # Step 2: Segment into events via Claude
        logger.info("Segmenting transcript into events")
        raw_events = await ai_pipeline.segment_events(full_transcript, session_start)

        if isinstance(raw_events, dict) and "raw_text" in raw_events:
            logger.warning("Event segmentation returned raw text instead of structured data")
            raw_events = []

        # Step 3: Store events and index into memory
        events_out = []
        for i, event in enumerate(raw_events):
            event_id = event.get("id") or str(uuid.uuid4())
            event["id"] = event_id
            event["session_id"] = session_id
            event["started_at"] = event.get("started_at", session_start.isoformat())
            event["created_at"] = datetime.utcnow().isoformat()

            # Save to shared in-memory store
            store.events[event_id] = event
            events_out.append(event)

            # Index into vector memory
            await memory_service.index_event(user_id, event_id, event)

        # Step 4: Auto-sync meetings to Google Calendar if token available
        calendar_sync_result = None
        token_data = store.calendar_tokens.get(user_id)
        if token_data and token_data.get("access_token"):
            meetings = [
                e for e in events_out
                if e.get("suggested_calendar_event")
            ]
            if meetings:
                try:
                    calendar_sync_result = await calendar_service.sync_events_to_calendar(
                        access_token=token_data["access_token"],
                        events=meetings,
                    )
                    logger.info(f"Calendar sync: {len(calendar_sync_result.get('synced', []))} events synced")
                except Exception as e:
                    logger.error(f"Calendar sync failed: {e}")

        # Update session status
        if session_id in store.sessions:
            store.sessions[session_id]["status"] = "processed"

        logger.info(f"Session {session_id}: {len(events_out)} events extracted")

        result = {
            "transcript": full_transcript,
            "events": events_out,
            "chunks_processed": len(audio_paths),
            "chunk_results": chunk_results,
        }
        if calendar_sync_result:
            result["calendar_sync"] = calendar_sync_result

        return result

    async def generate_daily_summary(
        self, user_id: str, date: str
    ) -> dict:
        """Generate daily summary with structured sections + mentor feedback."""
        # Collect events for the date
        date_events = [
            e for e in store.events.values()
            if e.get("started_at", "").startswith(date)
        ]

        if not date_events:
            return {"error": "No events found for this date"}

        # Generate summary (now includes meetings_section, commitments_section, etc.)
        summary = await ai_pipeline.generate_daily_summary(date_events, date)

        # Generate coaching
        coaching = await ai_pipeline.generate_coaching(date_events)
        if isinstance(coaching, dict) and "raw_text" not in coaching:
            summary["coaching_details"] = coaching

        # Generate mentor feedback
        mentor = await ai_pipeline.generate_mentor_feedback(date_events, date)
        if isinstance(mentor, dict) and "raw_text" not in mentor:
            summary["mentor_feedback"] = mentor
            store.mentor_feedback[date] = mentor

        # Store summary with metadata
        summary["id"] = str(uuid.uuid4())
        summary["date"] = date
        summary["created_at"] = datetime.utcnow().isoformat()
        summary["total_events"] = len(date_events)
        summary["total_meetings"] = len([
            e for e in date_events if e.get("event_type") in ("meeting", "sales_call")
        ])
        summary["total_ideas"] = len([
            e for e in date_events if e.get("event_type") == "idea"
        ])
        summary["total_commitments"] = len([
            e for e in date_events if e.get("commitments")
        ])
        summary["total_tasks"] = sum(
            len(e.get("action_items", []))
            for e in date_events
        )

        store.daily_summaries[date] = summary

        # Auto-sync tasks to Google if token available
        token_data = store.calendar_tokens.get(user_id)
        if token_data and token_data.get("access_token"):
            tasks_section = summary.get("tasks_section", {})
            new_tasks = tasks_section.get("new_tasks", [])
            if new_tasks:
                try:
                    sync_result = await calendar_service.sync_tasks_to_google(
                        access_token=token_data["access_token"],
                        tasks=new_tasks,
                    )
                    summary["tasks_sync"] = sync_result
                except Exception as e:
                    logger.error(f"Tasks sync failed: {e}")

        return summary

    async def analyze_meeting_event(
        self, transcript: str, meeting_context: dict
    ) -> dict:
        """Deep analysis of a specific meeting event."""
        return await ai_pipeline.analyze_meeting(transcript, meeting_context)

    async def get_mentor_feedback(self, date: str) -> dict | None:
        """Get stored mentor feedback for a date."""
        return store.mentor_feedback.get(date)

    async def search_memory(
        self, user_id: str, query: str, filters: dict | None = None
    ) -> str:
        """Search personal memory and generate AI response."""
        results = await memory_service.search(user_id, query, filters=filters)
        if not results:
            return "No relevant memories found for your query."

        context_docs = [r["document"] for r in results]
        return await ai_pipeline.semantic_search(query, context_docs)


processing_service = ProcessingService()
