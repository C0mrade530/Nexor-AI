import AVFoundation
import SwiftUI
import WatchKit

struct WatchRecordView: View {
    @State private var isRecording = false
    @State private var duration: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 16) {
            // Waveform indicator
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: isRecording ? "waveform" : "mic")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(isRecording ? .red : .orange)
                    .symbolEffect(.pulse, isActive: isRecording)
            }

            // Timer
            Text(formatDuration(duration))
                .font(.system(size: 20, weight: .light, design: .monospaced))
                .foregroundColor(isRecording ? .red : .secondary)

            // Record/Stop button
            Button {
                toggleRecording()
            } label: {
                Text(isRecording ? "Stop" : "Start")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isRecording ? Color.red : Color.orange)
                    .foregroundColor(isRecording ? .white : .black)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Record")
        .onDisappear {
            stopRecording()
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        duration = 0
        WKInterfaceDevice.current().play(.start)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                duration += 1
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        timer?.invalidate()
        timer = nil
        WKInterfaceDevice.current().play(.stop)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
