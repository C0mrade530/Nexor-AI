import SwiftUI

/// Root navigation — custom minimal tab bar.
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .record

    enum Tab: String, CaseIterable {
        case inbox, record, summary, health, finance, search, settings

        var icon: String {
            switch self {
            case .inbox: return "tray"
            case .record: return "circle.fill"
            case .summary: return "text.alignleft"
            case .health: return "heart"
            case .finance: return "banknote"
            case .search: return "magnifyingglass"
            case .settings: return "slider.horizontal.3"
            }
        }

        var label: String {
            rawValue.capitalized
        }
    }

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                Group {
                    switch selectedTab {
                    case .inbox: InboxView()
                    case .record: RecordView()
                    case .summary: DailySummaryView()
                    case .health: HealthView()
                    case .finance: FinanceView()
                    case .search: SearchView()
                    case .settings: SettingsView().environmentObject(appState)
                    }
                }
                .frame(maxHeight: .infinity)

                // Tab bar
                LODivider()
                minimalTabBar
            }
        }
    }

    // MARK: - Minimal Tab Bar

    private var minimalTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: Spacing.xxs) {
                        if tab == .record {
                            // Record button is special — accent circle
                            Circle()
                                .fill(selectedTab == tab ? Color.loAccentFallback : Color.loTertiaryFallback.opacity(0.4))
                                .frame(width: 28, height: 28)
                        } else {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: selectedTab == tab ? .regular : .light))
                                .foregroundColor(selectedTab == tab ? Color.loPrimaryFallback : Color.loTertiaryFallback)
                        }

                        if selectedTab == tab && tab != .record {
                            Circle()
                                .fill(Color.loPrimaryFallback)
                                .frame(width: 3, height: 3)
                        } else {
                            Spacer().frame(height: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.xxs)
        .background(Color.loBackgroundFallback)
    }
}
