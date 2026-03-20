import SwiftUI

struct DailySummaryView: View {
    @StateObject private var vm = DailySummaryViewModel()

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .bottom) {
                        Text("Today")
                            .font(.loTitle)
                            .foregroundColor(Color.loPrimaryFallback)
                        Spacer()
                        Text(Date().formatted(.dateTime.month(.abbreviated).day()))
                            .font(.loCaption)
                            .foregroundColor(Color.loTertiaryFallback)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.lg)

                    if vm.isLoading {
                        VStack {
                            Spacer(minLength: 120)
                            ProgressView()
                                .tint(Color.loTertiaryFallback)
                            Spacer(minLength: 120)
                        }
                        .frame(maxWidth: .infinity)
                    } else if let summary = vm.summary {
                        summaryContent(summary)
                    } else {
                        emptyState
                    }

                    // History
                    if !vm.recentSummaries.isEmpty {
                        LOSectionHeader(title: "This week")

                        VStack(spacing: Spacing.xs) {
                            ForEach(vm.recentSummaries) { s in
                                NavigationLink(destination: SummaryFullView(summary: s)) {
                                    historyRow(s)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.xxl)
                    }
                }
            }
            .refreshable {
                await vm.loadToday()
                await vm.loadRecent()
            }
        }
        .navigationBarHidden(true)
        .task {
            await vm.loadToday()
            await vm.loadRecent()
        }
    }

    // MARK: - Summary Content

    @ViewBuilder
    private func summaryContent(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Headline
            Text(summary.headline)
                .font(.loHeadline)
                .foregroundColor(Color.loPrimaryFallback)
                .lineSpacing(2)
                .padding(.horizontal, Spacing.lg)

            // Stats strip
            HStack(spacing: 0) {
                statCell(value: summary.totalEvents ?? 0, label: "Events")
                statDivider
                statCell(value: summary.totalMeetings ?? 0, label: "Meetings")
                statDivider
                statCell(value: summary.totalIdeas ?? 0, label: "Ideas")
                statDivider
                statCell(value: Int(summary.totalRecordingMinutes ?? 0), label: "Min")
            }
            .padding(.vertical, Spacing.md)
            .loCardStyle()
            .padding(.horizontal, Spacing.lg)

            // Summary text
            Text(summary.summary)
                .font(.loBody)
                .foregroundColor(Color.loSecondaryFallback)
                .lineSpacing(5)
                .padding(.horizontal, Spacing.lg)

            LODivider()
                .padding(.horizontal, Spacing.lg)

            // Coaching
            if let coaching = summary.coachingFeedback {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(Color.loAccentFallback)
                        Text("COACHING")
                            .font(.loMicro)
                            .tracking(1.2)
                            .foregroundColor(Color.loTertiaryFallback)
                    }

                    Text(coaching)
                        .font(.loBody)
                        .foregroundColor(Color.loPrimaryFallback)
                        .lineSpacing(4)
                }
                .padding(.horizontal, Spacing.lg)
            }

            // Emotional arc
            if let emotional = summary.emotionalStateSummary {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("EMOTIONAL ARC")
                        .font(.loMicro)
                        .tracking(1.2)
                        .foregroundColor(Color.loTertiaryFallback)
                    Text(emotional)
                        .font(.loCaption)
                        .foregroundColor(Color.loSecondaryFallback)
                        .lineSpacing(3)
                }
                .padding(.horizontal, Spacing.lg)
            }

            // Focus for tomorrow
            if let tomorrow = summary.oneThingForTomorrow {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("TOMORROW")
                        .font(.loMicro)
                        .tracking(1.2)
                        .foregroundColor(Color.loTertiaryFallback)

                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Rectangle()
                            .fill(Color.loAccentFallback)
                            .frame(width: 2)

                        Text(tomorrow)
                            .font(.loHeadline)
                            .foregroundColor(Color.loPrimaryFallback)
                            .lineSpacing(2)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.lg)
            }

            // Score
            if let score = summary.effectivenessScore {
                HStack {
                    Text("Effectiveness")
                        .font(.loCaption)
                        .foregroundColor(Color.loTertiaryFallback)
                    Spacer()

                    // Minimal bar
                    HStack(spacing: 2) {
                        ForEach(0..<10, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Double(i) < score
                                      ? Color.loAccentFallback
                                      : Color.loTertiaryFallback.opacity(0.15))
                                .frame(width: 16, height: 4)
                        }
                    }

                    Text(String(format: "%.0f", score))
                        .font(.loMonoSmall)
                        .foregroundColor(Color.loPrimaryFallback)
                        .frame(width: 24, alignment: .trailing)
                }
                .padding(.horizontal, Spacing.lg)
            }

            Spacer(minLength: Spacing.lg)
        }
    }

    // MARK: - History Row

    private func historyRow(_ summary: DailySummary) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(summary.date.formatted(.dateTime.weekday(.wide)))
                    .font(.loCaption)
                    .foregroundColor(Color.loPrimaryFallback)
                Text(summary.headline)
                    .font(.loMicro)
                    .foregroundColor(Color.loSecondaryFallback)
                    .lineLimit(1)
            }
            Spacer()
            if let score = summary.effectivenessScore {
                Text(String(format: "%.0f", score))
                    .font(.loMonoSmall)
                    .foregroundColor(score >= 7 ? Color.loPrimaryFallback : Color.loTertiaryFallback)
            }
        }
        .padding(Spacing.sm)
        .loCardStyle()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer(minLength: 80)

            Image(systemName: "text.alignleft")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundColor(Color.loTertiaryFallback)

            Text("No summary yet")
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)

            Text("Record your day and the AI\nwill generate your summary")
                .font(.loMicro)
                .foregroundColor(Color.loTertiaryFallback.opacity(0.6))
                .multilineTextAlignment(.center)

            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: Spacing.xxxs) {
            Text("\(value)")
                .font(.loHeadline)
                .foregroundColor(Color.loPrimaryFallback)
            Text(label)
                .font(.loMicro)
                .foregroundColor(Color.loTertiaryFallback)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.loTertiaryFallback.opacity(0.2))
            .frame(width: 0.5, height: 28)
    }
}

// MARK: - Full Summary View

struct SummaryFullView: View {
    let summary: DailySummary

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text(summary.headline)
                        .font(.loTitle)
                        .foregroundColor(Color.loPrimaryFallback)

                    Text(summary.summary)
                        .font(.loBody)
                        .foregroundColor(Color.loSecondaryFallback)
                        .lineSpacing(5)

                    if let coaching = summary.coachingFeedback {
                        LODivider()
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("COACHING")
                                .font(.loMicro)
                                .tracking(1.2)
                                .foregroundColor(Color.loTertiaryFallback)
                            Text(coaching)
                                .font(.loBody)
                                .foregroundColor(Color.loPrimaryFallback)
                                .lineSpacing(4)
                        }
                    }

                    if let tomorrow = summary.oneThingForTomorrow {
                        LODivider()
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("FOCUS FOR TOMORROW")
                                .font(.loMicro)
                                .tracking(1.2)
                                .foregroundColor(Color.loTertiaryFallback)
                            Text(tomorrow)
                                .font(.loHeadline)
                                .foregroundColor(Color.loPrimaryFallback)
                        }
                    }

                    Spacer(minLength: Spacing.xxl)
                }
                .padding(Spacing.lg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
