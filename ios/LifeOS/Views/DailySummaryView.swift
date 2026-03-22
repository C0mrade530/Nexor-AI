import SwiftUI

struct DailySummaryView: View {
    @StateObject private var vm = DailySummaryViewModel()
    @State private var selectedTab = 0

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
            if let headline = summary.headline {
                Text(headline)
                    .font(.loHeadline)
                    .foregroundColor(Color.loPrimaryFallback)
                    .lineSpacing(2)
                    .padding(.horizontal, Spacing.lg)
            }

            // Stats strip
            HStack(spacing: 0) {
                statCell(value: summary.totalEvents ?? 0, label: "Events")
                statDivider
                statCell(value: summary.totalMeetings ?? 0, label: "Meetings")
                statDivider
                statCell(value: summary.totalCommitments ?? 0, label: "Promises")
                statDivider
                statCell(value: summary.totalTasks ?? 0, label: "Tasks")
            }
            .padding(.vertical, Spacing.md)
            .loCardStyle()
            .padding(.horizontal, Spacing.lg)

            // Section tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    sectionTab("Overview", index: 0)
                    sectionTab("Meetings", index: 1)
                    sectionTab("Promises", index: 2)
                    sectionTab("Tasks", index: 3)
                    sectionTab("Mentor", index: 4)
                    sectionTab("Ideas", index: 5)
                }
                .padding(.horizontal, Spacing.lg)
            }

            // Tab content
            Group {
                switch selectedTab {
                case 0: overviewSection(summary)
                case 1: meetingsSection(summary)
                case 2: commitmentsSection(summary)
                case 3: tasksSection(summary)
                case 4: mentorSection(summary)
                case 5: ideasSection(summary)
                default: overviewSection(summary)
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer(minLength: Spacing.lg)
        }
    }

    // MARK: - Section Tab

    private func sectionTab(_ title: String, index: Int) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index } }) {
            Text(title.uppercased())
                .font(.loMicro)
                .tracking(1)
                .foregroundColor(selectedTab == index ? Color.loPrimaryFallback : Color.loTertiaryFallback)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    selectedTab == index
                        ? Color.loSurfaceFallback
                        : Color.clear
                )
                .cornerRadius(6)
        }
    }

    // MARK: - Overview

    @ViewBuilder
    private func overviewSection(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let text = summary.summary {
                Text(text)
                    .font(.loBody)
                    .foregroundColor(Color.loSecondaryFallback)
                    .lineSpacing(5)
            }

            LODivider()

            if let coaching = summary.coachingFeedback {
                sectionBlock("COACHING", icon: "sparkle", accent: true) {
                    Text(coaching)
                        .font(.loBody)
                        .foregroundColor(Color.loPrimaryFallback)
                        .lineSpacing(4)
                }
            }

            if let emotional = summary.emotionalStateSummary {
                sectionBlock("EMOTIONAL ARC", icon: "heart.text.square") {
                    Text(emotional)
                        .font(.loCaption)
                        .foregroundColor(Color.loSecondaryFallback)
                        .lineSpacing(3)
                }
            }

            if let tomorrow = summary.oneThingForTomorrow {
                sectionBlock("TOMORROW", icon: "arrow.right.circle") {
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
            }

            effectivenessBar(summary.effectivenessScore)
        }
    }

    // MARK: - Meetings

    @ViewBuilder
    private func meetingsSection(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let section = summary.meetingsSection, let meetings = section.meetings, !meetings.isEmpty {
                ForEach(meetings) { meeting in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(meeting.title ?? "Meeting")
                            .font(.loHeadline)
                            .foregroundColor(Color.loPrimaryFallback)

                        if let participants = meeting.participants, !participants.isEmpty {
                            HStack(spacing: Spacing.xs) {
                                ForEach(participants, id: \.self) { p in
                                    Text(p)
                                        .font(.loMicro)
                                        .padding(.horizontal, Spacing.sm)
                                        .padding(.vertical, Spacing.xxs)
                                        .background(Color.loSurfaceFallback)
                                        .cornerRadius(4)
                                        .foregroundColor(Color.loSecondaryFallback)
                                }
                            }
                        }

                        if let takeaways = meeting.keyTakeaways, !takeaways.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("KEY TAKEAWAYS")
                                    .font(.loMicro)
                                    .tracking(0.8)
                                    .foregroundColor(Color.loTertiaryFallback)
                                ForEach(takeaways, id: \.self) { t in
                                    HStack(alignment: .top, spacing: Spacing.sm) {
                                        Circle()
                                            .fill(Color.loAccentFallback)
                                            .frame(width: 4, height: 4)
                                            .padding(.top, 6)
                                        Text(t)
                                            .font(.loCaption)
                                            .foregroundColor(Color.loPrimaryFallback)
                                    }
                                }
                            }
                        }

                        if let quality = meeting.outcomeQuality {
                            HStack(spacing: Spacing.xs) {
                                Text("Quality")
                                    .font(.loMicro)
                                    .foregroundColor(Color.loTertiaryFallback)
                                HStack(spacing: 2) {
                                    ForEach(0..<10, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(i < quality ? Color.loAccentFallback : Color.loTertiaryFallback.opacity(0.15))
                                            .frame(width: 12, height: 3)
                                    }
                                }
                            }
                        }

                        if let followUp = meeting.suggestedFollowUpMessage {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("FOLLOW-UP")
                                    .font(.loMicro)
                                    .tracking(0.8)
                                    .foregroundColor(Color.loTertiaryFallback)
                                Text(followUp)
                                    .font(.loCaption)
                                    .foregroundColor(Color.loSecondaryFallback)
                                    .lineSpacing(3)
                                    .padding(Spacing.sm)
                                    .loCardStyle()
                            }
                        }
                    }
                    .padding(Spacing.md)
                    .loCardStyle()
                }
            } else {
                noDataView("No meetings today")
            }
        }
    }

    // MARK: - Commitments

    @ViewBuilder
    private func commitmentsSection(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let section = summary.commitmentsSection, let items = section.items, !items.isEmpty {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: "hand.raised")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(Color.loAccentFallback)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                            Text(item.promise ?? "")
                                .font(.loBody)
                                .foregroundColor(Color.loPrimaryFallback)

                            HStack(spacing: Spacing.sm) {
                                if let whom = item.toWhom, !whom.isEmpty {
                                    Text(whom)
                                        .font(.loMicro)
                                        .foregroundColor(Color.loSecondaryFallback)
                                }
                                if let deadline = item.deadline, !deadline.isEmpty {
                                    Text(deadline)
                                        .font(.loMicro)
                                        .foregroundColor(Color.loAccentFallback)
                                }
                            }

                            if let risk = item.riskOfForgetting, risk >= 3 {
                                HStack(spacing: 2) {
                                    ForEach(0..<5, id: \.self) { i in
                                        Circle()
                                            .fill(i < risk ? Color.loAccentFallback : Color.loTertiaryFallback.opacity(0.2))
                                            .frame(width: 5, height: 5)
                                    }
                                    Text("risk")
                                        .font(.loMicro)
                                        .foregroundColor(Color.loTertiaryFallback)
                                }
                            }
                        }
                    }
                    .padding(Spacing.sm)
                    .loCardStyle()
                }
            } else {
                noDataView("No commitments today")
            }
        }
    }

    // MARK: - Tasks

    @ViewBuilder
    private func tasksSection(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let section = summary.tasksSection {
                if let order = section.suggestedOrder, !order.isEmpty {
                    sectionBlock("RECOMMENDED ORDER", icon: "arrow.up.arrow.down") {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(Array(order.enumerated()), id: \.offset) { i, task in
                                HStack(spacing: Spacing.sm) {
                                    Text("\(i + 1)")
                                        .font(.loMonoSmall)
                                        .foregroundColor(Color.loAccentFallback)
                                        .frame(width: 20)
                                    Text(task)
                                        .font(.loCaption)
                                        .foregroundColor(Color.loPrimaryFallback)
                                }
                            }
                        }
                    }
                }

                if let tasks = section.newTasks, !tasks.isEmpty {
                    VStack(spacing: Spacing.xs) {
                        ForEach(tasks) { task in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.loTertiaryFallback.opacity(0.5), lineWidth: 1)
                                    .frame(width: 14, height: 14)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                                    Text(task.task ?? "")
                                        .font(.loBody)
                                        .foregroundColor(Color.loPrimaryFallback)
                                    HStack(spacing: Spacing.xs) {
                                        if let source = task.sourceEvent {
                                            Text(source)
                                                .font(.loMicro)
                                                .foregroundColor(Color.loTertiaryFallback)
                                        }
                                        if let deadline = task.deadline {
                                            Text(deadline)
                                                .font(.loMicro)
                                                .foregroundColor(Color.loAccentFallback)
                                        }
                                        if let priority = task.priority {
                                            LOChip(text: priority, isActive: true)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                noDataView("No tasks today")
            }
        }
    }

    // MARK: - Mentor

    @ViewBuilder
    private func mentorSection(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if let mentor = vm.mentorFeedback ?? summary.mentorFeedback {
                // Overall assessment
                if let assessment = mentor.overallAssessment {
                    Text(assessment)
                        .font(.loBody)
                        .foregroundColor(Color.loPrimaryFallback)
                        .lineSpacing(4)
                        .padding(Spacing.md)
                        .loCardStyle()
                }

                // What you did well
                if let wins = mentor.whatYouDidWell, !wins.isEmpty {
                    sectionBlock("WHAT YOU DID WELL", icon: "checkmark.circle") {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(wins) { w in
                                HStack(alignment: .top, spacing: Spacing.sm) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.green)
                                        .padding(.top, 3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(w.observation ?? "")
                                            .font(.loCaption)
                                            .foregroundColor(Color.loPrimaryFallback)
                                        if let mentor = w.fromWhichMentor {
                                            Text(mentor)
                                                .font(.loMicro)
                                                .foregroundColor(Color.loTertiaryFallback)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // What to improve
                if let improvements = mentor.whatToImprove, !improvements.isEmpty {
                    sectionBlock("WHAT TO IMPROVE", icon: "arrow.up.circle") {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(improvements) { imp in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(imp.observation ?? "")
                                        .font(.loCaption)
                                        .foregroundColor(Color.loPrimaryFallback)
                                    if let advice = imp.specificAdvice {
                                        Text(advice)
                                            .font(.loMicro)
                                            .foregroundColor(Color.loAccentFallback)
                                    }
                                    if let mentor = imp.fromWhichMentor {
                                        Text(mentor)
                                            .font(.loMicro)
                                            .foregroundColor(Color.loTertiaryFallback)
                                    }
                                }
                                .padding(Spacing.sm)
                                .loCardStyle()
                            }
                        }
                    }
                }

                // Communication advice
                if let comms = mentor.communicationFeedback, !comms.isEmpty {
                    sectionBlock("COMMUNICATION", icon: "bubble.left.and.bubble.right") {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(comms) { c in
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    if let situation = c.situation {
                                        Text(situation)
                                            .font(.loCaption)
                                            .foregroundColor(Color.loSecondaryFallback)
                                    }
                                    if let better = c.whatToSayInstead {
                                        HStack(alignment: .top, spacing: Spacing.sm) {
                                            Rectangle()
                                                .fill(Color.loAccentFallback)
                                                .frame(width: 2)
                                            Text(better)
                                                .font(.loBody)
                                                .foregroundColor(Color.loPrimaryFallback)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Innovation sparks
                if let ideas = mentor.innovationSparks, !ideas.isEmpty {
                    sectionBlock("INNOVATION SPARKS", icon: "bolt.fill", accent: true) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(ideas) { idea in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(idea.idea ?? "")
                                        .font(.loHeadline)
                                        .foregroundColor(Color.loPrimaryFallback)
                                    if let impact = idea.potentialImpact {
                                        Text(impact)
                                            .font(.loMicro)
                                            .foregroundColor(Color.loSecondaryFallback)
                                    }
                                    if let step = idea.firstStep {
                                        Text("First step: \(step)")
                                            .font(.loMicro)
                                            .foregroundColor(Color.loAccentFallback)
                                    }
                                }
                                .padding(Spacing.sm)
                                .loCardStyle()
                            }
                        }
                    }
                }

                // Sales & Upsell
                if let sales = mentor.salesOpportunities, !sales.isEmpty {
                    sectionBlock("SALES OPPORTUNITIES", icon: "dollarsign.circle") {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(sales) { s in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.opportunity ?? "")
                                        .font(.loCaption)
                                        .foregroundColor(Color.loPrimaryFallback)
                                    if let approach = s.approach {
                                        Text(approach)
                                            .font(.loMicro)
                                            .foregroundColor(Color.loSecondaryFallback)
                                    }
                                }
                            }
                        }
                    }
                }

                if let upsells = mentor.upsellStrategies, !upsells.isEmpty {
                    sectionBlock("UPSELL STRATEGIES", icon: "arrow.up.right.circle") {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            ForEach(upsells) { u in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(u.clientOrContact ?? "")
                                        .font(.loCaption)
                                        .foregroundColor(Color.loPrimaryFallback)
                                    if let idea = u.upsellIdea {
                                        Text(idea)
                                            .font(.loMicro)
                                            .foregroundColor(Color.loAccentFallback)
                                    }
                                }
                            }
                        }
                    }
                }

                // Tomorrow script
                if let script = mentor.tomorrowScript {
                    sectionBlock("TOMORROW SCRIPT", icon: "sunrise") {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            if let morning = script.morningPriority {
                                labeledItem("Morning Priority", morning)
                            }
                            if let bold = script.oneBoldMove {
                                labeledItem("Bold Move", bold)
                            }
                            if let question = script.eveningReflectionQuestion {
                                labeledItem("Evening Question", question)
                            }
                        }
                    }
                }

                // Mentor quote
                if let quote = mentor.mentorQuote {
                    Text(quote)
                        .font(.loCaption)
                        .italic()
                        .foregroundColor(Color.loSecondaryFallback)
                        .lineSpacing(3)
                        .padding(Spacing.md)
                        .overlay(
                            HStack {
                                Rectangle()
                                    .fill(Color.loAccentFallback)
                                    .frame(width: 2)
                                Spacer()
                            }
                        )
                }
            } else {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(Color.loTertiaryFallback)

                    Text("AI Mentor feedback generates\nwith your daily summary")
                        .font(.loCaption)
                        .foregroundColor(Color.loTertiaryFallback)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xxl)
            }
        }
    }

    // MARK: - Ideas

    @ViewBuilder
    private func ideasSection(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let section = summary.ideasSection, let ideas = section.ideas, !ideas.isEmpty {
                ForEach(ideas) { idea in
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(Color.loAccentFallback)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                            Text(idea.text ?? "")
                                .font(.loBody)
                                .foregroundColor(Color.loPrimaryFallback)

                            HStack(spacing: Spacing.xs) {
                                if let cat = idea.category {
                                    Text(cat.uppercased())
                                        .font(.loMicro)
                                        .tracking(0.5)
                                        .foregroundColor(Color.loTertiaryFallback)
                                }
                                if let value = idea.potentialValue {
                                    Text(value)
                                        .font(.loMicro)
                                        .foregroundColor(Color.loSecondaryFallback)
                                }
                            }

                            if let next = idea.suggestedNextStep {
                                Text("Next: \(next)")
                                    .font(.loMicro)
                                    .foregroundColor(Color.loAccentFallback)
                            }
                        }
                    }
                }
            } else {
                noDataView("No ideas captured today")
            }
        }
    }

    // MARK: - History Row

    private func historyRow(_ summary: DailySummary) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(summary.date)
                    .font(.loCaption)
                    .foregroundColor(Color.loPrimaryFallback)
                if let headline = summary.headline {
                    Text(headline)
                        .font(.loMicro)
                        .foregroundColor(Color.loSecondaryFallback)
                        .lineLimit(1)
                }
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

            if !vm.isGenerating {
                LOButton(title: "Generate Now", style: .secondary) {
                    Task { await vm.generateSummary() }
                }
                .padding(.top, Spacing.sm)
            } else {
                ProgressView()
                    .tint(Color.loAccentFallback)
                    .padding(.top, Spacing.sm)
            }

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

    @ViewBuilder
    private func sectionBlock<Content: View>(
        _ title: String,
        icon: String,
        accent: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(accent ? Color.loAccentFallback : Color.loTertiaryFallback)
                Text(title)
                    .font(.loMicro)
                    .tracking(1.2)
                    .foregroundColor(Color.loTertiaryFallback)
            }
            content()
        }
    }

    @ViewBuilder
    private func effectivenessBar(_ score: Double?) -> some View {
        if let score = score {
            HStack {
                Text("Effectiveness")
                    .font(.loCaption)
                    .foregroundColor(Color.loTertiaryFallback)
                Spacer()
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
        }
    }

    private func labeledItem(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.loMicro)
                .tracking(0.5)
                .foregroundColor(Color.loTertiaryFallback)
            Text(value)
                .font(.loCaption)
                .foregroundColor(Color.loPrimaryFallback)
        }
    }

    private func noDataView(_ text: String) -> some View {
        Text(text)
            .font(.loCaption)
            .foregroundColor(Color.loTertiaryFallback)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xl)
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
                    if let headline = summary.headline {
                        Text(headline)
                            .font(.loTitle)
                            .foregroundColor(Color.loPrimaryFallback)
                    }

                    if let text = summary.summary {
                        Text(text)
                            .font(.loBody)
                            .foregroundColor(Color.loSecondaryFallback)
                            .lineSpacing(5)
                    }

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
