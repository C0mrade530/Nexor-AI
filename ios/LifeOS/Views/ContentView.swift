import SwiftUI

/// Main tab view for LifeOS app.
struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            InboxView()
                .tabItem {
                    Image(systemName: "tray.fill")
                    Text("Inbox")
                }

            RecordView()
                .tabItem {
                    Image(systemName: "mic.circle.fill")
                    Text("Record")
                }

            DailySummaryView()
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Summary")
                }

            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }

            SettingsView()
                .environmentObject(appState)
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}
