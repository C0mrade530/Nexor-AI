import SwiftUI

struct DailySummaryView: View {
    @StateObject private var vm = DailySummaryViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                if vm.isLoading {
                    ProgressView("Loading summary...")
                        .padding(.top, 60)
                } else if let summary = vm.summary {
                    SummaryCard(summary: summary)
                        .padding()
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No summary yet for today")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Record your day and the AI will generate insights, action items, and coaching feedback")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 80)
                }

                // Recent summaries
                if !vm.recentSummaries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Days")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(vm.recentSummaries) { summary in
                            NavigationLink(destination: SummaryDetailView(summary: summary)) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(summary.headline)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(summary.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let score = summary.effectivenessScore {
                                        Text(String(format: "%.0f", score))
                                            .font(.title3.bold())
                                            .foregroundColor(scoreColor(score))
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Daily Summary")
            .task {
                await vm.loadToday()
                await vm.loadRecent()
            }
            .refreshable {
                await vm.loadToday()
                await vm.loadRecent()
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 8 { return .green }
        if score >= 5 { return .orange }
        return .red
    }
}

struct SummaryCard: View {
    let summary: DailySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Headline
            Text(summary.headline)
                .font(.title3.bold())

            // Stats row
            HStack(spacing: 16) {
                StatBadge(value: summary.totalEvents ?? 0, label: "Events", icon: "list.bullet")
                StatBadge(value: summary.totalMeetings ?? 0, label: "Meetings", icon: "person.2")
                StatBadge(value: summary.totalIdeas ?? 0, label: "Ideas", icon: "lightbulb")
                if let mins = summary.totalRecordingMinutes {
                    StatBadge(value: Int(mins), label: "Minutes", icon: "clock")
                }
            }

            Divider()

            // Summary text
            Text(summary.summary)
                .font(.body)

            // Coaching
            if let coaching = summary.coachingFeedback {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Coaching", systemImage: "sparkles")
                            .font(.subheadline.bold())
                        Text(coaching)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Emotional state
            if let emotional = summary.emotionalStateSummary {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Emotional Arc", systemImage: "heart")
                            .font(.subheadline.bold())
                        Text(emotional)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // One thing for tomorrow
            if let tomorrow = summary.oneThingForTomorrow {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Focus for Tomorrow", systemImage: "target")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                        Text(tomorrow)
                            .font(.body.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Effectiveness score
            if let score = summary.effectivenessScore {
                HStack {
                    Text("Day Effectiveness")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f / 10", score))
                        .font(.title2.bold())
                        .foregroundColor(score >= 7 ? .green : score >= 4 ? .orange : .red)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

struct StatBadge: View {
    let value: Int
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SummaryDetailView: View {
    let summary: DailySummary

    var body: some View {
        ScrollView {
            SummaryCard(summary: summary)
                .padding()
        }
        .navigationTitle(summary.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}
