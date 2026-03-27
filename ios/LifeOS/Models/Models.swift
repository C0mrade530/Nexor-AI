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
    let decisions: [FlexibleDict]?
    let commitments: [FlexibleDict]?
    let followUps: [FlexibleDict]?
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

/// Flexible dictionary that handles both string and non-string JSON values.
struct FlexibleDict: Codable {
    let values: [String: String]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: String].self) {
            values = dict
        } else if let anyDict = try? container.decode([String: AnyCodableValue].self) {
            values = anyDict.mapValues { $0.stringValue }
        } else {
            values = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    subscript(key: String) -> String? { values[key] }

    var firstValue: String? { values.values.first }
}

/// Helper for decoding mixed-type JSON values as strings.
struct AnyCodableValue: Codable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            stringValue = s
        } else if let i = try? container.decode(Int.self) {
            stringValue = "\(i)"
        } else if let d = try? container.decode(Double.self) {
            stringValue = "\(d)"
        } else if let b = try? container.decode(Bool.self) {
            stringValue = b ? "true" : "false"
        } else {
            stringValue = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }
}

struct ActionItem: Codable {
    let task: String
    let assignee: String?
    let deadline: String?
    let priority: String?
}

struct Idea: Codable {
    let text: String
    let category: String?
    let valueScore: Int?
    let potentialValue: String?
    let suggestedNextStep: String?

    enum CodingKeys: String, CodingKey {
        case text, category
        case valueScore = "value_score"
        case potentialValue = "potential_value"
        case suggestedNextStep = "suggested_next_step"
    }
}

struct CalendarSuggestion: Codable {
    let title: String
    let datetimeStr: String?
    let participants: [String]?
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

struct ActionItemEntry: Codable, Identifiable {
    var id: String { "\(eventId)-\(task)" }
    let eventId: String
    let eventTitle: String
    let task: String
    let assignee: String?
    let deadline: String?
    let priority: String?
    let eventDate: String?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case eventTitle = "event_title"
        case task, assignee, deadline, priority
        case eventDate = "event_date"
    }
}

// MARK: - Commitments

struct CommitmentsResponse: Codable {
    let commitments: [CommitmentEntry]
    let total: Int
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case commitments, total, page
        case pageSize = "page_size"
    }
}

struct CommitmentEntry: Codable, Identifiable {
    var id: String { "\(eventId)-\(promise)" }
    let eventId: String
    let eventTitle: String
    let eventDate: String?
    let promise: String
    let toWhom: String?
    let deadline: String?
    let context: String?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case eventTitle = "event_title"
        case eventDate = "event_date"
        case promise
        case toWhom = "to_whom"
        case deadline, context
    }
}

// MARK: - Follow-ups

struct FollowUpsResponse: Codable {
    let followUps: [FollowUpEntry]
    let total: Int

    enum CodingKeys: String, CodingKey {
        case followUps = "follow_ups"
        case total
    }
}

struct FollowUpEntry: Codable, Identifiable {
    var id: String { "\(eventId)-\(action)" }
    let eventId: String
    let eventTitle: String
    let action: String
    let whom: String?
    let byWhen: String?
    let priority: String?
    let eventDate: String?

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case eventTitle = "event_title"
        case action, whom
        case byWhen = "by_when"
        case priority
        case eventDate = "event_date"
    }
}

// MARK: - Daily Summary (enhanced)

struct DailySummary: Codable, Identifiable {
    let id: String
    let date: String
    let headline: String?
    let summary: String?
    let keyEvents: [FlexibleDict]?
    let keyIdeas: [FlexibleDict]?
    let keyDecisions: [FlexibleDict]?
    let newTasks: [FlexibleDict]?
    let commitmentsMade: [FlexibleDict]?
    let followUpsNeeded: [FlexibleDict]?
    let emotionalStateSummary: String?
    let coachingFeedback: String?
    let oneThingForTomorrow: String?
    let effectivenessScore: Double?
    let totalEvents: Int?
    let totalMeetings: Int?
    let totalIdeas: Int?
    let totalCommitments: Int?
    let totalTasks: Int?
    let totalRecordingMinutes: Double?
    // Structured sections from enhanced AI
    let meetingsSection: MeetingsSection?
    let commitmentsSection: CommitmentsSection?
    let tasksSection: TasksSection?
    let ideasSection: IdeasSection?
    let decisionsMade: [FlexibleDict]?
    // Mentor feedback
    let mentorFeedback: MentorFeedback?
    let coachingDetails: CoachingDetails?
    let createdAt: String?

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
        case totalCommitments = "total_commitments"
        case totalTasks = "total_tasks"
        case totalRecordingMinutes = "total_recording_minutes"
        case meetingsSection = "meetings_section"
        case commitmentsSection = "commitments_section"
        case tasksSection = "tasks_section"
        case ideasSection = "ideas_section"
        case decisionsMade = "decisions_made"
        case mentorFeedback = "mentor_feedback"
        case coachingDetails = "coaching_details"
        case createdAt = "created_at"
    }
}

// MARK: - Structured Summary Sections

struct MeetingsSection: Codable {
    let total: Int?
    let meetings: [MeetingSummaryItem]?
}

struct MeetingSummaryItem: Codable, Identifiable {
    var id: String { title ?? UUID().uuidString }
    let title: String?
    let participants: [String]?
    let keyTakeaways: [String]?
    let actionItems: [String]?
    let followUpNeeded: String?
    let outcomeQuality: Int?
    let suggestedFollowUpMessage: String?

    enum CodingKeys: String, CodingKey {
        case title, participants
        case keyTakeaways = "key_takeaways"
        case actionItems = "action_items"
        case followUpNeeded = "follow_up_needed"
        case outcomeQuality = "outcome_quality"
        case suggestedFollowUpMessage = "suggested_follow_up_message"
    }
}

struct CommitmentsSection: Codable {
    let total: Int?
    let items: [CommitmentSummaryItem]?
}

struct CommitmentSummaryItem: Codable, Identifiable {
    var id: String { promise ?? UUID().uuidString }
    let promise: String?
    let toWhom: String?
    let deadline: String?
    let priority: String?
    let riskOfForgetting: Int?
    let reminderSuggestion: String?

    enum CodingKeys: String, CodingKey {
        case promise
        case toWhom = "to_whom"
        case deadline, priority
        case riskOfForgetting = "risk_of_forgetting"
        case reminderSuggestion = "reminder_suggestion"
    }
}

struct TasksSection: Codable {
    let total: Int?
    let newTasks: [TaskSummaryItem]?
    let suggestedOrder: [String]?

    enum CodingKeys: String, CodingKey {
        case total
        case newTasks = "new_tasks"
        case suggestedOrder = "suggested_order"
    }
}

struct TaskSummaryItem: Codable, Identifiable {
    var id: String { task ?? UUID().uuidString }
    let task: String?
    let sourceEvent: String?
    let assignee: String?
    let deadline: String?
    let priority: String?

    enum CodingKeys: String, CodingKey {
        case task
        case sourceEvent = "source_event"
        case assignee, deadline, priority
    }
}

struct IdeasSection: Codable {
    let total: Int?
    let ideas: [IdeaSummaryItem]?
}

struct IdeaSummaryItem: Codable, Identifiable {
    var id: String { text ?? UUID().uuidString }
    let text: String?
    let category: String?
    let potentialValue: String?
    let suggestedNextStep: String?

    enum CodingKeys: String, CodingKey {
        case text, category
        case potentialValue = "potential_value"
        case suggestedNextStep = "suggested_next_step"
    }
}

// MARK: - Mentor Feedback

struct MentorFeedback: Codable {
    let overallAssessment: String?
    let whatYouDidWell: [MentorObservation]?
    let whatToImprove: [MentorImprovement]?
    let communicationFeedback: [CommunicationAdvice]?
    let salesOpportunities: [SalesOpportunity]?
    let upsellStrategies: [UpsellStrategy]?
    let innovationSparks: [InnovationIdea]?
    let futureVision: FutureVision?
    let tomorrowScript: TomorrowScript?
    let mentorQuote: String?

    enum CodingKeys: String, CodingKey {
        case overallAssessment = "overall_assessment"
        case whatYouDidWell = "what_you_did_well"
        case whatToImprove = "what_to_improve"
        case communicationFeedback = "communication_feedback"
        case salesOpportunities = "sales_opportunities"
        case upsellStrategies = "upsell_strategies"
        case innovationSparks = "innovation_sparks"
        case futureVision = "future_vision"
        case tomorrowScript = "tomorrow_script"
        case mentorQuote = "mentor_quote"
    }
}

struct MentorObservation: Codable, Identifiable {
    var id: String { observation ?? UUID().uuidString }
    let observation: String?
    let principleApplied: String?
    let fromWhichMentor: String?

    enum CodingKeys: String, CodingKey {
        case observation
        case principleApplied = "principle_applied"
        case fromWhichMentor = "from_which_mentor"
    }
}

struct MentorImprovement: Codable, Identifiable {
    var id: String { observation ?? UUID().uuidString }
    let observation: String?
    let specificAdvice: String?
    let relevantPrinciple: String?
    let fromWhichMentor: String?

    enum CodingKeys: String, CodingKey {
        case observation
        case specificAdvice = "specific_advice"
        case relevantPrinciple = "relevant_principle"
        case fromWhichMentor = "from_which_mentor"
    }
}

struct CommunicationAdvice: Codable, Identifiable {
    var id: String { situation ?? UUID().uuidString }
    let situation: String?
    let whatWasSaid: String?
    let whatToSayInstead: String?
    let why: String?
    let principle: String?

    enum CodingKeys: String, CodingKey {
        case situation
        case whatWasSaid = "what_was_said"
        case whatToSayInstead = "what_to_say_instead"
        case why, principle
    }
}

struct SalesOpportunity: Codable, Identifiable {
    var id: String { opportunity ?? UUID().uuidString }
    let opportunity: String?
    let approach: String?
    let techniqueToUse: String?
    let expectedOutcome: String?

    enum CodingKeys: String, CodingKey {
        case opportunity, approach
        case techniqueToUse = "technique_to_use"
        case expectedOutcome = "expected_outcome"
    }
}

struct UpsellStrategy: Codable, Identifiable {
    var id: String { clientOrContact ?? UUID().uuidString }
    let clientOrContact: String?
    let currentRelationship: String?
    let upsellIdea: String?
    let approachScript: String?

    enum CodingKeys: String, CodingKey {
        case clientOrContact = "client_or_contact"
        case currentRelationship = "current_relationship"
        case upsellIdea = "upsell_idea"
        case approachScript = "approach_script"
    }
}

struct InnovationIdea: Codable, Identifiable {
    var id: String { idea ?? UUID().uuidString }
    let idea: String?
    let context: String?
    let potentialImpact: String?
    let firstStep: String?
    let whyItsBrilliant: String?

    enum CodingKeys: String, CodingKey {
        case idea, context
        case potentialImpact = "potential_impact"
        case firstStep = "first_step"
        case whyItsBrilliant = "why_its_brilliant"
    }
}

struct FutureVision: Codable {
    let threeMonthFocus: String?
    let keyHabitsToBuild: [String]?
    let biggestLeveragePoint: String?

    enum CodingKeys: String, CodingKey {
        case threeMonthFocus = "three_month_focus"
        case keyHabitsToBuild = "key_habits_to_build"
        case biggestLeveragePoint = "biggest_leverage_point"
    }
}

struct TomorrowScript: Codable {
    let morningPriority: String?
    let keyConversations: [KeyConversation]?
    let oneBoldMove: String?
    let eveningReflectionQuestion: String?

    enum CodingKeys: String, CodingKey {
        case morningPriority = "morning_priority"
        case keyConversations = "key_conversations"
        case oneBoldMove = "one_bold_move"
        case eveningReflectionQuestion = "evening_reflection_question"
    }
}

struct KeyConversation: Codable, Identifiable {
    var id: String { withWhom ?? UUID().uuidString }
    let withWhom: String?
    let objective: String?
    let openingLine: String?
    let technique: String?

    enum CodingKeys: String, CodingKey {
        case withWhom = "with_whom"
        case objective
        case openingLine = "opening_line"
        case technique
    }
}

// MARK: - Coaching Details

struct CoachingDetails: Codable {
    let energyMap: [FlexibleDict]?
    let effectivenessHighlights: String?
    let chaosMoments: String?
    let overPromises: String?
    let missedFollowUps: String?
    let communicationWins: String?
    let communicationMisses: String?
    let habitAdjustment: String?
    let patternAlert: String?
    let accountabilityScore: Int?

    enum CodingKeys: String, CodingKey {
        case energyMap = "energy_map"
        case effectivenessHighlights = "effectiveness_highlights"
        case chaosMoments = "chaos_moments"
        case overPromises = "over_promises"
        case missedFollowUps = "missed_follow_ups"
        case communicationWins = "communication_wins"
        case communicationMisses = "communication_misses"
        case habitAdjustment = "habit_adjustment"
        case patternAlert = "pattern_alert"
        case accountabilityScore = "accountability_score"
    }
}

// MARK: - Meeting Analysis

struct MeetingAnalysis: Codable {
    let eventId: String
    let analysis: MeetingAnalysisData

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case analysis
    }
}

struct MeetingAnalysisData: Codable {
    let summary: String?
    let keyDecisions: [FlexibleDict]?
    let actionItems: [FlexibleDict]?
    let painPoints: [String]?
    let objections: [FlexibleDict]?
    let interestSignals: String?
    let energyDrops: String?
    let nextSteps: [String]?
    let followUpDraft: String?
    let meetingRating: Int?
    let improvementSuggestions: [String]?
    let dealProbability: String?
    let relationshipTemperature: String?
    let hiddenOpportunities: [String]?

    enum CodingKeys: String, CodingKey {
        case summary
        case keyDecisions = "key_decisions"
        case actionItems = "action_items"
        case painPoints = "pain_points"
        case objections
        case interestSignals = "interest_signals"
        case energyDrops = "energy_drops"
        case nextSteps = "next_steps"
        case followUpDraft = "follow_up_draft"
        case meetingRating = "meeting_rating"
        case improvementSuggestions = "improvement_suggestions"
        case dealProbability = "deal_probability"
        case relationshipTemperature = "relationship_temperature"
        case hiddenOpportunities = "hidden_opportunities"
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

// MARK: - Calendar

struct CalendarStatus: Codable {
    let connected: Bool
    let userId: String

    enum CodingKeys: String, CodingKey {
        case connected
        case userId = "user_id"
    }
}

// MARK: - Plaud NotePin

struct PlaudStatus: Codable {
    let connected: Bool
    let region: String?
}

struct PlaudRecording: Codable, Identifiable {
    let id: String
    let filename: String?
    let durationSeconds: Double?
    let filesize: Int?
    let createdAt: String?
    let hasTranscription: Bool?
    let hasSummary: Bool?
    let synced: Bool?

    enum CodingKeys: String, CodingKey {
        case id, filename, filesize, synced
        case durationSeconds = "duration_seconds"
        case createdAt = "created_at"
        case hasTranscription = "has_transcription"
        case hasSummary = "has_summary"
    }
}

struct PlaudRecordingsResponse: Codable {
    let recordings: [PlaudRecording]
    let total: Int
}

struct PlaudSyncResult: Codable {
    let totalAvailable: Int?
    let alreadySynced: Int?
    let newlySynced: Int?
    let failed: Int?

    enum CodingKeys: String, CodingKey {
        case totalAvailable = "total_available"
        case alreadySynced = "already_synced"
        case newlySynced = "newly_synced"
        case failed
    }
}

struct PlaudSyncOneResult: Codable {
    let sessionId: String?
    let plaudFileId: String?
    let filename: String?
    let sizeBytes: Int?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case plaudFileId = "plaud_file_id"
        case filename
        case sizeBytes = "size_bytes"
    }
}

// MARK: - Health & Wellness

struct HealthTodaySnapshot: Codable {
    let available: Bool
    let date: String?
    let sleepHours: Double?
    let sleepQuality: Int?
    let steps: Int?
    let activeMinutes: Int?
    let activeCalories: Int?
    let restingHr: Int?
    let hrv: Int?
    let workoutsCount: Int?
    let energyScore: Int?

    enum CodingKeys: String, CodingKey {
        case available, date, steps, hrv
        case sleepHours = "sleep_hours"
        case sleepQuality = "sleep_quality"
        case activeMinutes = "active_minutes"
        case activeCalories = "active_calories"
        case restingHr = "resting_hr"
        case workoutsCount = "workouts_count"
        case energyScore = "energy_score"
    }
}

struct HealthGoalProgress: Codable {
    let available: Bool
    let sleep: GoalItem?
    let steps: GoalItem?
    let activeMinutes: GoalItem?
    let overallPercent: Int?

    enum CodingKeys: String, CodingKey {
        case available, sleep, steps
        case activeMinutes = "active_minutes"
        case overallPercent = "overall_percent"
    }
}

struct GoalItem: Codable {
    let current: Double?
    let goal: Double?
    let percent: Int?
}

struct HealthWeeklyTrends: Codable {
    let available: Bool
    let daysTracked: Int?
    let avgSleepHours: Double?
    let avgSteps: Int?
    let avgActiveMinutes: Int?
    let avgHrv: Int?
    let workoutDays: Int?
    let sleepTrend: String?
    let stepsTrend: String?
    let hrvTrend: String?

    enum CodingKeys: String, CodingKey {
        case available
        case daysTracked = "days_tracked"
        case avgSleepHours = "avg_sleep_hours"
        case avgSteps = "avg_steps"
        case avgActiveMinutes = "avg_active_minutes"
        case avgHrv = "avg_hrv"
        case workoutDays = "workout_days"
        case sleepTrend = "sleep_trend"
        case stepsTrend = "steps_trend"
        case hrvTrend = "hrv_trend"
    }
}

// MARK: - Finance

struct FinanceMonthlySummary: Codable {
    let month: String?
    let income: Double?
    let expenses: Double?
    let net: Double?
    let savingsRate: Double?
    let byCategory: [CategorySpend]?
    let transactionCount: Int?

    enum CodingKeys: String, CodingKey {
        case month, income, expenses, net
        case savingsRate = "savings_rate"
        case byCategory = "by_category"
        case transactionCount = "transaction_count"
    }
}

struct CategorySpend: Codable, Identifiable {
    var id: String { category }
    let category: String
    let amount: Double
}

struct FinanceTransaction: Codable, Identifiable {
    let id: String
    let date: String?
    let description: String?
    let amount: Double?
    let category: String?
    let account: String?
}

// MARK: - Telegram

struct TelegramStatus: Codable {
    let configured: Bool
    let linked: Bool
    let chatId: Int?
    let enabled: Bool
    let reminders: Bool
    let dailySummary: Bool

    enum CodingKeys: String, CodingKey {
        case configured, linked, enabled, reminders
        case chatId = "chat_id"
        case dailySummary = "daily_summary"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configured = (try? container.decode(Bool.self, forKey: .configured)) ?? false
        linked = (try? container.decode(Bool.self, forKey: .linked)) ?? false
        chatId = try? container.decode(Int.self, forKey: .chatId)
        enabled = (try? container.decode(Bool.self, forKey: .enabled)) ?? false
        reminders = (try? container.decode(Bool.self, forKey: .reminders)) ?? true
        dailySummary = (try? container.decode(Bool.self, forKey: .dailySummary)) ?? true
    }
}

struct TelegramLinkResponse: Codable {
    let linked: Bool
    let userId: String?
    let chatId: Int?

    enum CodingKeys: String, CodingKey {
        case linked
        case userId = "user_id"
        case chatId = "chat_id"
    }
}

// MARK: - Notifications

struct NotificationPreferences: Codable {
    let dailySummaryReminder: Bool?
    let dailySummaryTime: String?
    let commitmentReminders: Bool?
    let followUpReminders: Bool?
    let healthNudges: Bool?
    let financeAlerts: Bool?

    enum CodingKeys: String, CodingKey {
        case dailySummaryReminder = "daily_summary_reminder"
        case dailySummaryTime = "daily_summary_time"
        case commitmentReminders = "commitment_reminders"
        case followUpReminders = "follow_up_reminders"
        case healthNudges = "health_nudges"
        case financeAlerts = "finance_alerts"
    }
}

// MARK: - Health Dashboard (Athlytic-style)

struct HealthDashboard: Codable {
    let available: Bool
    let date: String?
    let recovery: RecoveryAnalysis?
    let battery: BatteryReadiness?
    let sleep: SleepAnalysis?
    let strain: StrainTracking?
    let hrv: HRVAnalysis?
    let snapshot: HealthTodaySnapshot?
    let goals: HealthGoalProgress?
    let trends: HealthWeeklyTrends?
}

struct RecoveryAnalysis: Codable {
    let available: Bool
    let recoveryScore: Int
    let zone: String
    let zoneLabel: String
    let recommendation: String

    enum CodingKeys: String, CodingKey {
        case available
        case recoveryScore = "recovery_score"
        case zone
        case zoneLabel = "zone_label"
        case recommendation
    }
}

struct BatteryReadiness: Codable {
    let available: Bool
    let batteryStart: Int
    let batteryRemaining: Int
    let batteryUsed: Int
    let strainToday: Int
    let capacity: String
    let advice: String

    enum CodingKeys: String, CodingKey {
        case available
        case batteryStart = "battery_start"
        case batteryRemaining = "battery_remaining"
        case batteryUsed = "battery_used"
        case strainToday = "strain_today"
        case capacity, advice
    }
}

struct SleepAnalysis: Codable {
    let available: Bool
    let score: Int
    let totalHours: Double
    let stages: SleepStages?
    let bedTime: String?
    let wakeTime: String?
    let consistency: Int
    let avgSleep7d: Double
    let insights: [SleepInsight]?

    enum CodingKeys: String, CodingKey {
        case available, score, stages, insights, consistency
        case totalHours = "total_hours"
        case bedTime = "bed_time"
        case wakeTime = "wake_time"
        case avgSleep7d = "avg_sleep_7d"
    }
}

struct SleepStages: Codable {
    let deep: SleepStage
    let rem: SleepStage
    let light: SleepStage
}

struct SleepStage: Codable {
    let hours: Double
    let percent: Double
    let idealRange: String

    enum CodingKeys: String, CodingKey {
        case hours, percent
        case idealRange = "ideal_range"
    }
}

struct SleepInsight: Codable {
    let type: String
    let text: String
}

struct StrainTracking: Codable {
    let available: Bool
    let strainScore: Int
    let strainStatus: String
    let strainAdvice: String
    let steps: Int
    let activeCalories: Int
    let activeMinutes: Int
    let workouts: [WorkoutStrain]

    enum CodingKeys: String, CodingKey {
        case available, steps, workouts
        case strainScore = "strain_score"
        case strainStatus = "strain_status"
        case strainAdvice = "strain_advice"
        case activeCalories = "active_calories"
        case activeMinutes = "active_minutes"
    }
}

struct WorkoutStrain: Codable {
    let type: String
    let durationMinutes: Int
    let calories: Int
    let strain: Int

    enum CodingKeys: String, CodingKey {
        case type, calories, strain
        case durationMinutes = "duration_minutes"
    }
}

struct HRVAnalysis: Codable {
    let available: Bool
    let current: Int
    let baseline: Double
    let high30d: Int
    let low30d: Int
    let cv: Double
    let status: String
    let interpretation: String
    let trend7d: String?
    let trend30d: String?
    let history: [HRVPoint]

    enum CodingKeys: String, CodingKey {
        case available, current, baseline, status, interpretation, history
        case high30d = "high_30d"
        case low30d = "low_30d"
        case cv = "coefficient_of_variation"
        case trend7d = "trend_7d"
        case trend30d = "trend_30d"
    }
}

struct HRVPoint: Codable {
    let date: String
    let hrv: Int
}

// MARK: - Mentor Chat

struct ChatMessage: Codable, Identifiable {
    let id: String
    let role: String
    let content: String
    let timestamp: String?
}

struct ChatResponse: Codable {
    let message: ChatMessage?
    let totalMessages: Int?

    enum CodingKeys: String, CodingKey {
        case message
        case totalMessages = "total_messages"
    }
}

struct ChatHistory: Codable {
    let messages: [ChatMessage]
    let total: Int
    let hasMore: Bool?

    enum CodingKeys: String, CodingKey {
        case messages, total
        case hasMore = "has_more"
    }
}

struct MentorInsight: Codable {
    let insight: String?
    let generatedAt: String?

    enum CodingKeys: String, CodingKey {
        case insight
        case generatedAt = "generated_at"
    }
}
