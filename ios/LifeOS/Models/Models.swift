import Foundation

// MARK: - Audio

struct AudioSession: Codable, Identifiable {
    let id: String
    let userId: String?
    let startedAt: Date
    let endedAt: Date?
    let durationSeconds: Double?
    let source: String
    let consentMode: String
    let status: String
    let environmentTag: String?
    let locationLabel: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case source
        case consentMode = "consent_mode"
        case status
        case environmentTag = "environment_tag"
        case locationLabel = "location_label"
        case createdAt = "created_at"
    }
}

struct AudioChunkResponse: Codable {
    let id: String
    let sessionId: String
    let chunkIndex: Int
    let durationSeconds: Double
    let status: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case chunkIndex = "chunk_index"
        case durationSeconds = "duration_seconds"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - Events

struct Event: Codable, Identifiable {
    let id: String
    let eventType: String
    let title: String
    let summary: String
    let startedAt: Date
    let endedAt: Date?
    let durationSeconds: Double?
    let participants: [String]?
    let actionItems: [ActionItem]?
    let ideas: [Idea]?
    let decisions: [[String: String]]?
    let commitments: [[String: String]]?
    let followUps: [[String: String]]?
    let emotionalTone: String?
    let urgency: Int?
    let importance: Int?
    let tags: [String]?
    let confidenceScore: Double?
    let suggestedCalendarEvent: CalendarSuggestion?
    let transcriptExcerpt: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case eventType = "event_type"
        case title, summary
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationSeconds = "duration_seconds"
        case participants
        case actionItems = "action_items"
        case ideas, decisions, commitments
        case followUps = "follow_ups"
        case emotionalTone = "emotional_tone"
        case urgency, importance, tags
        case confidenceScore = "confidence_score"
        case suggestedCalendarEvent = "suggested_calendar_event"
        case transcriptExcerpt = "transcript_excerpt"
        case createdAt = "created_at"
    }
}

struct ActionItem: Codable {
    let task: String
    let assignee: String?
    let deadline: String?
}

struct Idea: Codable {
    let text: String
    let category: String?
    let valueScore: Int?

    enum CodingKeys: String, CodingKey {
        case text, category
        case valueScore = "value_score"
    }
}

struct CalendarSuggestion: Codable {
    let title: String
    let datetimeStr: String?
    let participants: [String]
    let notes: String?
    let reminderMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case datetimeStr = "datetime_str"
        case participants, notes
        case reminderMinutes = "reminder_minutes"
    }
}

struct EventListResponse: Codable {
    let events: [Event]
    let total: Int
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case events, total, page
        case pageSize = "page_size"
    }
}

struct ActionItemsResponse: Codable {
    let actionItems: [ActionItemEntry]
    let total: Int

    enum CodingKeys: String, CodingKey {
        case actionItems = "action_items"
        case total
    }
}

struct ActionItemEntry: Codable {
    let eventId: String
    let eventTitle: String
    let task: String
    let assignee: String?
    let deadline: String?
    let eventDate: String?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case eventTitle = "event_title"
        case task, assignee, deadline
        case eventDate = "event_date"
    }
}

// MARK: - Daily Summary

struct DailySummary: Codable, Identifiable {
    let id: String
    let date: Date
    let headline: String
    let summary: String
    let keyEvents: [[String: String]]?
    let keyIdeas: [[String: String]]?
    let keyDecisions: [[String: String]]?
    let newTasks: [[String: String]]?
    let commitmentsMade: [[String: String]]?
    let followUpsNeeded: [[String: String]]?
    let emotionalStateSummary: String?
    let coachingFeedback: String?
    let oneThingForTomorrow: String?
    let effectivenessScore: Double?
    let totalEvents: Int?
    let totalMeetings: Int?
    let totalIdeas: Int?
    let totalRecordingMinutes: Double?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, date, headline, summary
        case keyEvents = "key_events"
        case keyIdeas = "key_ideas"
        case keyDecisions = "key_decisions"
        case newTasks = "new_tasks"
        case commitmentsMade = "commitments_made"
        case followUpsNeeded = "follow_ups_needed"
        case emotionalStateSummary = "emotional_state_summary"
        case coachingFeedback = "coaching_feedback"
        case oneThingForTomorrow = "one_thing_for_tomorrow"
        case effectivenessScore = "effectiveness_score"
        case totalEvents = "total_events"
        case totalMeetings = "total_meetings"
        case totalIdeas = "total_ideas"
        case totalRecordingMinutes = "total_recording_minutes"
        case createdAt = "created_at"
    }
}

// MARK: - Search

struct SearchResponse: Codable {
    let query: String
    let answer: String
}

// MARK: - Processing

struct ProcessingResult: Codable {
    let sessionId: String
    let chunksProcessed: Int
    let eventsExtracted: Int

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case chunksProcessed = "chunks_processed"
        case eventsExtracted = "events_extracted"
    }
}
