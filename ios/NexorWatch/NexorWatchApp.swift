import SwiftUI

@main
struct NexorWatchApp: App {
    @StateObject private var healthMonitor = WatchHealthMonitor()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(healthMonitor)
        }
    }
}
