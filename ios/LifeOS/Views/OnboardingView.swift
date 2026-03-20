import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showAuth = false
    @State private var serverURL = ""
    @State private var showServerConfig = false

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            if showAuth {
                authView
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
                    subtitle: "AI segments your speech\ninto events and ideas"
                ).tag(1)

                onboardingPage(
                    icon: "arrow.up.right",
                    title: "Act",
                    subtitle: "Get summaries, tasks,\nand coaching daily"
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 340)

            // Page indicators
            HStack(spacing: Spacing.xs) {
                ForEach(0..<3, id: \.self) { i in
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
                        showAuth = true
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
