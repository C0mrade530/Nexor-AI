import SwiftUI

struct RecordView: View {
    @StateObject private var recorder = AudioRecorderService()
    @State private var showSessionsList = false

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                // Recording indicator
                ZStack {
                    // Pulsing ring when recording
                    if recorder.isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 4)
                            .frame(width: 150, height: 150)
                            .scaleEffect(recorder.isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: recorder.isRecording)
                    }

                    Circle()
                        .fill(recorder.isRecording ? Color.red : Color(.systemGray4))
                        .frame(width: 120, height: 120)
                        .shadow(color: recorder.isRecording ? .red.opacity(0.4) : .clear, radius: 12)
                        .overlay(
                            Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
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

                // Duration & status
                if recorder.isRecording {
                    VStack(spacing: 8) {
                        Text(formatDuration(recorder.recordingDuration))
                            .font(.system(.title, design: .monospaced))

                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("Recording")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Quick actions during recording
                    HStack(spacing: 24) {
                        Button {
                            recorder.markImportantMoment()
                        } label: {
                            VStack {
                                Image(systemName: "star.fill")
                                    .font(.title3)
                                Text("Mark")
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                } else {
                    Text("Tap to start recording")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Consent mode selector
                VStack(spacing: 8) {
                    Text("Recording Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Mode", selection: $recorder.consentMode) {
                        Label("Private", systemImage: "lock.fill").tag("private")
                        Label("Meeting", systemImage: "person.2.fill").tag("meeting")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 40)

                    Text(recorder.consentMode == "private"
                         ? "Personal thoughts and ideas only"
                         : "Conversation with others — consent required")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Error message
                if let error = recorder.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Record")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSessionsList.toggle()
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showSessionsList) {
                SessionsListView()
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

/// List of past recording sessions.
struct SessionsListView: View {
    @State private var sessions: [AudioSession] = []
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else if sessions.isEmpty {
                    VStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No recordings yet")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(session.status.capitalized)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(statusColor(session.status).opacity(0.15))
                                    .foregroundColor(statusColor(session.status))
                                    .cornerRadius(4)

                                Spacer()

                                if let duration = session.durationSeconds {
                                    Text("\(Int(duration / 60)) min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)

                            Text("Source: \(session.source)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                do {
                    sessions = try await APIClient.shared.listSessions()
                } catch {
                    // empty
                }
                isLoading = false
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "processed": return .green
        case "processing": return .blue
        case "uploaded": return .orange
        case "recording": return .red
        default: return .gray
        }
    }
}
