"""Audio processing orchestrator — ties transcription, AI pipeline, and memory together."""

import logging
from datetime import datetime

from app.services.ai_pipeline import ai_pipeline
from app.services.memory import memory_service
from app.services.transcription import transcription_service

logger = logging.getLogger(__name__)


class ProcessingService:
    """Orchestrates the full pipeline: audio → transcript → events → memory."""

    async def process_session(
        self,
        user_id: str,
        session_id: str,
        audio_paths: list[str],
        session_start: datetime,
        language_hint: str = "ru",
    ) -> dict:
        """Process an entire audio session end-to-end.

        Returns:
            dict with transcript, events, and processing stats.
        """
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

        # Step 2: Segment into events
        logger.info(f"Segmenting transcript into events")
        events = await ai_pipeline.segment_events(full_transcript, session_start)

        if isinstance(events, dict) and "raw_text" in events:
            logger.warning("Event segmentation returned raw text instead of structured data")
            events = []

        # Step 3: Index events into memory
        for event in events:
            event_id = event.get("id", str(session_id) + f"_evt_{events.index(event)}")
            event["started_at"] = event.get("started_at", session_start.isoformat())
            await memory_service.index_event(user_id, event_id, event)

        logger.info(f"Session {session_id}: {len(events)} events extracted")

        return {
            "transcript": full_transcript,
            "events": events,
            "chunks_processed": len(audio_paths),
            "chunk_results": chunk_results,
        }

    async def generate_daily_summary(
        self, user_id: str, events: list[dict], date: str
    ) -> dict:
        """Generate daily summary and coaching from events."""
        summary = await ai_pipeline.generate_daily_summary(events, date)
        coaching = await ai_pipeline.generate_coaching(events)

        if isinstance(coaching, dict) and "raw_text" not in coaching:
            summary["coaching_details"] = coaching

        return summary

    async def analyze_meeting_event(
        self, transcript: str, meeting_context: dict
    ) -> dict:
        """Deep analysis of a specific meeting event."""
        return await ai_pipeline.analyze_meeting(transcript, meeting_context)

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
