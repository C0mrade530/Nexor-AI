import SwiftUI

struct EventDetailView: View {
    let event: Event
    @Environment(\.dismiss) var dismiss
    @StateObject private var meetingVM = MeetingDetailViewModel()

    var isMeeting: Bool {
        event.eventType == "meeting" || event.eventType == "sales_call"
    }

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.xs) {
                            LOEventIcon(type: event.eventType)
                            Text(event.eventType.replacingOccurrences(of: "_", with: " ").uppercased())
                                .font(.loMicro)
                                .tracking(1)
                                .foregroundColor(Color.loTertiaryFallback)
                        }

                        Text(event.title)
                            .font(.loTitle)
                            .foregroundColor(Color.loPrimaryFallback)

                        if let tone = event.emotionalTone {
                            Text(tone)
                                .font(.loCaption)
                                .foregroundColor(Color.loSecondaryFallback)
                        }
                    }

                    LODivider()

                    // Summary
                    Text(event.summary)
                        .font(.loBody)
                        .foregroundColor(Color.loPrimaryFallback)
                        .lineSpacing(4)

                    // AI Analysis for meetings
                    if isMeeting {
                        meetingAnalysisSection
                    }

                    // Participants
                    if let participants = event.participants, !participants.isEmpty {
                        detailSection("Participants") {
                            HStack(spacing: Spacing.xs) {
                                ForEach(participants, id: \.self) { name in
                                    Text(name)
                                        .font(.loCaption)
                                        .padding(.horizontal, Spacing.sm)
                                        .padding(.vertical, Spacing.xxs + 1)
                                        .background(Color.loSurfaceFallback)
                                        .cornerRadius(6)
                                        .foregroundColor(Color.loPrimaryFallback)
                                }
                            }
                        }
                    }

                    // Action Items
                    if let items = event.actionItems, !items.isEmpty {
                        detailSection("Tasks") {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                    HStack(alignment: .top, spacing: Spacing.sm) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(Color.loTertiaryFallback.opacity(0.5), lineWidth: 1)
                                            .frame(width: 14, height: 14)
                                            .padding(.top, 2)

                                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                                            Text(item.task)
                                                .font(.loBody)
                                                .foregroundColor(Color.loPrimaryFallback)
                                            HStack(spacing: Spacing.xs) {
                                                if let assignee = item.assignee {
                                                    Text(assignee)
                                                        .font(.loMicro)
                                                        .foregroundColor(Color.loSecondaryFallback)
                                                }
                                                if let deadline = item.deadline {
                                                    Text(deadline)
                                                        .font(.loMicro)
                                                        .foregroundColor(Color.loAccentFallback)
                                                }
                                                if let priority = item.priority {
                                                    LOChip(text: priority, isActive: true)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Ideas
                    if let ideas = event.ideas, !ideas.isEmpty {
                        detailSection("Ideas") {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                ForEach(Array(ideas.enumerated()), id: \.offset) { _, idea in
                                    HStack(alignment: .top, spacing: Spacing.sm) {
                                        Image(systemName: "sparkle")
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(Color.loAccentFallback)
                                            .padding(.top, 2)

                                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                                            Text(idea.text)
                                                .font(.loBody)
                                                .foregroundColor(Color.loPrimaryFallback)
                                            HStack(spacing: Spacing.xs) {
                                                if let category = idea.category {
                                                    Text(category.uppercased())
                                                        .font(.loMicro)
                                                        .tracking(0.5)
                                                        .foregroundColor(Color.loTertiaryFallback)
                                                }
                                                if let next = idea.suggestedNextStep {
                                                    Text("Next: \(next)")
                                                        .font(.loMicro)
                                                        .foregroundColor(Color.loAccentFallback)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Decisions
                    if let decisions = event.decisions, !decisions.isEmpty {
                        detailSection("Decisions") {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                ForEach(Array(decisions.enumerated()), id: \.offset) { _, d in
                                    HStack(alignment: .top, spacing: Spacing.sm) {
                                        Image(systemName: "arrow.branch")
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(Color.loSecondaryFallback)
                                        Text(d["decision"] ?? d.firstValue ?? "")
                                            .font(.loBody)
                                            .foregroundColor(Color.loPrimaryFallback)
                                    }
                                }
                            }
                        }
                    }

                    // Commitments
                    if let commitments = event.commitments, !commitments.isEmpty {
                        detailSection("Commitments") {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                ForEach(Array(commitments.enumerated()), id: \.offset) { _, c in
                                    HStack(alignment: .top, spacing: Spacing.sm) {
                                        Image(systemName: "hand.raised")
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(Color.loAccentFallback)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(c["promise"] ?? c.firstValue ?? "")
                                                .font(.loBody)
                                                .foregroundColor(Color.loPrimaryFallback)
                                            if let whom = c["to_whom"], !whom.isEmpty {
                                                Text("To: \(whom)")
                                                    .font(.loMicro)
                                                    .foregroundColor(Color.loSecondaryFallback)
                                            }
                                            if let deadline = c["deadline"], !deadline.isEmpty {
                                                Text(deadline)
                                                    .font(.loMicro)
                                                    .foregroundColor(Color.loAccentFallback)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Follow-ups
                    if let followUps = event.followUps, !followUps.isEmpty {
                        detailSection("Follow-ups") {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                ForEach(Array(followUps.enumerated()), id: \.offset) { _, f in
                                    HStack(alignment: .top, spacing: Spacing.sm) {
                                        Image(systemName: "arrow.turn.up.right")
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(Color.loAccentFallback)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(f["action"] ?? f.firstValue ?? "")
                                                .font(.loBody)
                                                .foregroundColor(Color.loPrimaryFallback)
                                            HStack(spacing: Spacing.xs) {
                                                if let whom = f["whom"], !whom.isEmpty {
                                                    Text(whom)
                                                        .font(.loMicro)
                                                        .foregroundColor(Color.loSecondaryFallback)
                                                }
                                                if let when = f["by_when"], !when.isEmpty {
                                                    Text(when)
                                                        .font(.loMicro)
                                                        .foregroundColor(Color.loAccentFallback)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Calendar suggestion
                    if let cal = event.suggestedCalendarEvent {
                        detailSection("Calendar") {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text(cal.title)
                                    .font(.loHeadline)
                                    .foregroundColor(Color.loPrimaryFallback)
                                if let dt = cal.datetimeStr {
                                    Text(dt)
                                        .font(.loCaption)
                                        .foregroundColor(Color.loSecondaryFallback)
                                }
                                LOButton(title: "Add to Calendar", style: .secondary) {
                                    // TODO: EventKit integration
                                }
                            }
                        }
                    }

                    // Transcript
                    if let transcript = event.transcriptExcerpt, !transcript.isEmpty {
                        detailSection("Source") {
                            Text(transcript)
                                .font(.loMonoSmall)
                                .foregroundColor(Color.loTertiaryFallback)
                                .lineSpacing(3)
                        }
                    }

                    // Tags
                    if let tags = event.tags, !tags.isEmpty {
                        HStack(spacing: Spacing.xs) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.loMicro)
                                    .tracking(0.3)
                                    .foregroundColor(Color.loTertiaryFallback)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xxs)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.loTertiaryFallback.opacity(0.2), lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(.top, Spacing.sm)
                    }

                    // Urgency / Importance
                    if event.urgency != nil || event.importance != nil {
                        HStack(spacing: Spacing.xl) {
                            if let u = event.urgency {
                                metricView("Urgency", value: u)
                            }
                            if let i = event.importance {
                                metricView("Importance", value: i)
                            }
                            Spacer()
                        }
                    }

                    Spacer(minLength: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if isMeeting {
                await meetingVM.loadAnalysis(eventId: event.id)
            }
        }
    }

    // MARK: - Meeting Analysis

    @ViewBuilder
    private var meetingAnalysisSection: some View {
        if meetingVM.isLoading {
            HStack {
                ProgressView()
                    .tint(Color.loTertiaryFallback)
                Text("Analyzing meeting...")
                    .font(.loCaption)
                    .foregroundColor(Color.loTertiaryFallback)
            }
            .padding(Spacing.md)
            .loCardStyle()
        } else if let analysis = meetingVM.analysis {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Meeting rating
                if let rating = analysis.meetingRating {
                    HStack {
                        Text("MEETING SCORE")
                            .font(.loMicro)
                            .tracking(1)
                            .foregroundColor(Color.loTertiaryFallback)
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(0..<10, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(i < rating ? Color.loAccentFallback : Color.loTertiaryFallback.opacity(0.15))
                                    .frame(width: 14, height: 3)
                            }
                        }
                        Text("\(rating)")
                            .font(.loMonoSmall)
                            .foregroundColor(Color.loPrimaryFallback)
                    }
                }

                // Relationship temperature
                if let temp = analysis.relationshipTemperature {
                    HStack(spacing: Spacing.xs) {
                        Text("RELATIONSHIP")
                            .font(.loMicro)
                            .tracking(1)
                            .foregroundColor(Color.loTertiaryFallback)
                        LOChip(text: temp, isActive: true)
                    }
                }

                // Follow-up draft
                if let draft = analysis.followUpDraft {
                    detailSection("Suggested Follow-up") {
                        Text(draft)
                            .font(.loCaption)
                            .foregroundColor(Color.loSecondaryFallback)
                            .lineSpacing(3)
                            .padding(Spacing.sm)
                            .loCardStyle()
                    }
                }

                // Deal probability
                if let prob = analysis.dealProbability {
                    HStack(spacing: Spacing.xs) {
                        Text("DEAL PROBABILITY")
                            .font(.loMicro)
                            .tracking(1)
                            .foregroundColor(Color.loTertiaryFallback)
                        Text(prob)
                            .font(.loCaption)
                            .foregroundColor(Color.loAccentFallback)
                    }
                }

                // Hidden opportunities
                if let hidden = analysis.hiddenOpportunities, !hidden.isEmpty {
                    detailSection("Hidden Opportunities") {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(hidden, id: \.self) { opp in
                                HStack(alignment: .top, spacing: Spacing.sm) {
                                    Image(systemName: "eye")
                                        .font(.system(size: 10, weight: .light))
                                        .foregroundColor(Color.loAccentFallback)
                                        .padding(.top, 3)
                                    Text(opp)
                                        .font(.loCaption)
                                        .foregroundColor(Color.loPrimaryFallback)
                                }
                            }
                        }
                    }
                }

                // Improvement suggestions
                if let suggestions = analysis.improvementSuggestions, !suggestions.isEmpty {
                    detailSection("Next Meeting Improvements") {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(suggestions, id: \.self) { s in
                                HStack(alignment: .top, spacing: Spacing.sm) {
                                    Image(systemName: "arrow.up.circle")
                                        .font(.system(size: 10, weight: .light))
                                        .foregroundColor(Color.loSecondaryFallback)
                                        .padding(.top, 3)
                                    Text(s)
                                        .font(.loCaption)
                                        .foregroundColor(Color.loPrimaryFallback)
                                }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .background(Color.loSurfaceFallback.opacity(0.5))
            .cornerRadius(12)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title.uppercased())
                .font(.loMicro)
                .tracking(1.2)
                .foregroundColor(Color.loTertiaryFallback)

            content()
        }
    }

    private func metricView(_ label: String, value: Int) -> some View {
        VStack(spacing: Spacing.xxxs) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(i < value ? Color.loAccentFallback : Color.loTertiaryFallback.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }
            Text(label)
                .font(.loMicro)
                .foregroundColor(Color.loTertiaryFallback)
        }
    }
}
