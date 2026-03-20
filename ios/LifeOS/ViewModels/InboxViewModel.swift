import Foundation

/// ViewModel for the Inbox — daily feed of all events and recordings.
@MainActor
class InboxViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await api.getEvents()
            events = response.events
        } catch {
            errorMessage = "Failed to load events: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func loadByType(_ type: String) async {
        isLoading = true
        do {
            let response = try await api.getEvents(type: type)
            events = response.events
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

/// ViewModel for Daily Summary screen.
@MainActor
class DailySummaryViewModel: ObservableObject {
    @Published var summary: DailySummary?
    @Published var recentSummaries: [DailySummary] = []
    @Published var isLoading = false

    private let api = APIClient.shared

    func loadToday() async {
        isLoading = true
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        do {
            summary = try await api.getDailySummary(date: String(today))
        } catch {
            // No summary yet for today
        }
        isLoading = false
    }

    func loadRecent() async {
        do {
            recentSummaries = try await api.getDailySummaries(limit: 7)
        } catch {
            // Handle error
        }
    }
}

/// ViewModel for Memory Search.
@MainActor
class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var answer: String = ""
    @Published var isSearching = false

    private let api = APIClient.shared

    func search() async {
        guard !query.isEmpty else { return }
        isSearching = true
        do {
            let response = try await api.searchMemory(query: query)
            answer = response.answer
        } catch {
            answer = "Search failed: \(error.localizedDescription)"
        }
        isSearching = false
    }
}
