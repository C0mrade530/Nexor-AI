import SwiftUI

/// Full detail view for a single event — meeting, idea, task, etc.
struct EventDetailView: View {
    let event: Event

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    EventTypeBadge(type: event.eventType)
                    Text(event.title)
                        .font(.title2.bold())

                    if let tone = event.emotionalTone {
                        Text("Tone: \(tone)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Summary
                GroupBox("Summary") {
                    Text(event.summary)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Participants
                if let participants = event.participants, !participants.isEmpty {
                    GroupBox("Participants") {
                        FlowLayout(items: participants) { name in
                            Label(name, systemImage: "person")
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                }

                // Action Items
                if let items = event.actionItems, !items.isEmpty {
                    GroupBox("Action Items") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .top) {
                                    Image(systemName: "circle")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.top, 3)
                                    VStack(alignment: .leading) {
                                        Text(item.task)
                                            .font(.subheadline)
                                        if let assignee = item.assignee {
                                            Text("Assignee: \(assignee)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let deadline = item.deadline {
                                            Text("By: \(deadline)")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Ideas
                if let ideas = event.ideas, !ideas.isEmpty {
                    GroupBox("Ideas") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(ideas.enumerated()), id: \.offset) { _, idea in
                                HStack(alignment: .top) {
                                    Image(systemName: "lightbulb")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                        .padding(.top, 3)
                                    VStack(alignment: .leading) {
                                        Text(idea.text)
                                            .font(.subheadline)
                                        if let category = idea.category {
                                            Text(category.capitalized)
                                                .font(.caption)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.15))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Decisions
                if let decisions = event.decisions, !decisions.isEmpty {
                    GroupBox("Decisions") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(decisions.enumerated()), id: \.offset) { _, decision in
                                HStack(alignment: .top) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .foregroundColor(.indigo)
                                        .font(.caption)
                                    Text(decision["decision"] ?? decision.values.first ?? "")
                                        .font(.subheadline)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Commitments
                if let commitments = event.commitments, !commitments.isEmpty {
                    GroupBox("Commitments") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(commitments.enumerated()), id: \.offset) { _, commitment in
                                HStack(alignment: .top) {
                                    Image(systemName: "handshake")
                                        .foregroundColor(.purple)
                                        .font(.caption)
                                    Text(commitment["promise"] ?? commitment.values.first ?? "")
                                        .font(.subheadline)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Follow-ups
                if let followUps = event.followUps, !followUps.isEmpty {
                    GroupBox("Follow-ups") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(followUps.enumerated()), id: \.offset) { _, followUp in
                                HStack(alignment: .top) {
                                    Image(systemName: "arrow.uturn.forward")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text(followUp["action"] ?? followUp.values.first ?? "")
                                        .font(.subheadline)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Calendar Suggestion
                if let cal = event.suggestedCalendarEvent {
                    GroupBox("Calendar Suggestion") {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(cal.title, systemImage: "calendar.badge.plus")
                                .font(.subheadline.bold())
                            if let dt = cal.datetimeStr {
                                Label(dt, systemImage: "clock")
                                    .font(.caption)
                            }
                            if !cal.participants.isEmpty {
                                Label(cal.participants.joined(separator: ", "), systemImage: "person.2")
                                    .font(.caption)
                            }

                            Button("Add to Calendar") {
                                // TODO: EventKit integration
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Transcript excerpt
                if let transcript = event.transcriptExcerpt, !transcript.isEmpty {
                    GroupBox("Source Transcript") {
                        Text(transcript)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Tags
                if let tags = event.tags, !tags.isEmpty {
                    FlowLayout(items: tags) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Simple horizontal wrapping layout for tags and chips.
struct FlowLayout<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        // Simplified: horizontal scroll for now, proper flow layout needs GeometryReader
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        }
    }
}
