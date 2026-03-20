import Foundation

/// LifeOS API client for communicating with the backend.
class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?

    init(baseURL: String = "https://api.lifeos.app/api/v1") {
        self.baseURL = URL(string: baseURL)!
        self.session = URLSession.shared
    }

    func setAuthToken(_ token: String) {
        self.authToken = token
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
        let url = baseURL.appendingPathComponent("/audio/sessions/\(sessionId)/chunks")
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

        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(AudioChunkResponse.self, from: data)
    }

    func finishSession(sessionId: String) async throws -> AudioSession {
        let body: [String: Any] = [
            "ended_at": ISO8601DateFormatter().string(from: Date())
        ]
        return try await post("/audio/sessions/\(sessionId)/finish", body: body)
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

    // MARK: - Processing

    func processSession(sessionId: String) async throws -> ProcessingResult {
        return try await post("/process/session/\(sessionId)", body: [:])
    }

    // MARK: - Private Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(&request)

        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func addAuthHeader(_ request: inout URLRequest) {
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}
