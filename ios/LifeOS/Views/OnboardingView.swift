import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showAuth = false
    @State private var showPermissions = false
    @State private var serverURL = ""
    @State private var showServerConfig = false

    // Permissions state
    @State private var micGranted = false
    @State private var healthGranted = false
    @State private var notifGranted = false

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            if showAuth {
                authView
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if showPermissions {
                permissionsView
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                onboardingPages
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .onAppear { serverURL = appState.serverURL }
    }

    // MARK: - Onboarding Pages

    private var onboardingPages: some View {
        VStack(spacing: 0) {
            Spacer()

            TabView(selection: $currentPage) {
                onboardingPage(
                    icon: "waveform",
                    title: "Record",
                    subtitle: "Capture your day\nin the background"
                ).tag(0)

                onboardingPage(
                    icon: "sparkle",
                    title: "Understand",
                    subtitle: "AI segments your speech\ninto events, ideas, and tasks"
                ).tag(1)

                onboardingPage(
                    icon: "heart",
                    title: "Energy",
                    subtitle: "Apple Watch tracks sleep,\nsteps, and workouts"
                ).tag(2)

                onboardingPage(
                    icon: "banknote",
                    title: "Finance",
                    subtitle: "Import Tinkoff statements\nand get AI spending advice"
                ).tag(3)

                onboardingPage(
                    icon: "paperplane",
                    title: "Telegram",
                    subtitle: "Send voice messages\nand get reminders in chat"
                ).tag(4)

                onboardingPage(
                    icon: "arrow.up.right",
                    title: "Grow",
                    subtitle: "Daily coaching from a\n$1M AI mentor"
                ).tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 340)

            // Page indicators
            HStack(spacing: Spacing.xs) {
                ForEach(0..<6, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? Color.loPrimaryFallback : Color.loTertiaryFallback.opacity(0.4))
                        .frame(width: i == currentPage ? 24 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.top, Spacing.xl)

            Spacer()

            // CTA
            VStack(spacing: Spacing.sm) {
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showPermissions = true
                    }
                } label: {
                    Text("Get Started")
                        .font(.loHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.loPrimaryFallback)
                        .foregroundColor(Color.loBackgroundFallback)
                        .cornerRadius(12)
                }

                Button("Skip for now") {
                    appState.skipAuth()
                }
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private func onboardingPage(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Color.loAccentFallback)

            Text(title)
                .font(.loLargeTitle)
                .foregroundColor(Color.loPrimaryFallback)

            Text(subtitle)
                .font(.loBody)
                .foregroundColor(Color.loSecondaryFallback)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: - Permissions View

    private var permissionsView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showPermissions = false
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(Color.loPrimaryFallback)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)

            Spacer()

            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.xs) {
                    Text("Permissions")
                        .font(.loLargeTitle)
                        .foregroundColor(Color.loPrimaryFallback)
                    Text("Nexor needs a few permissions to work")
                        .font(.loBody)
                        .foregroundColor(Color.loSecondaryFallback)
                }

                VStack(spacing: Spacing.md) {
                    permissionRow(
                        icon: "mic",
                        title: "Microphone",
                        description: "Record audio throughout your day",
                        granted: micGranted
                    ) {
                        // Mic permission handled on first recording
                        micGranted = true
                    }

                    permissionRow(
                        icon: "heart",
                        title: "HealthKit",
                        description: "Sleep, steps, workouts from Apple Watch",
                        granted: healthGranted
                    ) {
                        Task {
                            healthGranted = await HealthKitService.shared.requestAuthorization()
                        }
                    }

                    permissionRow(
                        icon: "bell",
                        title: "Notifications",
                        description: "Reminders and daily summary alerts",
                        granted: notifGranted
                    ) {
                        Task {
                            notifGranted = await NotificationService.shared.requestPermission()
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }

            Spacer()

            VStack(spacing: Spacing.sm) {
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showPermissions = false
                        showAuth = true
                    }
                } label: {
                    Text("Continue")
                        .font(.loHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.loPrimaryFallback)
                        .foregroundColor(Color.loBackgroundFallback)
                        .cornerRadius(12)
                }

                Button("Skip permissions") {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showPermissions = false
                        showAuth = true
                    }
                }
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(granted ? .green : Color.loAccentFallback)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.loBody)
                    .foregroundColor(Color.loPrimaryFallback)
                Text(description)
                    .font(.loMicro)
                    .foregroundColor(Color.loTertiaryFallback)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Allow") { action() }
                    .font(.loCaption)
                    .foregroundColor(Color.loAccentFallback)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.loAccentFallback, lineWidth: 1)
                    )
            }
        }
        .padding(Spacing.sm)
        .background(Color.loSurfaceFallback)
        .cornerRadius(12)
    }

    // MARK: - Auth View

    private var authView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showAuth = false
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(Color.loPrimaryFallback)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)

            Spacer()

            VStack(spacing: Spacing.xxl) {
                VStack(spacing: Spacing.xs) {
                    Text("Welcome")
                        .font(.loLargeTitle)
                        .foregroundColor(Color.loPrimaryFallback)
                    Text("Sign in to sync your memory")
                        .font(.loBody)
                        .foregroundColor(Color.loSecondaryFallback)
                }

                VStack(spacing: Spacing.sm) {
                    MinimalTextField(placeholder: "Email", text: $email, isSecure: false)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)

                    MinimalTextField(placeholder: "Password", text: $password, isSecure: true)
                        .textContentType(.password)
                }
                .padding(.horizontal, Spacing.xl)

                VStack(spacing: Spacing.sm) {
                    Button {
                        Task {
                            isLoading = true
                            try? await appState.signIn(email: email, password: password)
                            isLoading = false
                        }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                                    .tint(Color.loBackgroundFallback)
                            } else {
                                Text("Continue")
                                    .font(.loHeadline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.loPrimaryFallback)
                        .foregroundColor(Color.loBackgroundFallback)
                        .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                    .opacity(email.isEmpty || password.isEmpty ? 0.4 : 1)

                    Button("Continue without account") {
                        appState.skipAuth()
                    }
                    .font(.loCaption)
                    .foregroundColor(Color.loTertiaryFallback)
                }
                .padding(.horizontal, Spacing.xl)
            }

            Spacer()

            // Server config (hidden by default)
            Button {
                withAnimation { showServerConfig.toggle() }
            } label: {
                Image(systemName: "server.rack")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color.loTertiaryFallback)
            }

            if showServerConfig {
                HStack(spacing: Spacing.xs) {
                    MinimalTextField(placeholder: "Server URL", text: $serverURL, isSecure: false)
                        .font(.loMonoSmall)
                    Button("Save") {
                        appState.serverURL = serverURL
                    }
                    .font(.loMicro)
                    .foregroundColor(Color.loAccentFallback)
                }
                .padding(.horizontal, Spacing.xl)
                .transition(.opacity)
            }

            Spacer().frame(height: Spacing.xxl)
        }
    }
}

// MARK: - Minimal Text Field

struct MinimalTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isSecure {
                SecureField("", text: $text, prompt: promptText)
                    .focused($isFocused)
                    .font(.loBody)
                    .foregroundColor(Color.loPrimaryFallback)
                    .padding(.vertical, Spacing.sm)
            } else {
                TextField("", text: $text, prompt: promptText)
                    .focused($isFocused)
                    .font(.loBody)
                    .foregroundColor(Color.loPrimaryFallback)
                    .padding(.vertical, Spacing.sm)
            }

            Rectangle()
                .fill(isFocused ? Color.loPrimaryFallback : Color.loTertiaryFallback.opacity(0.3))
                .frame(height: isFocused ? 1.5 : 0.5)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }

    private var promptText: Text {
        Text(placeholder)
            .foregroundColor(Color.loTertiaryFallback)
    }
}
