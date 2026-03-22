import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var retentionPolicy = "after_transcription"
    @State private var retentionDays: Double = 30
    @State private var encryptAudio = true
    @State private var coachingEnabled = true
    @State private var language = "ru"
    @State private var showDeleteAlert = false

    // Plaud NotePin
    @State private var plaudConnected = false
    @State private var showPlaudConnect = false
    @State private var plaudToken = ""
    @State private var plaudRegion = "us"
    @State private var isSyncingPlaud = false
    @State private var plaudSyncResult: Int?

    // Google Calendar
    @State private var calendarConnected = false

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

                    // MARK: - Plaud NotePin

                    LOSectionHeader(title: "Plaud NotePin")

                    VStack(spacing: 0) {
                        settingsRow {
                            HStack {
                                Image(systemName: "waveform.circle")
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundColor(plaudConnected ? Color.loAccentFallback : Color.loTertiaryFallback)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Plaud NotePin")
                                        .font(.loBody)
                                        .foregroundColor(Color.loPrimaryFallback)
                                    Text(plaudConnected ? "Connected" : "Not connected")
                                        .font(.loMicro)
                                        .foregroundColor(plaudConnected ? Color.loAccentFallback : Color.loTertiaryFallback)
                                }
                                Spacer()
                                if !plaudConnected {
                                    LOButton(title: "Connect", style: .secondary) {
                                        showPlaudConnect = true
                                    }
                                }
                            }
                        }

                        if plaudConnected {
                            LODivider().padding(.leading, Spacing.md)

                            settingsAction("Sync recordings now", icon: "arrow.triangle.2.circlepath") {
                                Task { await syncPlaud() }
                            }

                            if isSyncingPlaud {
                                HStack {
                                    ProgressView()
                                        .tint(Color.loAccentFallback)
                                    Text("Syncing...")
                                        .font(.loCaption)
                                        .foregroundColor(Color.loTertiaryFallback)
                                }
                                .padding(.horizontal, Spacing.md)
                                .padding(.bottom, Spacing.sm)
                            }

                            if let result = plaudSyncResult {
                                HStack(spacing: Spacing.sm) {
                                    Text("\(result) new recordings synced")
                                        .font(.loMicro)
                                        .foregroundColor(Color.loAccentFallback)
                                }
                                .padding(.horizontal, Spacing.md)
                                .padding(.bottom, Spacing.sm)
                            }

                            LODivider().padding(.leading, Spacing.md)

                            settingsAction("Disconnect", icon: "xmark.circle", isDestructive: true) {
                                Task { await disconnectPlaud() }
                            }
                        }
                    }
                    .loCardStyle()
                    .padding(.horizontal, Spacing.lg)

                    // MARK: - Google Calendar

                    LOSectionHeader(title: "Google Calendar")

                    VStack(spacing: 0) {
                        settingsRow {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundColor(calendarConnected ? Color.loAccentFallback : Color.loTertiaryFallback)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Google Calendar")
                                        .font(.loBody)
                                        .foregroundColor(Color.loPrimaryFallback)
                                    Text(calendarConnected ? "Auto-sync enabled" : "Not connected")
                                        .font(.loMicro)
                                        .foregroundColor(calendarConnected ? Color.loAccentFallback : Color.loTertiaryFallback)
                                }
                                Spacer()
                            }
                        }

                        LODivider().padding(.leading, Spacing.md)

                        settingsRow {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Auto-sync meetings and tasks to Google Calendar when daily summary is generated")
                                    .font(.loMicro)
                                    .foregroundColor(Color.loTertiaryFallback)
                                    .lineSpacing(2)
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
                        Text("Nexor 0.1.0 (1)")
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
        .task { await checkIntegrations() }
        .sheet(isPresented: $showPlaudConnect) {
            PlaudConnectSheet(isPresented: $showPlaudConnect, plaudConnected: $plaudConnected)
        }
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

    // MARK: - Plaud Actions

    private func checkIntegrations() async {
        do {
            let status = try await APIClient.shared.getPlaudStatus()
            plaudConnected = status.connected
        } catch {}
        do {
            let status = try await APIClient.shared.getCalendarStatus()
            calendarConnected = status.connected
        } catch {}
    }

    private func syncPlaud() async {
        isSyncingPlaud = true
        plaudSyncResult = nil
        do {
            let result = try await APIClient.shared.syncAllPlaud()
            plaudSyncResult = result.newlySynced ?? 0
        } catch {}
        isSyncingPlaud = false
    }

    private func disconnectPlaud() async {
        do {
            _ = try await APIClient.shared.disconnectPlaud()
            plaudConnected = false
        } catch {}
    }
}

// MARK: - Plaud Connect Sheet

struct PlaudConnectSheet: View {
    @Binding var isPresented: Bool
    @Binding var plaudConnected: Bool
    @State private var token = ""
    @State private var region = "us"
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.loBackgroundFallback.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text("Connect Plaud NotePin")
                            .font(.loTitle)
                            .foregroundColor(Color.loPrimaryFallback)

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("HOW TO GET TOKEN")
                                .font(.loMicro)
                                .tracking(1)
                                .foregroundColor(Color.loTertiaryFallback)

                            stepRow(1, "Open web.plaud.ai and log in")
                            stepRow(2, "Open DevTools (F12) — Network tab")
                            stepRow(3, "Refresh the page")
                            stepRow(4, "Find request to api.plaud.ai")
                            stepRow(5, "Copy the Authorization header value")
                        }

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("BEARER TOKEN")
                                .font(.loMicro)
                                .tracking(1)
                                .foregroundColor(Color.loTertiaryFallback)

                            TextField("Paste token here...", text: $token)
                                .font(.loMonoSmall)
                                .textFieldStyle(.plain)
                                .padding(Spacing.sm)
                                .background(Color.loSurfaceFallback)
                                .cornerRadius(8)
                                .foregroundColor(Color.loPrimaryFallback)
                        }

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("REGION")
                                .font(.loMicro)
                                .tracking(1)
                                .foregroundColor(Color.loTertiaryFallback)

                            Picker("", selection: $region) {
                                Text("US").tag("us")
                                Text("EU").tag("eu")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.loCaption)
                                .foregroundColor(.red)
                        }

                        LOButton(title: isConnecting ? "Connecting..." : "Connect", style: .primary) {
                            Task { await connect() }
                        }
                        .disabled(token.isEmpty || isConnecting)
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(Color.loTertiaryFallback)
                }
            }
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("\(number)")
                .font(.loMonoSmall)
                .foregroundColor(Color.loAccentFallback)
                .frame(width: 20)
            Text(text)
                .font(.loCaption)
                .foregroundColor(Color.loPrimaryFallback)
        }
    }

    private func connect() async {
        isConnecting = true
        errorMessage = nil
        do {
            _ = try await APIClient.shared.connectPlaud(token: token, region: region)
            plaudConnected = true
            isPresented = false
        } catch {
            errorMessage = "Connection failed: \(error.localizedDescription)"
        }
        isConnecting = false
    }
}
