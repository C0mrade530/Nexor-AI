import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var retentionPolicy = "after_transcription"
    @State private var retentionDays = 30.0
    @State private var encryptAudio = true
    @State private var coachingEnabled = true
    @State private var language = "ru"
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                Section("Privacy & Data") {
                    Picker("Audio Retention", selection: $retentionPolicy) {
                        Text("Keep All Audio").tag("keep_all")
                        Text("Delete After Transcription").tag("after_transcription")
                        Text("Keep Summaries Only").tag("summaries_only")
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text("Retention Period")
                            Spacer()
                            Text("\(Int(retentionDays)) days")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $retentionDays, in: 1...365, step: 1)
                    }

                    Toggle("Encrypt Audio at Rest", isOn: $encryptAudio)
                }

                Section("AI Features") {
                    Toggle("Daily Coaching Feedback", isOn: $coachingEnabled)

                    Picker("Primary Language", selection: $language) {
                        Text("Russian").tag("ru")
                        Text("English").tag("en")
                        Text("Auto-detect").tag("auto")
                    }
                }

                Section("Server") {
                    HStack {
                        Text("Server URL")
                        Spacer()
                        Text(appState.serverURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Section("Account") {
                    Button("Export All My Data") {
                        // TODO: trigger full data export
                    }

                    Button("Delete All My Data") {
                        showDeleteConfirmation = true
                    }
                    .foregroundColor(.red)

                    Button("Sign Out") {
                        appState.signOut()
                    }
                    .foregroundColor(.red)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0 MVP")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    // TODO: call delete API and clear local data
                }
            } message: {
                Text("This will permanently delete all your recordings, transcripts, events, and summaries. This action cannot be undone.")
            }
        }
    }
}
