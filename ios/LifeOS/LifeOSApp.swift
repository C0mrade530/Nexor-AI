import SwiftUI

@main
struct LifeOSApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                ContentView()
                    .environmentObject(appState)
            } else {
                OnboardingView()
                    .environmentObject(appState)
            }
        }
    }
}

/// Global app state — auth, onboarding, server config.
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "lifeos_server_url")
            APIClient.shared.updateBaseURL(serverURL)
        }
    }
    @Published var userName: String = ""

    init() {
        self.serverURL = UserDefaults.standard.string(forKey: "lifeos_server_url")
            ?? "http://localhost:8000/api/v1"

        if let token = KeychainHelper.load(key: "lifeos_auth_token") {
            APIClient.shared.setAuthToken(token)
            isAuthenticated = true
        }

        if let url = UserDefaults.standard.string(forKey: "lifeos_server_url") {
            APIClient.shared.updateBaseURL(url)
        }
    }

    func signIn(email: String, password: String) async throws {
        // TODO: Real auth endpoint
        let token = "demo-token"
        KeychainHelper.save(key: "lifeos_auth_token", value: token)
        APIClient.shared.setAuthToken(token)
        isAuthenticated = true
    }

    func signOut() {
        KeychainHelper.delete(key: "lifeos_auth_token")
        APIClient.shared.setAuthToken("")
        isAuthenticated = false
    }

    func skipAuth() {
        isAuthenticated = true
    }
}

/// Minimal Keychain wrapper for auth token storage.
enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
