import SwiftUI

struct RecordView: View {
    @StateObject private var recorder = AudioRecorderService()
    @State private var showSessions = false
    @State private var breathScale: CGFloat = 1.0
    @State private var ringRotation: Double = 0

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("Record")
                        .font(.loTitle)
                        .foregroundColor(Color.loPrimaryFallback)
                    Spacer()
                    Button {
                        showSessions = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(Color.loSecondaryFallback)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

                Spacer()

                // Central orb
                ZStack {
                    // Outer breathing ring
                    if recorder.isRecording {
                        Circle()
                            .stroke(
                                Color.loAccentFallback.opacity(0.08),
                                lineWidth: 1
                            )
                            .frame(width: 220, height: 220)
                            .scaleEffect(breathScale)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                                    breathScale = 1.15
                                }
                            }
                            .onDisappear { breathScale = 1.0 }

                        // Rotating arc
                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(
                                Color.loAccentFallback.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                            )
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(ringRotation))
                            .onAppear {
                                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                                    ringRotation = 360
                                }
                            }
                            .onDisappear { ringRotation = 0 }
                    }

                    // Main circle
                    Circle()
                        .fill(
                            recorder.isRecording
                                ? Color.loAccentFallback.opacity(0.1)
                                : Color.loSurfaceFallback
                        )
                        .frame(width: 160, height: 160)
                        .overlay(
                            Circle()
                                .stroke(
                                    recorder.isRecording
                                        ? Color.loAccentFallback.opacity(0.4)
                                        : Color.loTertiaryFallback.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        .overlay(
                            Group {
                                if recorder.isRecording {
                                    // Stop icon — minimal square
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.loAccentFallback)
                                        .frame(width: 24, height: 24)
                                } else {
                                    // Mic icon
                                    Image(systemName: "mic")
                                        .font(.system(size: 32, weight: .ultraLight))
                                        .foregroundColor(Color.loPrimaryFallback)
                                }
                            }
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
                }

                // Duration
                if recorder.isRecording {
                    VStack(spacing: Spacing.xs) {
                        Text(formatDuration(recorder.recordingDuration))
                            .font(.loMono)
                            .foregroundColor(Color.loPrimaryFallback)
                            .padding(.top, Spacing.xl)

                        HStack(spacing: Spacing.xxs) {
                            Circle()
                                .fill(Color.loAccentFallback)
                                .frame(width: 6, height: 6)
                            Text("Recording")
                                .font(.loMicro)
                                .tracking(0.8)
                                .textCase(.uppercase)
                                .foregroundColor(Color.loSecondaryFallback)
                        }
                    }
                } else {
                    Text("Tap to begin")
                        .font(.loCaption)
                        .foregroundColor(Color.loTertiaryFallback)
                        .padding(.top, Spacing.xl)
                }

                Spacer()

                // Bottom controls
                VStack(spacing: Spacing.lg) {
                    // Mark moment button (only during recording)
                    if recorder.isRecording {
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) {
                                recorder.markImportantMoment()
                            }
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "star")
                                    .font(.system(size: 14, weight: .light))
                                Text("Mark moment")
                                    .font(.loCaption)
                            }
                            .foregroundColor(Color.loSecondaryFallback)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .overlay(
                                Capsule()
                                    .stroke(Color.loTertiaryFallback.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                    }

                    // Mode selector
                    HStack(spacing: Spacing.xxl) {
                        modeButton("Private", icon: "lock", isSelected: recorder.consentMode == "private") {
                            recorder.consentMode = "private"
                        }
                        modeButton("Meeting", icon: "person.2", isSelected: recorder.consentMode == "meeting") {
                            recorder.consentMode = "meeting"
                        }
                    }
                    .padding(.bottom, Spacing.lg)
                }

                // Error
                if let error = recorder.errorMessage {
                    Text(error)
                        .font(.loCaption)
                        .foregroundColor(Color.loDestructive)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.sm)
                }
            }
        }
        .sheet(isPresented: $showSessions) {
            SessionsListView()
        }
    }

    // MARK: - Helpers

    private func modeButton(_ label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .regular : .ultraLight))
                    .foregroundColor(isSelected ? Color.loPrimaryFallback : Color.loTertiaryFallback)
                Text(label)
                    .font(.loMicro)
                    .foregroundColor(isSelected ? Color.loPrimaryFallback : Color.loTertiaryFallback)
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Sessions List (Sheet)

struct SessionsListView: View {
    @State private var sessions: [AudioSession] = []
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Sessions")
                        .font(.loTitle)
                        .foregroundColor(Color.loPrimaryFallback)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(Color.loSecondaryFallback)
                            .frame(width: 28, height: 28)
                            .background(Color.loSurfaceFallback)
                            .clipShape(Circle())
                    }
                }
                .padding(Spacing.lg)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color.loTertiaryFallback)
                    Spacer()
                } else if sessions.isEmpty {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "waveform")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(Color.loTertiaryFallback)
                        Text("No recordings yet")
                            .font(.loCaption)
                            .foregroundColor(Color.loTertiaryFallback)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.xs) {
                            ForEach(sessions) { session in
                                sessionRow(session)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                    }
                }
            }
        }
        .task {
            do { sessions = try await APIClient.shared.listSessions() } catch {}
            isLoading = false
        }
    }

    private func sessionRow(_ session: AudioSession) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(statusColor(session.status))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.loBody)
                    .foregroundColor(Color.loPrimaryFallback)
                HStack(spacing: Spacing.xs) {
                    Text(session.status)
                        .font(.loMicro)
                        .foregroundColor(Color.loSecondaryFallback)
                    if let d = session.durationSeconds {
                        Text("\(Int(d / 60))m")
                            .font(.loMicro)
                            .foregroundColor(Color.loTertiaryFallback)
                    }
                }
            }

            Spacer()
        }
        .padding(Spacing.sm)
        .loCardStyle()
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "processed": return .green.opacity(0.8)
        case "processing": return Color.loAccentFallback
        case "recording": return .red.opacity(0.8)
        default: return Color.loTertiaryFallback
        }
    }
}
