import SwiftUI

/// AI Mentor Chat — conversational coach with full context from Apple Watch, Plaud, events.
struct MentorChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var showInsight = false
    @State private var proactiveInsight: String?

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.1)

                // Proactive insight card
                if let insight = proactiveInsight, showInsight {
                    insightCard(insight)
                }

                // Messages
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color.loAccentFallback)
                    Spacer()
                } else if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }

                // Input bar
                inputBar
            }
        }
        .task {
            await loadHistory()
            await loadInsight()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mentor")
                    .font(.loTitle)
                    .foregroundColor(Color.loPrimaryFallback)
                Text("AI coach with your full context")
                    .font(.loMicro)
                    .foregroundColor(Color.loTertiaryFallback)
            }
            Spacer()
            Button {
                Task { await loadInsight() }
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(Color.loAccentFallback)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Insight Card

    private func insightCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(Color.loAccentFallback)
                Text("Proactive Insight")
                    .font(.loMicro)
                    .foregroundColor(Color.loAccentFallback)
                Spacer()
                Button {
                    withAnimation { showInsight = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(Color.loTertiaryFallback)
                }
            }
            Text(text)
                .font(.loCaption)
                .foregroundColor(Color.loPrimaryFallback)
                .lineSpacing(3)
        }
        .padding(Spacing.md)
        .background(Color.loAccentFallback.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Color.loTertiaryFallback)

            Text("Your AI Mentor")
                .font(.loBody)
                .foregroundColor(Color.loPrimaryFallback)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                featureRow("waveform", "Send voice or text about your day")
                featureRow("applewatch", "Auto-pulls Apple Watch data")
                featureRow("waveform.circle", "Knows your Plaud recordings")
                featureRow("chart.line.uptrend.xyaxis", "Tracks patterns and accountability")
                featureRow("brain.head.profile", "Advice from world-class mentors")
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            // Quick start prompts
            VStack(spacing: Spacing.xs) {
                quickPrompt("How was my recovery today?")
                quickPrompt("What should I focus on today?")
                quickPrompt("Analyze my sleep patterns")
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(Color.loAccentFallback)
                .frame(width: 24)
            Text(text)
                .font(.loCaption)
                .foregroundColor(Color.loPrimaryFallback)
        }
    }

    private func quickPrompt(_ text: String) -> some View {
        Button {
            inputText = text
            Task { await sendMessage() }
        } label: {
            Text(text)
                .font(.loCaption)
                .foregroundColor(Color.loAccentFallback)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.loAccentFallback.opacity(0.08))
                .cornerRadius(10)
        }
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }

                    if isSending {
                        HStack(spacing: Spacing.xs) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(Color.loAccentFallback)
                            Text("Thinking...")
                                .font(.loMicro)
                                .foregroundColor(Color.loTertiaryFallback)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.lg)
                        .id("loading")
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
            .onChange(of: messages.count) { _ in
                withAnimation {
                    proxy.scrollTo(messages.last?.id ?? "loading", anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == "user" { Spacer(minLength: 60) }

            VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(msg.content)
                    .font(.loCaption)
                    .foregroundColor(msg.role == "user" ? .white : Color.loPrimaryFallback)
                    .lineSpacing(3)

                if let time = msg.timestamp {
                    Text(formatTime(time))
                        .font(.system(size: 9))
                        .foregroundColor(msg.role == "user" ? .white.opacity(0.6) : Color.loTertiaryFallback)
                }
            }
            .padding(Spacing.md)
            .background(
                msg.role == "user"
                    ? Color.loAccentFallback
                    : Color.loSurfaceFallback
            )
            .cornerRadius(16)
            .cornerRadius(msg.role == "user" ? 16 : 16)

            if msg.role == "assistant" { Spacer(minLength: 60) }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Ask your mentor...", text: $inputText, axis: .vertical)
                .font(.loCaption)
                .foregroundColor(Color.loPrimaryFallback)
                .lineLimit(1...4)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.loSurfaceFallback)
                .cornerRadius(20)

            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.isEmpty || isSending ? Color.loTertiaryFallback : Color.loAccentFallback)
            }
            .disabled(inputText.isEmpty || isSending)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color.loBackgroundFallback)
    }

    // MARK: - Actions

    private func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMsg = ChatMessage(
            id: UUID().uuidString,
            role: "user",
            content: text,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        messages.append(userMsg)
        inputText = ""
        isSending = true

        do {
            let response = try await APIClient.shared.sendMentorMessage(message: text)
            if let assistantMsg = response.message {
                messages.append(assistantMsg)
            }
        } catch {
            let errorMsg = ChatMessage(
                id: UUID().uuidString,
                role: "assistant",
                content: "Sorry, I couldn't process that. Please try again.",
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            messages.append(errorMsg)
        }

        isSending = false
    }

    private func loadHistory() async {
        isLoading = true
        do {
            let history = try await APIClient.shared.getMentorHistory()
            messages = history.messages
        } catch {}
        isLoading = false
    }

    private func loadInsight() async {
        do {
            let result = try await APIClient.shared.getMentorInsight()
            if let text = result.insight, !text.isEmpty {
                proactiveInsight = text
                withAnimation { showInsight = true }
            }
        } catch {}
    }

    private func formatTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return "" }
        let display = DateFormatter()
        display.dateFormat = "HH:mm"
        return display.string(from: date)
    }
}
