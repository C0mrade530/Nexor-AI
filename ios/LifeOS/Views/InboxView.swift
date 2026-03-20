import SwiftUI

struct InboxView: View {
    @StateObject private var vm = InboxViewModel()
    @State private var selectedFilter: String = "all"

    let filters = ["all", "meeting", "idea", "task", "commitment", "sales_call"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { filter in
                            Button {
                                selectedFilter = filter
                                Task {
                                    if filter == "all" {
                                        await vm.loadEvents()
                                    } else {
                                        await vm.loadByType(filter)
                                    }
                                }
                            } label: {
                                Text(filter.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(selectedFilter == filter ? Color.blue : Color(.systemGray5))
                                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if vm.isLoading && vm.events.isEmpty {
                    Spacer()
                    ProgressView("Loading events...")
                    Spacer()
                } else if vm.events.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No events yet")
                            .foregroundColor(.secondary)
                        Text("Start recording to capture your day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(vm.events) { event in
                            NavigationLink(destination: EventDetailView(event: event)) {
                                EventCard(event: event)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await vm.loadEvents() }
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Inbox")
            .task { await vm.loadEvents() }
        }
    }
}

// MARK: - Event Card

struct EventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                EventTypeBadge(type: event.eventType)
                Spacer()
                if let urgency = event.urgency {
                    HStack(spacing: 2) {
                        ForEach(0..<urgency, id: \.self) { _ in
                            Image(systemName: "exclamationmark")
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(urgency >= 4 ? .red : .secondary)
                }
            }

            Text(event.title)
                .font(.headline)
                .lineLimit(2)

            Text(event.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)

            HStack(spacing: 12) {
                if let items = event.actionItems, !items.isEmpty {
                    Label("\(items.count)", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                if let ideas = event.ideas, !ideas.isEmpty {
                    Label("\(ideas.count)", systemImage: "lightbulb")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                if let participants = event.participants, !participants.isEmpty {
                    Label("\(participants.count)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            if let tags = event.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Event Type Badge

struct EventTypeBadge: View {
    let type: String

    var color: Color {
        switch type {
        case "meeting", "sales_call": return .blue
        case "idea": return .orange
        case "task": return .green
        case "commitment": return .purple
        case "decision": return .indigo
        case "follow_up": return .red
        case "personal_thought": return .teal
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
        case "personal_thought": return "brain"
        case "planning": return "calendar"
        default: return "text.bubble"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}
