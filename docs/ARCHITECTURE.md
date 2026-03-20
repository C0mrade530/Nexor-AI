# LifeOS — System Architecture

## Overview

LifeOS is an AI wearable memory assistant that records daily audio, transcribes and
segments it into semantic events, and generates actionable intelligence (summaries,
ideas, tasks, coaching).

```
┌─────────────┐     ┌──────────────┐     ┌───────────────────────────────────┐
│  Wearable   │────▶│  iPhone App  │────▶│         Cloud Backend             │
│  Device     │ BLE │              │HTTPS│                                   │
│  (Phase 2)  │     │  - Record    │     │  ┌─────────┐  ┌───────────────┐  │
└─────────────┘     │  - Sync      │     │  │ FastAPI  │  │ Transcription │  │
                    │  - View      │     │  │ Gateway  │──│ Worker        │  │
                    │  - Search    │     │  └────┬─────┘  └───────┬───────┘  │
                    └──────────────┘     │       │                │          │
                                        │  ┌────▼────────────────▼───────┐  │
                                        │  │     AI Pipeline (Claude)    │  │
                                        │  │  - Event Segmentation      │  │
                                        │  │  - Structured Extraction   │  │
                                        │  │  - Daily Summary           │  │
                                        │  │  - Meeting Analysis        │  │
                                        │  │  - Coaching                │  │
                                        │  └────────────┬───────────────┘  │
                                        │               │                  │
                                        │  ┌────────────▼───────────────┐  │
                                        │  │   Storage & Memory         │  │
                                        │  │  - PostgreSQL (events)     │  │
                                        │  │  - S3/local (audio)        │  │
                                        │  │  - ChromaDB (vectors)      │  │
                                        │  └────────────────────────────┘  │
                                        └───────────────────────────────────┘
```

## Data Flow

```
Audio Input → Chunking (5 min) → Upload → Transcription (Whisper/Deepgram)
    → Event Segmentation (Claude) → Structured Extraction (JSON)
    → Vector Indexing (ChromaDB) → Storage (PostgreSQL)
    → Daily Summary → Coaching Feedback → Push to iPhone
```

## Backend Services

| Service | Responsibility |
|---------|---------------|
| `api/v1/audio` | Audio session management, chunk upload |
| `api/v1/events` | Event CRUD, filtering by type/date/tags |
| `api/v1/search` | Semantic memory search (NL queries) |
| `api/v1/process` | Trigger AI pipeline on sessions |
| `services/transcription` | Whisper/Deepgram STT |
| `services/ai_pipeline` | Claude-powered segmentation, extraction, coaching |
| `services/memory` | ChromaDB vector indexing and retrieval |
| `services/processing` | Orchestrator tying pipeline together |

## Data Model

### Core Entities

- **User** — account with privacy preferences
- **AudioSession** — continuous recording period
- **AudioChunk** — 5-min segment within a session
- **Event** — semantic scene (meeting, idea, task, commitment...)
- **DailySummary** — AI-generated daily report with coaching

### Event Types

| Type | Description |
|------|-------------|
| `meeting` | Structured conversation with others |
| `idea` | Creative thought or concept |
| `task` | Action item or todo |
| `commitment` | Promise made to someone |
| `personal_thought` | Reflection, thinking out loud |
| `planning` | Scheduling, organizing |
| `sales_call` | Sales-related conversation |
| `follow_up` | Something needing follow-up |
| `decision` | Clear decision being made |

### Event Extraction Schema

Each event produces structured JSON:
```json
{
  "title": "string",
  "event_type": "meeting|idea|task|...",
  "summary": "string",
  "participants": ["name1", "name2"],
  "action_items": [{"task": "...", "assignee": "...", "deadline": "..."}],
  "ideas": [{"text": "...", "category": "content|startup|sales|personal"}],
  "decisions": [{"decision": "...", "context": "..."}],
  "commitments": [{"promise": "...", "by": "...", "to": "..."}],
  "follow_ups": [{"action": "...", "deadline": "..."}],
  "emotional_tone": "positive|negative|neutral|excited|stressed",
  "urgency": 1-5,
  "importance": 1-5,
  "tags": ["tag1", "tag2"],
  "suggested_calendar_event": {
    "title": "...", "datetime": "...", "participants": [...], "notes": "..."
  },
  "transcript_excerpt": "source reference"
}
```

## Privacy Model

| Setting | Options | Default |
|---------|---------|---------|
| Audio retention | keep_all, after_transcription, summaries_only | after_transcription |
| Retention period | 1-365 days | 30 days |
| Encryption at rest | on/off | on |
| Consent mode | private, meeting, public | private |
| Data export | full export available | — |
| Data deletion | per-event, per-day, full account | — |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend API | Python 3.12 + FastAPI |
| Database | PostgreSQL 16 |
| Cache/Queue | Redis 7 |
| Vector DB | ChromaDB |
| Transcription | OpenAI Whisper / Deepgram |
| AI/LLM | Claude API (Anthropic) |
| File Storage | Local / S3 |
| iOS App | Swift + SwiftUI |
| Containers | Docker + Docker Compose |

## API Endpoints

### Audio
- `POST /api/v1/audio/sessions` — create recording session
- `POST /api/v1/audio/sessions/{id}/chunks` — upload audio chunk
- `POST /api/v1/audio/sessions/{id}/finish` — finish session
- `GET /api/v1/audio/sessions` — list sessions
- `DELETE /api/v1/audio/sessions/{id}` — delete session + audio

### Events
- `GET /api/v1/events` — list with filters (type, date, tags)
- `GET /api/v1/events/ideas` — ideas feed
- `GET /api/v1/events/meetings` — meetings feed
- `GET /api/v1/events/tasks` — action items
- `GET /api/v1/events/{id}` — event detail
- `DELETE /api/v1/events/{id}` — delete event

### Summaries
- `GET /api/v1/events/summaries/daily` — recent summaries
- `GET /api/v1/events/summaries/daily/{date}` — specific date

### Search
- `GET /api/v1/search?q=...` — natural language memory search

### Processing
- `POST /api/v1/process/session/{id}` — trigger AI pipeline
- `POST /api/v1/process/daily-summary` — generate daily summary
