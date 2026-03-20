import SwiftUI

/// Onboarding / auth screen shown on first launch.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var serverURL: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var showServerConfig = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Logo area
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.gradient)

                    Text("LifeOS")
                        .font(.largeTitle.bold())

                    Text("Your AI memory assistant")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Auth form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        Task {
                            isLoading = true
                            errorMessage = nil
                            do {
                                try await appState.signIn(email: email, password: password)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                }
                .padding(.horizontal, 32)

                // Skip for MVP
                Button("Continue without account") {
                    appState.skipAuth()
                }
                .font(.footnote)
                .foregroundColor(.secondary)

                // Server config
                Button {
                    showServerConfig.toggle()
                } label: {
                    HStack {
                        Image(systemName: "server.rack")
                        Text("Server Settings")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }

                if showServerConfig {
                    HStack {
                        TextField("Server URL", text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .autocapitalization(.none)

                        Button("Save") {
                            appState.serverURL = serverURL
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()
            }
            .onAppear {
                serverURL = appState.serverURL
            }
        }
    }
}
