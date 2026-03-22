import Foundation

/// Nexor API client for communicating with the backend.
class APIClient {
    static let shared = APIClient()

    private var baseURLString: String
    private let session: URLSession
    private var authToken: String?

    init(baseURL: String = "http://localhost:8000/api/v1") {
        self.baseURLString = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    func updateBaseURL(_ url: String) {
        baseURLString = url
    }

    func setAuthToken(_ token: String) {
        authToken = token
    }

    // MARK: - Audio Sessions

    func createSession(source: String = "iphone_app", consentMode: String = "private") async throws -> AudioSession {
        let body: [String: Any] = [
            "source": source,
            "consent_mode": consentMode,
            "started_at": ISO8601DateFormatter().string(from: Date())
        ]
        return try await post("/audio/sessions", body: body)
    }

    func uploadChunk(sessionId: String, audioData: Data, filename: String = "chunk.wav") async throws -> AudioChunkResponse {
        guard let url = URL(string: "\(baseURLString)/audio/sessions/\(sessionId)/chunks") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeader(&request)

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AudioChunkResponse.self, from: data)
    }

    func finishSession(sessionId: String) async throws -> AudioSession {
        let body: [String: Any] = [
            "ended_at": ISO8601DateFormatter().string(from: Date())
        ]
        return try await post("/audio/sessions/\(sessionId)/finish", body: body)
    }

    func listSessions(limit: Int = 20) async throws -> [AudioSession] {
        return try await get("/audio/sessions?limit=\(limit)")
    }

    func deleteSession(sessionId: String) async throws {
        let _: EmptyResponse = try await delete("/audio/sessions/\(sessionId)")
    }

    // MARK: - Events

    func getEvents(type: String? = nil, page: Int = 1) async throws -> EventListResponse {
        var path = "/events?page=\(page)"
        if let type = type { path += "&event_type=\(type)" }
        return try await get(path)
    }

    func getIdeas(category: String? = nil) async throws -> EventListResponse {
        var path = "/events/ideas"
        if let category = category { path += "?category=\(category)" }
        return try await get(path)
    }

    func getMeetings() async throws -> EventListResponse {
        return try await get("/events/meetings")
    }

    func getActionItems() async throws -> ActionItemsResponse {
        return try await get("/events/tasks")
    }

    func getEvent(id: String) async throws -> Event {
        return try await get("/events/\(id)")
    }

    func deleteEvent(id: String) async throws {
        let _: EmptyResponse = try await delete("/events/\(id)")
    }

    // MARK: - Search

    func searchMemory(query: String) async throws -> SearchResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await get("/search?q=\(encoded)")
    }

    // MARK: - Daily Summary

    func getDailySummaries(limit: Int = 7) async throws -> [DailySummary] {
        return try await get("/events/summaries/daily?limit=\(limit)")
    }

    func getDailySummary(date: String) async throws -> DailySummary {
        return try await get("/events/summaries/daily/\(date)")
    }

    // MARK: - Commitments & Follow-ups

    func getCommitments() async throws -> CommitmentsResponse {
        return try await get("/events/commitments")
    }

    func getFollowUps() async throws -> FollowUpsResponse {
        return try await get("/events/follow-ups")
    }

    // MARK: - Meeting Analysis

    func getMeetingAnalysis(eventId: String) async throws -> MeetingAnalysis {
        return try await get("/events/meetings/\(eventId)/analysis")
    }

    // MARK: - Mentor

    func getMentorFeedback(date: String) async throws -> MentorFeedback {
        return try await get("/process/mentor/\(date)")
    }

    func generateMentorFeedback(date: String) async throws -> MentorFeedback {
        return try await post("/process/mentor/\(date)", body: [:])
    }

    // MARK: - Calendar

    func getCalendarStatus() async throws -> CalendarStatus {
        return try await get("/calendar/status")
    }

    func connectCalendar(accessToken: String) async throws -> EmptyResponse {
        return try await post("/calendar/connect", body: [
            "access_token": accessToken
        ])
    }

    func syncMeetingsToCalendar(date: String? = nil) async throws -> EmptyResponse {
        var body: [String: Any] = [:]
        if let date = date { body["date"] = date }
        return try await post("/calendar/sync/meetings", body: body)
    }

    func syncTasksToCalendar(date: String? = nil) async throws -> EmptyResponse {
        var body: [String: Any] = [:]
        if let date = date { body["date"] = date }
        return try await post("/calendar/sync/tasks", body: body)
    }

    // MARK: - Processing

    func processSession(sessionId: String) async throws -> ProcessingResult {
        return try await post("/process/session/\(sessionId)", body: [:])
    }

    func generateDailySummary(date: String? = nil) async throws -> DailySummary {
        var path = "/process/daily-summary"
        if let date = date { path += "?date=\(date)" }
        return try await post(path, body: [:])
    }

    // MARK: - Health & HealthKit

    func getHealthToday() async throws -> HealthTodaySnapshot {
        return try await get("/health/today")
    }

    func getHealthTrends() async throws -> HealthWeeklyTrends {
        return try await get("/health/trends")
    }

    func getHealthProgress() async throws -> HealthGoalProgress {
        return try await get("/health/progress")
    }

    func setHealthGoals(_ goals: [String: Any]) async throws -> EmptyResponse {
        return try await post("/health/goals", body: goals)
    }

    // MARK: - Finance

    func getFinanceSummary(month: String? = nil) async throws -> FinanceMonthlySummary {
        var path = "/finance/summary"
        if let month = month { path += "?month=\(month)" }
        return try await get(path)
    }

    func addTransactions(_ transactions: [[String: Any]]) async throws -> EmptyResponse {
        return try await post("/finance/transactions", body: ["transactions": transactions])
    }

    func analyzeSpending(month: String? = nil) async throws -> [String: Any] {
        var path = "/finance/analyze"
        if let month = month { path += "?month=\(month)" }

        guard let url = URL(string: "\(baseURLString)\(path)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuthHeader(&request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    // MARK: - Notifications

    func getNotificationPrefs() async throws -> NotificationPreferences {
        return try await get("/notifications/preferences")
    }

    func setNotificationPrefs(_ prefs: [String: Any]) async throws -> EmptyResponse {
        return try await post("/notifications/preferences", body: prefs)
    }

    func checkReminders() async throws -> EmptyResponse {
        return try await post("/notifications/check-reminders", body: [:])
    }

    // MARK: - Plaud NotePin

    func getPlaudStatus() async throws -> PlaudStatus {
        return try await get("/plaud/status")
    }

    func connectPlaud(token: String, region: String = "us") async throws -> EmptyResponse {
        return try await post("/plaud/connect", body: [
            "token": token,
            "region": region
        ])
    }

    func disconnectPlaud() async throws -> EmptyResponse {
        return try await delete("/plaud/disconnect")
    }

    func getPlaudRecordings() async throws -> PlaudRecordingsResponse {
        return try await get("/plaud/recordings")
    }

    func syncAllPlaud() async throws -> PlaudSyncResult {
        return try await post("/plaud/sync-and-process", body: [:])
    }

    func syncOnePlaud(fileId: String, autoProcess: Bool = true) async throws -> PlaudSyncOneResult {
        return try await post("/plaud/sync/one", body: [
            "file_id": fileId,
            "auto_process": autoProcess
        ] as [String: Any])
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURLString)\(path)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(&request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(baseURLString)\(path)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURLString)\(path)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addAuthHeader(&request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func addAuthHeader(_ request: inout URLRequest) {
        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode)
        }
    }
}

// MARK: - Error Types

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error (HTTP \(code))"
        }
    }
}

/// For DELETE endpoints that return `{"status": "deleted"}`.
struct EmptyResponse: Decodable {
    let status: String?
}
