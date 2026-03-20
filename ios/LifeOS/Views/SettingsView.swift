import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var retentionPolicy = "after_transcription"
    @State private var retentionDays: Double = 30
    @State private var encryptAudio = true
    @State private var coachingEnabled = true
    @State private var language = "ru"
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Settings")
                        .font(.loTitle)
                        .foregroundColor(Color.loPrimaryFallback)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.lg)

                    // MARK: - Privacy

                    LOSectionHeader(title: "Privacy")

                    VStack(spacing: 0) {
                        settingsRow {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Audio Retention")
                                    .font(.loBody)
                                    .foregroundColor(Color.loPrimaryFallback)
                                Picker("", selection: $retentionPolicy) {
                                    Text("Keep all").tag("keep_all")
                                    Text("After transcription").tag("after_transcription")
                                    Text("Summaries only").tag("summaries_only")
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        LODivider().padding(.leading, Spacing.md)

                        settingsRow {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                HStack {
                                    Text("Retention period")
                                        .font(.loBody)
                                        .foregroundColor(Color.loPrimaryFallback)
                                    Spacer()
                                    Text("\(Int(retentionDays)) days")
                                        .font(.loMonoSmall)
                                        .foregroundColor(Color.loTertiaryFallback)
                                }
                                Slider(value: $retentionDays, in: 1...365, step: 1)
                                    .tint(Color.loAccentFallback)
                            }
                        }

                        LODivider().padding(.leading, Spacing.md)

                        settingsToggle("Encrypt at rest", isOn: $encryptAudio)
                    }
                    .loCardStyle()
                    .padding(.horizontal, Spacing.lg)

                    // MARK: - AI

                    LOSectionHeader(title: "Intelligence")

                    VStack(spacing: 0) {
                        settingsToggle("Daily coaching", isOn: $coachingEnabled)

                        LODivider().padding(.leading, Spacing.md)

                        settingsRow {
                            HStack {
                                Text("Language")
                                    .font(.loBody)
                                    .foregroundColor(Color.loPrimaryFallback)
                                Spacer()
                                Picker("", selection: $language) {
                                    Text("RU").tag("ru")
                                    Text("EN").tag("en")
                                    Text("Auto").tag("auto")
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 160)
                            }
                        }
                    }
                    .loCardStyle()
                    .padding(.horizontal, Spacing.lg)

                    // MARK: - Server

                    LOSectionHeader(title: "Connection")

                    VStack(spacing: 0) {
                        settingsRow {
                            HStack {
                                Text("Server")
                                    .font(.loBody)
                                    .foregroundColor(Color.loPrimaryFallback)
                                Spacer()
                                Text(appState.serverURL)
                                    .font(.loMicro)
                                    .foregroundColor(Color.loTertiaryFallback)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .loCardStyle()
                    .padding(.horizontal, Spacing.lg)

                    // MARK: - Data

                    LOSectionHeader(title: "Data")

                    VStack(spacing: 0) {
                        settingsAction("Export all data", icon: "arrow.down.doc") {
                            // TODO
                        }

                        LODivider().padding(.leading, Spacing.md)

                        settingsAction("Delete all data", icon: "trash", isDestructive: true) {
                            showDeleteAlert = true
                        }
                    }
                    .loCardStyle()
                    .padding(.horizontal, Spacing.lg)

                    // MARK: - Account

                    LOSectionHeader(title: "Account")

                    VStack(spacing: 0) {
                        settingsAction("Sign out", icon: "rectangle.portrait.and.arrow.forward", isDestructive: true) {
                            appState.signOut()
                        }
                    }
                    .loCardStyle()
                    .padding(.horizontal, Spacing.lg)

                    // Version
                    HStack {
                        Spacer()
                        Text("LifeOS 0.1.0 (1)")
                            .font(.loMicro)
                            .foregroundColor(Color.loTertiaryFallback.opacity(0.5))
                        Spacer()
                    }
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.xxl)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Delete all data?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // TODO: API call
            }
        } message: {
            Text("This permanently removes all recordings, events, and summaries.")
        }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
    }

    private func settingsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        settingsRow {
            Toggle(isOn: isOn) {
                Text(label)
                    .font(.loBody)
                    .foregroundColor(Color.loPrimaryFallback)
            }
            .tint(Color.loAccentFallback)
        }
    }

    private func settingsAction(_ label: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                Text(label)
                    .font(.loBody)
                Spacer()
            }
            .foregroundColor(isDestructive ? Color.loDestructive : Color.loPrimaryFallback)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }
}
