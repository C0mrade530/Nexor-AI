import SwiftUI
import UserNotifications

@main
struct LifeOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    NavigationStack {
                        ContentView()
                    }
                    .environmentObject(appState)
                } else {
                    OnboardingView()
                        .environmentObject(appState)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: appState.isAuthenticated)
            .preferredColorScheme(nil)  // follow system
            .task {
                // Request notification permission on first launch
                _ = await NotificationService.shared.requestPermission()
                // Schedule daily summary reminder
                NotificationService.shared.scheduleDailySummaryReminder()
            }
        }
    }
}

/// App delegate for handling push notification registration.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            NotificationService.shared.registerToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Push registration failed: \(error)")
    }

    // Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}

/// Global app state — auth, onboarding, server config.
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "nexor_server_url")
            APIClient.shared.updateBaseURL(serverURL)
        }
    }
    @Published var userName: String = ""

    init() {
        self.serverURL = UserDefaults.standard.string(forKey: "nexor_server_url")
            ?? "http://localhost:8000/api/v1"

        if let token = KeychainHelper.load(key: "nexor_auth_token") {
            APIClient.shared.setAuthToken(token)
            isAuthenticated = true
        }

        if let url = UserDefaults.standard.string(forKey: "nexor_server_url") {
            APIClient.shared.updateBaseURL(url)
        }
    }

    func signIn(email: String, password: String) async throws {
        // TODO: Real auth endpoint
        let token = "demo-token"
        KeychainHelper.save(key: "nexor_auth_token", value: token)
        APIClient.shared.setAuthToken(token)
        isAuthenticated = true
    }

    func signOut() {
        KeychainHelper.delete(key: "nexor_auth_token")
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
