import SwiftUI

struct EventDetailView: View {
    let event: Event
    @Environment(\.dismiss) var dismiss

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
                                            if let category = idea.category {
                                                Text(category.uppercased())
                                                    .font(.loMicro)
                                                    .tracking(0.5)
                                                    .foregroundColor(Color.loTertiaryFallback)
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
                                        Text(d["decision"] ?? d.values.first ?? "")
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
                                    Text(c["promise"] ?? c.values.first ?? "")
                                        .font(.loBody)
                                        .foregroundColor(Color.loPrimaryFallback)
                                        .padding(.leading, Spacing.md)
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
                                        Text(f["action"] ?? f.values.first ?? "")
                                            .font(.loBody)
                                            .foregroundColor(Color.loPrimaryFallback)
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
                                    // TODO: EventKit
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
