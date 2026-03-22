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

/// ViewModel for Daily Summary screen (enhanced with mentor feedback).
@MainActor
class DailySummaryViewModel: ObservableObject {
    @Published var summary: DailySummary?
    @Published var recentSummaries: [DailySummary] = []
    @Published var mentorFeedback: MentorFeedback?
    @Published var isLoading = false
    @Published var isGenerating = false

    private let api = APIClient.shared

    var todayDateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    func loadToday() async {
        isLoading = true
        do {
            summary = try await api.getDailySummary(date: todayDateString)
            mentorFeedback = summary?.mentorFeedback
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

    func generateSummary() async {
        isGenerating = true
        do {
            summary = try await api.generateDailySummary(date: todayDateString)
            mentorFeedback = summary?.mentorFeedback
        } catch {
            // Handle error
        }
        isGenerating = false
    }

    func loadMentor(date: String? = nil) async {
        let d = date ?? todayDateString
        do {
            mentorFeedback = try await api.getMentorFeedback(date: d)
        } catch {
            // No mentor feedback yet
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

/// ViewModel for Meeting Detail with AI analysis.
@MainActor
class MeetingDetailViewModel: ObservableObject {
    @Published var analysis: MeetingAnalysisData?
    @Published var isLoading = false

    private let api = APIClient.shared

    func loadAnalysis(eventId: String) async {
        isLoading = true
        do {
            let result = try await api.getMeetingAnalysis(eventId: eventId)
            analysis = result.analysis
        } catch {
            // Handle error
        }
        isLoading = false
    }
}
