"""AI pipeline — event segmentation, extraction, summarization, coaching."""

import json
import logging
from datetime import datetime

import anthropic

from app.core.config import settings

logger = logging.getLogger(__name__)

SEGMENTATION_PROMPT = """\
You are an AI assistant for LifeOS, a personal memory system. You analyze transcripts
of a user's day and segment them into meaningful events.

Given a transcript with timestamps, identify and segment it into distinct events.

Event types:
- meeting: a structured conversation with others (work call, client meeting)
- idea: a creative thought or concept the user expressed
- task: a specific action item or todo mentioned
- commitment: a promise made to someone
- personal_thought: reflection, journaling, thinking out loud
- planning: scheduling, organizing, prioritizing
- sales_call: a sales-related conversation
- casual_conversation: informal chat, small talk
- emotional_episode: a moment of strong emotion
- follow_up: mention of needing to follow up on something
- decision: a clear decision being made

For each event, extract:
1. title — brief descriptive title
2. event_type — from the list above
3. summary — 2-3 sentence summary
4. participants — list of people involved (if mentioned)
5. action_items — specific tasks/todos with assignees if known
6. ideas — any creative ideas mentioned
7. decisions — decisions made
8. commitments — promises/commitments made
9. follow_ups — things that need follow-up
10. emotional_tone — overall emotional tone (positive, negative, neutral, excited, stressed, etc.)
11. urgency — 1-5 scale
12. importance — 1-5 scale
13. tags — relevant tags
14. suggested_calendar_event — if a meeting/call was scheduled, extract details

Respond with a JSON array of events. Be thorough but precise — don't hallucinate details
not present in the transcript.

IMPORTANT: Include transcript excerpts as source references for each event.
"""

DAILY_SUMMARY_PROMPT = """\
You are a personal AI executive assistant for LifeOS. Generate a comprehensive daily summary.

Given the events from today, create:

1. headline — one sentence capturing the essence of the day
2. summary — 3-5 paragraph overview of the day
3. key_events — list of the most important events with brief descriptions
4. key_ideas — all ideas captured today with categories
5. key_decisions — decisions made today
6. new_tasks — action items generated today
7. commitments_made — promises made to others
8. follow_ups_needed — things requiring follow-up
9. emotional_state_summary — overall emotional arc of the day
10. coaching_feedback — actionable advice for improvement
11. one_thing_for_tomorrow — single most important focus for tomorrow
12. effectiveness_score — 1-10 rating of the day's effectiveness

Be specific, reference actual events, and provide genuinely useful coaching feedback.
Write in the user's language (Russian if the transcript is in Russian).
"""

MEETING_ANALYSIS_PROMPT = """\
You are an AI meeting analyst for LifeOS. Analyze this meeting transcript deeply.

Extract:
1. Summary — what was discussed
2. Key decisions — what was decided
3. Action items — who needs to do what, by when
4. Client/counterpart pain points — what problems were mentioned
5. Objections raised — any pushback or concerns
6. Interest signals — where was engagement highest
7. Energy drops — where attention was lost
8. Next steps — agreed follow-ups
9. Follow-up message draft — suggested follow-up email/message
10. Meeting improvement suggestions — how to make the next meeting better
11. Deal probability — if sales-related, estimated close probability

Respond in JSON format. Be specific and reference actual quotes.
"""

COACHING_PROMPT = """\
You are a personal effectiveness coach for LifeOS. Based on the day's events, provide evening coaching.

Analyze:
1. Where the user was most effective today
2. Where they were chaotic or unfocused
3. Where they over-promised
4. Missed follow-ups
5. Communication strengths observed
6. Moments of irritation, coldness, or insecurity
7. One habit to adjust tomorrow

Be direct, specific, and constructive. Reference actual events from the day.
Write in the user's language.
"""


class AIPipeline:
    """Orchestrates all AI processing: segmentation, extraction, summarization."""

    def __init__(self):
        self.client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
        self.model = settings.default_llm_model

    async def segment_events(
        self, transcript: str, session_start: datetime
    ) -> list[dict]:
        """Segment transcript into semantic events."""
        response = await self.client.messages.create(
            model=self.model,
            max_tokens=8192,
            system=SEGMENTATION_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": (
                        f"Session started at: {session_start.isoformat()}\n\n"
                        f"Transcript:\n{transcript}"
                    ),
                }
            ],
        )
        return self._parse_json_response(response.content[0].text)

    async def generate_daily_summary(self, events: list[dict], date: str) -> dict:
        """Generate comprehensive daily summary with coaching."""
        events_text = json.dumps(events, ensure_ascii=False, indent=2)
        response = await self.client.messages.create(
            model=self.model,
            max_tokens=4096,
            system=DAILY_SUMMARY_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": f"Date: {date}\n\nEvents:\n{events_text}",
                }
            ],
        )
        return self._parse_json_response(response.content[0].text)

    async def analyze_meeting(self, transcript: str, meeting_context: dict) -> dict:
        """Deep analysis of a specific meeting."""
        context_str = json.dumps(meeting_context, ensure_ascii=False)
        response = await self.client.messages.create(
            model=self.model,
            max_tokens=4096,
            system=MEETING_ANALYSIS_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": (
                        f"Meeting context: {context_str}\n\n"
                        f"Transcript:\n{transcript}"
                    ),
                }
            ],
        )
        return self._parse_json_response(response.content[0].text)

    async def generate_coaching(self, events: list[dict]) -> dict:
        """Generate personal coaching feedback."""
        events_text = json.dumps(events, ensure_ascii=False, indent=2)
        response = await self.client.messages.create(
            model=self.model,
            max_tokens=2048,
            system=COACHING_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": f"Today's events:\n{events_text}",
                }
            ],
        )
        return self._parse_json_response(response.content[0].text)

    async def semantic_search(self, query: str, context_docs: list[str]) -> str:
        """Answer user query against their personal memory."""
        docs_text = "\n\n---\n\n".join(context_docs)
        response = await self.client.messages.create(
            model=self.model,
            max_tokens=2048,
            system=(
                "You are LifeOS memory assistant. Answer the user's question based on their "
                "personal events, meetings, ideas, and conversations. Be specific, cite sources. "
                "If you don't have enough information, say so."
            ),
            messages=[
                {
                    "role": "user",
                    "content": (
                        f"My question: {query}\n\n"
                        f"Relevant memories:\n{docs_text}"
                    ),
                }
            ],
        )
        return response.content[0].text

    def _parse_json_response(self, text: str) -> dict | list:
        """Extract JSON from LLM response, handling markdown code blocks."""
        text = text.strip()
        if text.startswith("```"):
            lines = text.split("\n")
            # Remove first and last lines (```json and ```)
            json_lines = []
            in_block = False
            for line in lines:
                if line.startswith("```") and not in_block:
                    in_block = True
                    continue
                elif line.startswith("```") and in_block:
                    break
                elif in_block:
                    json_lines.append(line)
            text = "\n".join(json_lines)

        try:
            return json.loads(text)
        except json.JSONDecodeError:
            logger.warning("Failed to parse JSON from LLM response, returning as text")
            return {"raw_text": text}


ai_pipeline = AIPipeline()
