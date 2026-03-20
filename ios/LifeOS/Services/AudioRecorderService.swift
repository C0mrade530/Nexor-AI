import AVFoundation
import Foundation

/// Manages audio recording, chunking, and background capture.
@MainActor
class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var currentSessionId: String?
    @Published var recordingDuration: TimeInterval = 0
    @Published var consentMode: String = "private"
    @Published var errorMessage: String?

    private var audioRecorder: AVAudioRecorder?
    private var chunkTimer: Timer?
    private var durationTimer: Timer?
    private var currentChunkIndex = 0
    private var chunkDuration: TimeInterval = 300 // 5 minutes
    private var recordingStartTime: Date?

    private let api = APIClient.shared

    // MARK: - Permissions

    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Recording Control

    func startRecording(consent: String = "private") async throws {
        // Check permission first
        let granted = await requestMicrophonePermission()
        guard granted else {
            errorMessage = "Microphone access denied. Enable in Settings > Privacy > Microphone."
            return
        }

        consentMode = consent
        errorMessage = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)

        // Create backend session
        do {
            let session = try await api.createSession(
                source: "iphone_app",
                consentMode: consent
            )
            currentSessionId = session.id
        } catch {
            // Offline mode — record locally, sync later
            currentSessionId = UUID().uuidString
        }

        currentChunkIndex = 0
        recordingStartTime = Date()

        // Start first chunk
        try startNewChunk()

        isRecording = true

        // Start chunk rotation timer
        chunkTimer = Timer.scheduledTimer(withTimeInterval: chunkDuration, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                try? await self.rotateChunk()
            }
        }

        // Duration tracking
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if let start = self.recordingStartTime {
                    self.recordingDuration = Date().timeIntervalSince(start)
                }
            }
        }
    }

    func stopRecording() async throws {
        chunkTimer?.invalidate()
        chunkTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil

        // Upload final chunk
        if let chunkURL = currentChunkURL() {
            try await uploadChunk(url: chunkURL)
        }

        // Finish session on backend
        if let sessionId = currentSessionId {
            do {
                _ = try await api.finishSession(sessionId: sessionId)
                // Trigger processing
                _ = try? await api.processSession(sessionId: sessionId)
            } catch {
                // Will sync later
            }
        }

        isRecording = false
        recordingDuration = 0
        currentSessionId = nil

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func markImportantMoment() {
        // Save marker with current timestamp for priority processing
        guard let start = recordingStartTime else { return }
        let offset = Date().timeIntervalSince(start)
        let marker = ImportantMarker(
            timestamp: Date(),
            offsetSeconds: offset,
            sessionId: currentSessionId ?? ""
        )
        var markers = loadMarkers()
        markers.append(marker)
        saveMarkers(markers)
    }

    // MARK: - Private — Recording

    private func startNewChunk() throws {
        let url = chunkFileURL(index: currentChunkIndex)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
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

        do {
            _ = try await api.uploadChunk(
                sessionId: sessionId,
                audioData: data,
                filename: url.lastPathComponent
            )
            // Clean up local file after successful upload
            try? FileManager.default.removeItem(at: url)
        } catch {
            // Keep file for later sync
            savePendingUpload(sessionId: sessionId, filePath: url.path)
        }
    }

    // MARK: - Private — File Management

    private func chunkFileURL(index: Int) -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lifeos_audio")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chunk_\(String(format: "%04d", index)).wav")
    }

    private func currentChunkURL() -> URL? {
        let url = chunkFileURL(index: currentChunkIndex)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Private — Offline Queue

    private func savePendingUpload(sessionId: String, filePath: String) {
        var pending = UserDefaults.standard.stringArray(forKey: "lifeos_pending_uploads") ?? []
        pending.append("\(sessionId)|\(filePath)")
        UserDefaults.standard.set(pending, forKey: "lifeos_pending_uploads")
    }

    func syncPendingUploads() async {
        guard let pending = UserDefaults.standard.stringArray(forKey: "lifeos_pending_uploads"),
              !pending.isEmpty else { return }

        var remaining: [String] = []
        for entry in pending {
            let parts = entry.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let sessionId = String(parts[0])
            let filePath = String(parts[1])
            let url = URL(fileURLWithPath: filePath)

            guard FileManager.default.fileExists(atPath: filePath) else { continue }

            do {
                let data = try Data(contentsOf: url)
                _ = try await api.uploadChunk(
                    sessionId: sessionId,
                    audioData: data,
                    filename: url.lastPathComponent
                )
                try? FileManager.default.removeItem(at: url)
            } catch {
                remaining.append(entry)
            }
        }
        UserDefaults.standard.set(remaining, forKey: "lifeos_pending_uploads")
    }

    // MARK: - Private — Markers

    private func loadMarkers() -> [ImportantMarker] {
        guard let data = UserDefaults.standard.data(forKey: "lifeos_markers"),
              let markers = try? JSONDecoder().decode([ImportantMarker].self, from: data) else {
            return []
        }
        return markers
    }

    private func saveMarkers(_ markers: [ImportantMarker]) {
        if let data = try? JSONEncoder().encode(markers) {
            UserDefaults.standard.set(data, forKey: "lifeos_markers")
        }
    }
}

struct ImportantMarker: Codable {
    let timestamp: Date
    let offsetSeconds: TimeInterval
    let sessionId: String
}
