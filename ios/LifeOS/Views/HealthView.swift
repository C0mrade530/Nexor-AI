import SwiftUI

/// Health & Energy dashboard — Apple Watch data, goals, trends.
struct HealthView: View {
    @StateObject private var healthKit = HealthKitService.shared
    @State private var snapshot: HealthTodaySnapshot?
    @State private var trends: HealthWeeklyTrends?
    @State private var progress: HealthGoalProgress?
    @State private var isLoading = true
    @State private var isSyncing = false

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .bottom) {
                        Text("Energy")
                            .font(.loTitle)
                            .foregroundColor(Color.loPrimaryFallback)
                        Spacer()
                        Button {
                            Task { await syncHealth() }
                        } label: {
                            Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(Color.loAccentFallback)
                                .rotationEffect(.degrees(isSyncing ? 360 : 0))
                                .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.lg)

                    if isLoading {
                        VStack {
                            Spacer(minLength: 120)
                            ProgressView()
                                .tint(Color.loAccentFallback)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else if let snap = snapshot, snap.available {
                        // Energy score ring
                        if let score = snap.energyScore {
                            energyScoreCard(score)
                        }

                        // Today's stats
                        LOSectionHeader(title: "Today")
                        todayStatsGrid(snap)

                        // Goal progress
                        if let prog = progress, prog.available {
                            LOSectionHeader(title: "Goal Progress")
                            goalProgressCard(prog)
                        }

                        // Weekly trends
                        if let tr = trends, tr.available {
                            LOSectionHeader(title: "Weekly Trends")
                            weeklyTrendsCard(tr)
                        }
                    } else {
                        // Not connected
                        notConnectedCard
                    }

                    Spacer(minLength: Spacing.xxl)
                }
            }
        }
        .task { await loadData() }
    }

    // MARK: - Energy Score

    private func energyScoreCard(_ score: Int) -> some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(Color.loTertiaryFallback.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: Double(score) / 100.0)
                    .stroke(energyColor(score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .light, design: .monospaced))
                        .foregroundColor(Color.loPrimaryFallback)
                    Text("ENERGY")
                        .font(.loMicro)
                        .tracking(1)
                        .foregroundColor(Color.loTertiaryFallback)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Today Stats

    private func todayStatsGrid(_ snap: HealthTodaySnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
            if let sleep = snap.sleepHours {
                statCard("Sleep", "\(String(format: "%.1f", sleep))h", icon: "moon.zzz", color: .indigo)
            }
            if let steps = snap.steps {
                statCard("Steps", formatNumber(steps), icon: "figure.walk", color: .green)
            }
            if let mins = snap.activeMinutes {
                statCard("Active", "\(mins) min", icon: "flame", color: .orange)
            }
            if let cals = snap.activeCalories {
                statCard("Calories", "\(cals)", icon: "bolt.heart", color: .red)
            }
            if let rhr = snap.restingHr {
                statCard("Resting HR", "\(rhr) bpm", icon: "heart", color: .pink)
            }
            if let hrv = snap.hrv {
                statCard("HRV", "\(hrv) ms", icon: "waveform.path.ecg", color: .cyan)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func statCard(_ title: String, _ value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(color.opacity(0.8))
                Text(title)
                    .font(.loMicro)
                    .foregroundColor(Color.loTertiaryFallback)
            }
            Text(value)
                .font(.system(size: 20, weight: .light, design: .monospaced))
                .foregroundColor(Color.loPrimaryFallback)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.loSurfaceFallback)
        .cornerRadius(12)
    }

    // MARK: - Goal Progress

    private func goalProgressCard(_ prog: HealthGoalProgress) -> some View {
        VStack(spacing: Spacing.sm) {
            if let overall = prog.overallPercent {
                HStack {
                    Text("Overall")
                        .font(.loBody)
                        .foregroundColor(Color.loPrimaryFallback)
                    Spacer()
                    Text("\(overall)%")
                        .font(.loMonoSmall)
                        .foregroundColor(Color.loAccentFallback)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.loTertiaryFallback.opacity(0.2))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.loAccentFallback)
                            .frame(width: geo.size.width * Double(min(overall, 100)) / 100.0, height: 6)
                    }
                }
                .frame(height: 6)
            }

            if let sleep = prog.sleep, let pct = sleep.percent {
                goalRow("Sleep", pct: pct, current: "\(String(format: "%.1f", sleep.current ?? 0))h", goal: "\(String(format: "%.0f", sleep.goal ?? 0))h")
            }
            if let steps = prog.steps, let pct = steps.percent {
                goalRow("Steps", pct: pct, current: formatNumber(Int(steps.current ?? 0)), goal: formatNumber(Int(steps.goal ?? 0)))
            }
            if let active = prog.activeMinutes, let pct = active.percent {
                goalRow("Active", pct: pct, current: "\(Int(active.current ?? 0)) min", goal: "\(Int(active.goal ?? 0)) min")
            }
        }
        .loCardStyle()
        .padding(.horizontal, Spacing.lg)
    }

    private func goalRow(_ label: String, pct: Int, current: String, goal: String) -> some View {
        HStack {
            Text(label)
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
                .frame(width: 50, alignment: .leading)
            Text(current)
                .font(.loMonoSmall)
                .foregroundColor(Color.loPrimaryFallback)
            Text("/ \(goal)")
                .font(.loMicro)
                .foregroundColor(Color.loTertiaryFallback)
            Spacer()
            Text("\(pct)%")
                .font(.loMonoSmall)
                .foregroundColor(pct >= 100 ? .green : Color.loAccentFallback)
        }
    }

    // MARK: - Weekly Trends

    private func weeklyTrendsCard(_ tr: HealthWeeklyTrends) -> some View {
        VStack(spacing: Spacing.sm) {
            if let days = tr.daysTracked {
                HStack {
                    Text("\(days) days tracked")
                        .font(.loCaption)
                        .foregroundColor(Color.loTertiaryFallback)
                    Spacer()
                }
            }

            if let avgSleep = tr.avgSleepHours {
                trendRow("Avg Sleep", value: "\(String(format: "%.1f", avgSleep))h", trend: tr.sleepTrend)
            }
            if let avgSteps = tr.avgSteps {
                trendRow("Avg Steps", value: formatNumber(avgSteps), trend: tr.stepsTrend)
            }
            if let workouts = tr.workoutDays {
                trendRow("Workout Days", value: "\(workouts)/7", trend: nil)
            }
            if let hrv = tr.avgHrv {
                trendRow("Avg HRV", value: "\(hrv) ms", trend: tr.hrvTrend)
            }
        }
        .loCardStyle()
        .padding(.horizontal, Spacing.lg)
    }

    private func trendRow(_ label: String, value: String, trend: String?) -> some View {
        HStack {
            Text(label)
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
            Spacer()
            Text(value)
                .font(.loMonoSmall)
                .foregroundColor(Color.loPrimaryFallback)
            if let trend = trend {
                Image(systemName: trendIcon(trend))
                    .font(.system(size: 10))
                    .foregroundColor(trendColor(trend))
            }
        }
    }

    // MARK: - Not Connected

    private var notConnectedCard: some View {
        VStack(spacing: Spacing.md) {
            Spacer(minLength: 80)
            Image(systemName: "heart.text.square")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Color.loTertiaryFallback)
            Text("Connect Apple Watch")
                .font(.loBody)
                .foregroundColor(Color.loPrimaryFallback)
            Text("Sync sleep, steps, workouts, and heart rate to get personalized energy insights")
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            LOButton(title: "Enable HealthKit", style: .primary) {
                Task {
                    let granted = await healthKit.requestAuthorization()
                    if granted { await syncHealth() }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func energyColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return Color.loAccentFallback }
        if score >= 40 { return .orange }
        return .red
    }

    private func trendIcon(_ trend: String) -> String {
        switch trend {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "improving": return .green
        case "declining": return .red
        default: return Color.loTertiaryFallback
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        do {
            async let s = APIClient.shared.getHealthToday()
            async let t = APIClient.shared.getHealthTrends()
            async let p = APIClient.shared.getHealthProgress()
            snapshot = try await s
            trends = try await t
            progress = try await p
        } catch {}
        isLoading = false
    }

    private func syncHealth() async {
        isSyncing = true
        _ = await healthKit.syncToday()
        await loadData()
        isSyncing = false
    }
}
