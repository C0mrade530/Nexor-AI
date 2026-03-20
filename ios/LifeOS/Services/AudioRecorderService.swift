import AVFoundation
import Foundation

/// Manages audio recording, chunking, and background capture.
class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var currentSessionId: String?
    @Published var recordingDuration: TimeInterval = 0
    @Published var consentMode: String = "private"

    private var audioRecorder: AVAudioRecorder?
    private var chunkTimer: Timer?
    private var durationTimer: Timer?
    private var currentChunkIndex = 0
    private var chunkDuration: TimeInterval = 300 // 5 minutes
    private var recordingStartTime: Date?

    private let api = APIClient.shared

    // MARK: - Recording Control

    func startRecording(consent: String = "private") async throws {
        consentMode = consent

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true)

        // Create backend session
        let session = try await api.createSession(
            source: "iphone_app",
            consentMode: consent
        )
        currentSessionId = session.id
        currentChunkIndex = 0
        recordingStartTime = Date()

        // Start first chunk
        try startNewChunk()

        isRecording = true

        // Start chunk rotation timer
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: true) { [weak self] _ in
            Task { try? await self?.rotateChunk() }
        }

        // Duration tracking
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            if let start = self?.recordingStartTime {
                self?.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    func stopRecording() async throws {
        chunkTimer?.invalidate()
        durationTimer?.invalidate()
        audioRecorder?.stop()

        // Upload final chunk
        if let chunkURL = currentChunkURL() {
            try await uploadChunk(url: chunkURL)
        }

        // Finish session
        if let sessionId = currentSessionId {
            _ = try await api.finishSession(sessionId: sessionId)
        }

        isRecording = false
        recordingDuration = 0
        currentSessionId = nil
    }

    func markImportantMoment() {
        // TODO: Add marker to current timestamp for priority processing
    }

    func togglePrivateMode() {
        consentMode = consentMode == "private" ? "meeting" : "private"
    }

    // MARK: - Private

    private func startNewChunk() throws {
        let url = chunkFileURL(index: currentChunkIndex)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
    }

    private func rotateChunk() async throws {
        audioRecorder?.stop()

        if let chunkURL = currentChunkURL() {
            try await uploadChunk(url: chunkURL)
        }

        currentChunkIndex += 1
        try startNewChunk()
    }

    private func uploadChunk(url: URL) async throws {
        guard let sessionId = currentSessionId else { return }
        let data = try Data(contentsOf: url)
        _ = try await api.uploadChunk(
            sessionId: sessionId,
            audioData: data,
            filename: url.lastPathComponent
        )
        // Clean up local file after upload
        try? FileManager.default.removeItem(at: url)
    }

    private func chunkFileURL(index: Int) -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lifeos_audio")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chunk_\(String(format: "%04d", index)).wav")
    }

    private func currentChunkURL() -> URL? {
        let url = chunkFileURL(index: currentChunkIndex)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
