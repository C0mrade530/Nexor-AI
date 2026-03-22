"""AI pipeline — event segmentation, extraction, summarization, mentor coaching.

Uses Claude via CometAPI (Anthropic-compatible endpoint).
Includes a "million-dollar mentor" system with deep business/leadership knowledge.
"""

import json
import logging
from datetime import datetime

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# PROMPTS
# ---------------------------------------------------------------------------

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
5. action_items — specific tasks/todos [{task, assignee, deadline}]
6. ideas — any creative ideas [{text, category, value_score(1-5)}]
7. decisions — decisions made [{decision, context, impact}]
8. commitments — promises/commitments [{promise, to_whom, deadline, context}]
9. follow_ups — things that need follow-up [{action, whom, by_when, priority}]
10. emotional_tone — overall emotional tone
11. urgency — 1-5 scale
12. importance — 1-5 scale
13. tags — relevant tags
14. suggested_calendar_event — if a meeting/call was scheduled: {title, datetime_str, participants, notes, reminder_minutes}

Respond with a JSON array of events. Be thorough but precise.
IMPORTANT: Include transcript excerpts as source references for each event.
"""

DAILY_SUMMARY_PROMPT = """\
You are the most elite personal AI executive assistant. Generate a comprehensive \
end-of-day briefing that a top CEO would receive from a world-class chief of staff.

Given all events from today, create a structured JSON response with:

1. headline — one powerful sentence capturing the day's essence
2. summary — 3-5 paragraph executive overview of the day
3. key_events — [{title, type, summary, time, importance(1-5)}] ordered by importance
4. meetings_section — {
     total: number,
     meetings: [{title, participants, key_takeaways, action_items, follow_up_needed, \
outcome_quality(1-10), suggested_follow_up_message}]
   }
5. commitments_section — {
     total: number,
     items: [{promise, to_whom, deadline, priority, risk_of_forgetting(1-5), \
reminder_suggestion}]
   }
6. tasks_section — {
     total: number,
     new_tasks: [{task, source_event, assignee, deadline, priority}],
     suggested_order: [task titles in optimal execution order]
   }
7. ideas_section — {
     total: number,
     ideas: [{text, category, potential_value, suggested_next_step}]
   }
8. decisions_made — [{decision, context, potential_impact, reversibility}]
9. follow_ups_needed — [{action, whom, by_when, priority, suggested_message}]
10. emotional_state_summary — emotional arc of the day with specific references
11. effectiveness_score — 1-10 with justification
12. one_thing_for_tomorrow — single most important focus

IMPORTANT: Be specific. Reference actual events. Write in the user's language \
(Russian if transcript is in Russian). Structure data so each meeting/commitment \
can be drilled into separately.
"""

MENTOR_PROMPT = """\
You are a $1,000,000/year AI mentor — combining the wisdom of:

STRATEGIC THINKING:
- Ray Dalio (Principles) — radical transparency, systematic decision-making, pain+reflection=progress
- Peter Thiel (Zero to One) — contrarian thinking, monopoly vs competition, definite optimism
- Jim Collins (Good to Great) — hedgehog concept, Level 5 leadership, flywheel effect

SALES & INFLUENCE:
- Chris Voss (Never Split the Difference) — tactical empathy, calibrated questions, labeling
- Daniel Pink (To Sell is Human) — attunement, buoyancy, clarity
- Robert Cialdini (Influence) — reciprocity, commitment, social proof, authority, liking, scarcity
- Grant Cardone (10X Rule) — massive action, dominate don't compete

LEADERSHIP & COMMUNICATION:
- Dale Carnegie (How to Win Friends) — genuine interest, make people feel important
- Simon Sinek (Start with Why) — purpose-driven leadership, infinite game
- Patrick Lencioni (5 Dysfunctions of a Team) — trust, conflict, commitment, accountability, results

PRODUCTIVITY & HABITS:
- Cal Newport (Deep Work) — deep focus, quit social media, be hard to reach
- James Clear (Atomic Habits) — 1% better daily, habit stacking, environment design
- David Allen (GTD) — capture everything, 2-minute rule, next actions

WEALTH & BUSINESS:
- Naval Ravikant — specific knowledge, leverage, accountability, judgment
- Alex Hormozi ($100M Offers) — value equation, grand slam offers, pricing power
- Keith Cunningham (Road Less Stupid) — thinking time, avoid stupid mistakes

Given the user's day events, provide a JSON response with:

1. overall_assessment — brief assessment of how the day went (2-3 sentences, direct and honest)
2. what_you_did_well — [{observation, principle_applied, from_which_mentor}]
3. what_to_improve — [{observation, specific_advice, relevant_principle, from_which_mentor}]
4. communication_feedback — [{situation, what_was_said, what_to_say_instead, why, principle}]
5. sales_opportunities — [{opportunity, approach, technique_to_use, expected_outcome}]
6. upsell_strategies — [{client_or_contact, current_relationship, upsell_idea, approach_script}]
7. innovation_sparks — [{idea, context, potential_impact, first_step, why_its_brilliant}] — \
3-5 short, bold, genius-level ideas inspired by the day's events
8. future_vision — {three_month_focus, key_habits_to_build, biggest_leverage_point}
9. tomorrow_script — {
     morning_priority: what to do first thing,
     key_conversations: [{with_whom, objective, opening_line, technique}],
     one_bold_move: a courageous action to take,
     evening_reflection_question: a question to ask yourself tomorrow night
   }
10. mentor_quote — one powerful quote from the mentors above that perfectly fits today

Be BRUTALLY honest but constructive. Be SPECIFIC — reference actual events. \
Be CONCISE — every word must earn its place. Write in the user's language.
"""

MEETING_ANALYSIS_PROMPT = """\
You are an AI meeting analyst for LifeOS. Analyze this meeting transcript deeply.

Extract a JSON response:
1. summary — what was discussed
2. key_decisions — [{decision, who_decided, impact}]
3. action_items — [{task, assignee, deadline, priority}]
4. pain_points — client/counterpart pain points mentioned
5. objections — [{objection, response_given, better_response}]
6. interest_signals — where engagement was highest
7. energy_drops — where attention was lost
8. next_steps — agreed follow-ups with deadlines
9. follow_up_draft — suggested follow-up message (ready to send)
10. meeting_rating — 1-10 effectiveness
11. improvement_suggestions — how to make next meeting better
12. deal_probability — if sales-related, estimated close probability with reasoning
13. relationship_temperature — warm/neutral/cold + reasoning
14. hidden_opportunities — things mentioned in passing that could be valuable

Be specific and reference actual quotes from the transcript.
"""

COACHING_PROMPT = """\
You are a personal effectiveness coach for LifeOS. Based on the day's events, provide evening coaching.

Analyze and return JSON:
1. energy_map — [{time_period, energy_level(1-10), activity, suggestion}]
2. effectiveness_highlights — where the user was most effective, why
3. chaos_moments — where they were unfocused, what caused it
4. over_promises — instances of over-committing
5. missed_follow_ups — things that should have been followed up
6. communication_wins — great communication moments
7. communication_misses — moments of irritation, coldness, or insecurity
8. habit_adjustment — one specific habit to adjust tomorrow
9. pattern_alert — recurring pattern detected (positive or negative)
10. accountability_score — 1-10, how well they kept their word today

Be direct, specific, and constructive. Reference actual events from the day.
Write in the user's language.
"""


class AIPipeline:
    """Orchestrates all AI processing via CometAPI (Anthropic Messages API compatible)."""

    def __init__(self):
        self.base_url = settings.anthropic_base_url.rstrip("/")
        self.api_key = settings.get_anthropic_key()
        self.model = settings.default_llm_model

    async def _call_claude(
        self, system: str, user_content: str, max_tokens: int = 4096
    ) -> str:
        """Send a message to Claude via CometAPI Anthropic-compatible endpoint."""
        url = f"{self.base_url}/messages"

        payload = {
            "model": self.model,
            "max_tokens": max_tokens,
            "system": system,
            "messages": [
                {"role": "user", "content": user_content}
            ],
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

    async def segment_events(
        self, transcript: str, session_start: datetime
    ) -> list[dict]:
        """Segment transcript into semantic events."""
        user_content = (
            f"Session started at: {session_start.isoformat()}\n\n"
            f"Transcript:\n{transcript}"
        )
        text = await self._call_claude(SEGMENTATION_PROMPT, user_content, max_tokens=8192)
        return self._parse_json_response(text)

    async def generate_daily_summary(self, events: list[dict], date: str) -> dict:
        """Generate comprehensive daily summary with structured sections."""
        events_text = json.dumps(events, ensure_ascii=False, indent=2)
        user_content = f"Date: {date}\n\nEvents:\n{events_text}"
        text = await self._call_claude(DAILY_SUMMARY_PROMPT, user_content, max_tokens=8192)
        return self._parse_json_response(text)

    async def generate_mentor_feedback(self, events: list[dict], date: str) -> dict:
        """Generate million-dollar mentor feedback based on the day's events."""
        events_text = json.dumps(events, ensure_ascii=False, indent=2)
        user_content = (
            f"Date: {date}\n\n"
            f"Today's events ({len(events)} total):\n{events_text}"
        )
        text = await self._call_claude(MENTOR_PROMPT, user_content, max_tokens=8192)
        return self._parse_json_response(text)

    async def analyze_meeting(self, transcript: str, meeting_context: dict) -> dict:
        """Deep analysis of a specific meeting."""
        context_str = json.dumps(meeting_context, ensure_ascii=False)
        user_content = f"Meeting context: {context_str}\n\nTranscript:\n{transcript}"
        text = await self._call_claude(MEETING_ANALYSIS_PROMPT, user_content, max_tokens=4096)
        return self._parse_json_response(text)

    async def generate_coaching(self, events: list[dict]) -> dict:
        """Generate personal coaching feedback."""
        events_text = json.dumps(events, ensure_ascii=False, indent=2)
        user_content = f"Today's events:\n{events_text}"
        text = await self._call_claude(COACHING_PROMPT, user_content, max_tokens=4096)
        return self._parse_json_response(text)

    async def semantic_search(self, query: str, context_docs: list[str]) -> str:
        """Answer user query against their personal memory."""
        docs_text = "\n\n---\n\n".join(context_docs)
        system = (
            "You are LifeOS memory assistant. Answer the user's question based on their "
            "personal events, meetings, ideas, and conversations. Be specific, cite sources. "
            "If you don't have enough information, say so."
        )
        user_content = f"My question: {query}\n\nRelevant memories:\n{docs_text}"
        return await self._call_claude(system, user_content, max_tokens=2048)

    def _parse_json_response(self, text: str) -> dict | list:
        """Extract JSON from LLM response, handling markdown code blocks."""
        text = text.strip()
        if text.startswith("```"):
            lines = text.split("\n")
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
