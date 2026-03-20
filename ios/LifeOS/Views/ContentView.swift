import SwiftUI

/// Main tab view for LifeOS app.
struct ContentView: View {
    var body: some View {
        TabView {
            InboxView()
                .tabItem {
                    Image(systemName: "tray.fill")
                    Text("Inbox")
                }

            RecordView()
                .tabItem {
                    Image(systemName: "mic.circle.fill")
                    Text("Record")
                }

            DailySummaryView()
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Summary")
                }

            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

// MARK: - Inbox

struct InboxView: View {
    @StateObject private var vm = InboxViewModel()
    @State private var selectedFilter: String = "all"

    let filters = ["all", "meeting", "idea", "task", "commitment", "sales_call"]

    var body: some View {
        NavigationView {
            VStack {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(filters, id: \.self) { filter in
                            Button(filter.capitalized) {
                                selectedFilter = filter
                                Task {
                                    if filter == "all" {
                                        await vm.loadEvents()
                                    } else {
                                        await vm.loadByType(filter)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedFilter == filter ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }

                // Events list
                List(vm.events) { event in
                    EventCard(event: event)
                }
                .refreshable { await vm.loadEvents() }
            }
            .navigationTitle("Inbox")
            .task { await vm.loadEvents() }
        }
    }
}

struct EventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                EventTypeBadge(type: event.eventType)
                Spacer()
                if let urgency = event.urgency {
                    Text("Priority: \(urgency)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(event.title)
                .font(.headline)

            Text(event.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)

            if let items = event.actionItems, !items.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("\(items.count) action items")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }

            if let tags = event.tags, !tags.isEmpty {
                HStack {
                    ForEach(tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EventTypeBadge: View {
    let type: String

    var color: Color {
        switch type {
        case "meeting", "sales_call": return .blue
        case "idea": return .yellow
        case "task": return .green
        case "commitment": return .orange
        case "decision": return .purple
        case "follow_up": return .red
        default: return .gray
        }
    }

    var icon: String {
        switch type {
        case "meeting": return "person.2"
        case "sales_call": return "phone"
        case "idea": return "lightbulb"
        case "task": return "checkmark.square"
        case "commitment": return "handshake"
        case "decision": return "arrow.triangle.branch"
        case "follow_up": return "arrow.uturn.forward"
        default: return "text.bubble"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

// MARK: - Record

struct RecordView: View {
    @StateObject private var recorder = AudioRecorderService()

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // Recording status
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    )
                    .onTapGesture {
                        Task {
                            if recorder.isRecording {
                                try? await recorder.stopRecording()
                            } else {
                                try? await recorder.startRecording(consent: recorder.consentMode)
                            }
                        }
                    }

                if recorder.isRecording {
                    Text(formatDuration(recorder.recordingDuration))
                        .font(.title2.monospacedDigit())

                    // Mark important moment
                    Button("Mark Important") {
                        recorder.markImportantMoment()
                    }
                    .buttonStyle(.bordered)
                }

                // Consent mode toggle
                Picker("Mode", selection: $recorder.consentMode) {
                    Text("Private").tag("private")
                    Text("Meeting").tag("meeting")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Record")
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Daily Summary

struct DailySummaryView: View {
    @StateObject private var vm = DailySummaryViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                if let summary = vm.summary {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(summary.headline)
                            .font(.title2.bold())

                        Text(summary.summary)
                            .font(.body)

                        if let coaching = summary.coachingFeedback {
                            GroupBox("Coaching") {
                                Text(coaching)
                                    .font(.body)
                            }
                        }

                        if let tomorrow = summary.oneThingForTomorrow {
                            GroupBox("Focus for Tomorrow") {
                                Text(tomorrow)
                                    .font(.body.bold())
                            }
                        }

                        if let score = summary.effectivenessScore {
                            HStack {
                                Text("Effectiveness")
                                Spacer()
                                Text(String(format: "%.1f / 10", score))
                                    .font(.title3.bold())
                            }
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No summary yet for today")
                            .foregroundColor(.secondary)
                        Text("Record your day and the AI will generate insights")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 80)
                }
            }
            .navigationTitle("Daily Summary")
            .task { await vm.loadToday() }
        }
    }
}

// MARK: - Search

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                HStack {
                    TextField("Ask your memory...", text: $vm.query)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task { await vm.search() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(vm.query.isEmpty || vm.isSearching)
                }
                .padding(.horizontal)

                if vm.isSearching {
                    ProgressView("Searching...")
                } else if !vm.answer.isEmpty {
                    ScrollView {
                        Text(vm.answer)
                            .padding()
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Example queries:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach([
                            "What did I discuss with Misha last week?",
                            "My AI SaaS ideas from this month",
                            "When did I promise to send the proposal?",
                            "Recurring problems in meetings"
                        ], id: \.self) { example in
                            Button(example) {
                                vm.query = example
                                Task { await vm.search() }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.top, 40)
                }

                Spacer()
            }
            .navigationTitle("Memory Search")
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @State private var retentionPolicy = "after_transcription"
    @State private var retentionDays = 30.0
    @State private var encryptAudio = true
    @State private var coachingEnabled = true
    @State private var language = "ru"

    var body: some View {
        NavigationView {
            Form {
                Section("Privacy") {
                    Picker("Audio Retention", selection: $retentionPolicy) {
                        Text("Keep All").tag("keep_all")
                        Text("Delete After Transcription").tag("after_transcription")
                        Text("Summaries Only").tag("summaries_only")
                    }

                    HStack {
                        Text("Retention Days")
                        Slider(value: $retentionDays, in: 1...365, step: 1)
                        Text("\(Int(retentionDays))")
                    }

                    Toggle("Encrypt Audio", isOn: $encryptAudio)
                }

                Section("AI Features") {
                    Toggle("Daily Coaching", isOn: $coachingEnabled)

                    Picker("Language", selection: $language) {
                        Text("Russian").tag("ru")
                        Text("English").tag("en")
                    }
                }

                Section("Data") {
                    Button("Export All Data") { }
                    Button("Delete All My Data") { }
                        .foregroundColor(.red)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0 MVP")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
