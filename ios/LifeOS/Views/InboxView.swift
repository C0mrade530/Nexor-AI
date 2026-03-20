import SwiftUI

struct InboxView: View {
    @StateObject private var vm = InboxViewModel()
    @State private var selectedFilter: String = "all"

    let filters = ["all", "meeting", "idea", "task", "commitment", "follow_up"]

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(alignment: .bottom) {
                    Text("Inbox")
                        .font(.loTitle)
                        .foregroundColor(Color.loPrimaryFallback)
                    Spacer()
                    if !vm.events.isEmpty {
                        Text("\(vm.events.count)")
                            .font(.loMonoSmall)
                            .foregroundColor(Color.loTertiaryFallback)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.sm)

                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(filters, id: \.self) { filter in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedFilter = filter
                                }
                                Task {
                                    if filter == "all" {
                                        await vm.loadEvents()
                                    } else {
                                        await vm.loadByType(filter)
                                    }
                                }
                            } label: {
                                LOChip(
                                    text: filter.replacingOccurrences(of: "_", with: " "),
                                    isActive: selectedFilter == filter
                                )
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
                .padding(.bottom, Spacing.sm)

                LODivider()

                // Content
                if vm.isLoading && vm.events.isEmpty {
                    Spacer()
                    ProgressView()
                        .tint(Color.loTertiaryFallback)
                    Spacer()
                } else if vm.events.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(vm.events) { event in
                                NavigationLink(destination: EventDetailView(event: event)) {
                                    MinimalEventRow(event: event)
                                }
                                .buttonStyle(.plain)
                                LODivider()
                                    .padding(.leading, Spacing.xxl + Spacing.lg)
                            }
                        }
                    }
                    .refreshable { await vm.loadEvents() }
                }
            }
        }
        .navigationBarHidden(true)
        .task { await vm.loadEvents() }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundColor(Color.loTertiaryFallback)
            Text("Nothing here yet")
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
        }
    }
}

// MARK: - Minimal Event Row

struct MinimalEventRow: View {
    let event: Event

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Type icon
            LOEventIcon(type: event.eventType)
                .padding(.top, Spacing.xxxs)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                // Title
                Text(event.title)
                    .font(.loHeadline)
                    .foregroundColor(Color.loPrimaryFallback)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Summary
                Text(event.summary)
                    .font(.loCaption)
                    .foregroundColor(Color.loSecondaryFallback)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Metadata row
                HStack(spacing: Spacing.sm) {
                    if let items = event.actionItems, !items.isEmpty {
                        metaLabel("\(items.count) tasks", icon: "square")
                    }
                    if let ideas = event.ideas, !ideas.isEmpty {
                        metaLabel("\(ideas.count) ideas", icon: "sparkle")
                    }
                    if let urgency = event.urgency, urgency >= 4 {
                        metaLabel("urgent", icon: "exclamationmark")
                            .foregroundColor(Color.loAccentFallback)
                    }
                }
                .padding(.top, Spacing.xxxs)
            }

            Spacer()

            // Time
            if let tone = event.emotionalTone {
                Text(toneEmoji(tone))
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    private func metaLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: Spacing.xxxs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .light))
            Text(text)
                .font(.loMicro)
        }
        .foregroundColor(Color.loTertiaryFallback)
    }

    private func toneEmoji(_ tone: String) -> String {
        switch tone.lowercased() {
        case "positive", "excited": return ""
        case "negative", "stressed": return ""
        case "neutral": return ""
        default: return ""
        }
    }
}
