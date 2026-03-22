"""Shared in-memory store for MVP — replaces database in dev mode.

All API routes read/write from these dicts.
In production, replace with SQLAlchemy queries.
"""

# Audio sessions: {session_id: dict}
sessions: dict[str, dict] = {}

# Audio chunks per session: {session_id: [chunk_dict, ...]}
chunks: dict[str, list[dict]] = {}

# Extracted events: {event_id: dict}
events: dict[str, dict] = {}

# Daily summaries: {date_string: dict}
daily_summaries: dict[str, dict] = {}

# Mentor feedback: {date_string: dict}
mentor_feedback: dict[str, dict] = {}

# Google Calendar tokens: {user_id: {access_token, refresh_token, ...}}
calendar_tokens: dict[str, dict] = {}
