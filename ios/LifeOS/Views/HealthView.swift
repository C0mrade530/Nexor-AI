import SwiftUI

/// Athlytic-style Health & Energy dashboard — recovery, battery, sleep analysis, strain, HRV.
struct HealthView: View {
    @StateObject private var healthKit = HealthKitService.shared
    @State private var dashboard: HealthDashboard?
    @State private var isLoading = true
    @State private var isSyncing = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    if isLoading {
                        loadingView
                    } else if let d = dashboard, d.available {
                        // Recovery + Battery cards
                        recoveryBatteryRow(d)

                        // Tab selector
                        tabSelector

                        // Tab content
                        switch selectedTab {
                        case 0: overviewTab(d)
                        case 1: sleepTab(d)
                        case 2: strainTab(d)
                        case 3: hrvTab(d)
                        case 4: LabResultsView()
                        default: overviewTab(d)
                        }
                    } else {
                        notConnectedCard
                    }

                    Spacer(minLength: Spacing.xxl)
                }
            }
        }
        .task { await loadData() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            Text("Energy")
                .font(.loTitle)
                .foregroundColor(Color.loPrimaryFallback)
            Spacer()
            Button {
                Task { await syncHealth() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color.loAccentFallback)
                    .rotationEffect(.degrees(isSyncing ? 360 : 0))
                    .animation(isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isSyncing)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Recovery + Battery Row

    private func recoveryBatteryRow(_ d: HealthDashboard) -> some View {
        HStack(spacing: Spacing.sm) {
            // Recovery card
            if let r = d.recovery, r.available {
                VStack(spacing: Spacing.xs) {
                    ZStack {
                        Circle()
                            .stroke(Color.loTertiaryFallback.opacity(0.15), lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: Double(r.recoveryScore) / 100.0)
                            .stroke(recoveryZoneColor(r.zone), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1), value: r.recoveryScore)
                        VStack(spacing: 0) {
                            Text("\(r.recoveryScore)")
                                .font(.system(size: 28, weight: .light, design: .monospaced))
                                .foregroundColor(Color.loPrimaryFallback)
                            Text("RECOVERY")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(1)
                                .foregroundColor(Color.loTertiaryFallback)
                        }
                    }
                    .frame(width: 90, height: 90)

                    Text(r.zoneLabel)
                        .font(.loMicro)
                        .foregroundColor(recoveryZoneColor(r.zone))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.loSurfaceFallback)
                .cornerRadius(16)
            }

            // Battery card
            if let b = d.battery, b.available {
                VStack(spacing: Spacing.xs) {
                    ZStack {
                        // Battery outline
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.loTertiaryFallback.opacity(0.3), lineWidth: 2)
                            .frame(width: 50, height: 80)

                        // Battery nub
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.loTertiaryFallback.opacity(0.3))
                            .frame(width: 20, height: 6)
                            .offset(y: -43)

                        // Battery fill
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 5)
                                .fill(batteryColor(b.batteryRemaining))
                                .frame(width: 42, height: max(4, 72 * Double(b.batteryRemaining) / 100.0))
                        }
                        .frame(width: 50, height: 76)
                        .clipped()

                        Text("\(b.batteryRemaining)%")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.loPrimaryFallback)
                    }
                    .frame(height: 90)

                    Text(b.capacity.uppercased())
                        .font(.loMicro)
                        .foregroundColor(batteryColor(b.batteryRemaining))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.loSurfaceFallback)
                .cornerRadius(16)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                tabButton("Overview", index: 0)
                tabButton("Sleep", index: 1)
                tabButton("Strain", index: 2)
                tabButton("HRV", index: 3)
                tabButton("Labs", index: 4)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.sm)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
        } label: {
            Text(title)
                .font(.loCaption)
                .foregroundColor(selectedTab == index ? Color.loPrimaryFallback : Color.loTertiaryFallback)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(selectedTab == index ? Color.loAccentFallback.opacity(0.15) : Color.clear)
                .cornerRadius(8)
        }
    }

    // MARK: - Overview Tab

    private func overviewTab(_ d: HealthDashboard) -> some View {
        VStack(spacing: 0) {
            // Today's stats
            if let snap = d.snapshot, snap.available {
                LOSectionHeader(title: "Today")
                todayStatsGrid(snap)
            }

            // Recommendation
            if let r = d.recovery, r.available {
                LOSectionHeader(title: "Coach Says")
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(r.recommendation)
                        .font(.loCaption)
                        .foregroundColor(Color.loPrimaryFallback)
                        .lineSpacing(3)
                }
                .loCardStyle()
                .padding(.horizontal, Spacing.lg)
            }

            // Goal progress
            if let g = d.goals, g.available {
                LOSectionHeader(title: "Goals")
                goalProgressCard(g)
            }

            // Weekly trends
            if let t = d.trends, t.available {
                LOSectionHeader(title: "Weekly Trends")
                weeklyTrendsCard(t)
            }
        }
    }

    // MARK: - Sleep Tab

    private func sleepTab(_ d: HealthDashboard) -> some View {
        VStack(spacing: 0) {
            if let s = d.sleep, s.available {
                // Sleep score
                LOSectionHeader(title: "Sleep Score")
                VStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .stroke(Color.loTertiaryFallback.opacity(0.15), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: Double(s.score) / 100.0)
                            .stroke(sleepScoreColor(s.score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(s.score)")
                                .font(.system(size: 24, weight: .light, design: .monospaced))
                                .foregroundColor(Color.loPrimaryFallback)
                            Text("\(String(format: "%.1f", s.totalHours))h")
                                .font(.loMicro)
                                .foregroundColor(Color.loTertiaryFallback)
                        }
                    }
                    .frame(width: 80, height: 80)

                    if let bed = s.bedTime, let wake = s.wakeTime {
                        Text("\(bed) → \(wake)")
                            .font(.loMonoSmall)
                            .foregroundColor(Color.loTertiaryFallback)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.loSurfaceFallback)
                .cornerRadius(16)
                .padding(.horizontal, Spacing.lg)

                // Sleep stages
                LOSectionHeader(title: "Sleep Stages")
                VStack(spacing: Spacing.sm) {
                    if let stages = s.stages {
                        sleepStageRow("Deep", hours: stages.deep.hours, percent: stages.deep.percent, ideal: stages.deep.idealRange, color: .indigo)
                        sleepStageRow("REM", hours: stages.rem.hours, percent: stages.rem.percent, ideal: stages.rem.idealRange, color: .cyan)
                        sleepStageRow("Light", hours: stages.light.hours, percent: stages.light.percent, ideal: stages.light.idealRange, color: .blue.opacity(0.5))
                    }
                }
                .loCardStyle()
                .padding(.horizontal, Spacing.lg)

                // Consistency + insights
                LOSectionHeader(title: "Insights")
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text("Consistency")
                            .font(.loCaption)
                            .foregroundColor(Color.loTertiaryFallback)
                        Spacer()
                        Text("\(s.consistency)%")
                            .font(.loMonoSmall)
                            .foregroundColor(s.consistency >= 70 ? .green : .orange)
                    }
                    HStack {
                        Text("7-day avg")
                            .font(.loCaption)
                            .foregroundColor(Color.loTertiaryFallback)
                        Spacer()
                        Text("\(String(format: "%.1f", s.avgSleep7d))h")
                            .font(.loMonoSmall)
                            .foregroundColor(Color.loPrimaryFallback)
                    }

                    if let insights = s.insights {
                        ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                            HStack(alignment: .top, spacing: Spacing.xs) {
                                Image(systemName: insight.type == "positive" ? "checkmark.circle" : "exclamationmark.triangle")
                                    .font(.system(size: 12))
                                    .foregroundColor(insight.type == "positive" ? .green : .orange)
                                Text(insight.text)
                                    .font(.loMicro)
                                    .foregroundColor(Color.loPrimaryFallback)
                            }
                        }
                    }
                }
                .loCardStyle()
                .padding(.horizontal, Spacing.lg)
            } else {
                noDataCard("No sleep data", "Wear your Apple Watch to bed to track sleep stages.")
            }
        }
    }

    // MARK: - Strain Tab

    private func strainTab(_ d: HealthDashboard) -> some View {
        VStack(spacing: 0) {
            if let st = d.strain, st.available {
                LOSectionHeader(title: "Today's Strain")
                VStack(spacing: Spacing.sm) {
                    // Strain gauge
                    ZStack {
                        Circle()
                            .stroke(Color.loTertiaryFallback.opacity(0.15), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: Double(st.strainScore) / 100.0)
                            .stroke(strainColor(st.strainScore), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(st.strainScore)")
                                .font(.system(size: 24, weight: .light, design: .monospaced))
                                .foregroundColor(Color.loPrimaryFallback)
                            Text("STRAIN")
                                .font(.system(size: 8, weight: .medium))
                                .tracking(1)
                                .foregroundColor(Color.loTertiaryFallback)
                        }
                    }
                    .frame(width: 80, height: 80)

                    Text(st.strainStatus.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.loMicro)
                        .foregroundColor(strainColor(st.strainScore))

                    Text(st.strainAdvice)
                        .font(.loCaption)
                        .foregroundColor(Color.loTertiaryFallback)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.loSurfaceFallback)
                .cornerRadius(16)
                .padding(.horizontal, Spacing.lg)

                // Activity breakdown
                LOSectionHeader(title: "Activity")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                    miniStat("\(st.steps)", "steps", .green)
                    miniStat("\(st.activeCalories)", "kcal", .orange)
                    miniStat("\(st.activeMinutes)", "min", .red)
                }
                .padding(.horizontal, Spacing.lg)

                // Workouts
                if !st.workouts.isEmpty {
                    LOSectionHeader(title: "Workouts")
                    VStack(spacing: Spacing.xs) {
                        ForEach(Array(st.workouts.enumerated()), id: \.offset) { _, w in
                            HStack {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(Color.loAccentFallback)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.type)
                                        .font(.loCaption)
                                        .foregroundColor(Color.loPrimaryFallback)
                                    Text("\(w.durationMinutes) min | \(w.calories) kcal")
                                        .font(.loMicro)
                                        .foregroundColor(Color.loTertiaryFallback)
                                }
                                Spacer()
                                Text("strain \(w.strain)")
                                    .font(.loMonoSmall)
                                    .foregroundColor(strainColor(w.strain * 5))
                            }
                            .padding(.vertical, Spacing.xs)
                        }
                    }
                    .loCardStyle()
                    .padding(.horizontal, Spacing.lg)
                }
            } else {
                noDataCard("No strain data", "Sync HealthKit to see your activity strain.")
            }
        }
    }

    // MARK: - HRV Tab

    private func hrvTab(_ d: HealthDashboard) -> some View {
        VStack(spacing: 0) {
            if let h = d.hrv, h.available {
                LOSectionHeader(title: "HRV Analysis")
                VStack(spacing: Spacing.sm) {
                    HStack(alignment: .bottom, spacing: Spacing.xs) {
                        Text("\(h.current)")
                            .font(.system(size: 36, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(Color.loPrimaryFallback)
                        Text("ms")
                            .font(.loCaption)
                            .foregroundColor(Color.loTertiaryFallback)
                            .padding(.bottom, 6)
                    }

                    Text(h.status.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.loMicro)
                        .foregroundColor(hrvStatusColor(h.status))

                    Text(h.interpretation)
                        .font(.loCaption)
                        .foregroundColor(Color.loTertiaryFallback)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.loSurfaceFallback)
                .cornerRadius(16)
                .padding(.horizontal, Spacing.lg)

                // HRV stats
                LOSectionHeader(title: "Stats")
                VStack(spacing: Spacing.xs) {
                    hrvStatRow("Baseline", "\(String(format: "%.0f", h.baseline)) ms")
                    hrvStatRow("30-day High", "\(h.high30d) ms")
                    hrvStatRow("30-day Low", "\(h.low30d) ms")
                    hrvStatRow("Variability (CV)", "\(String(format: "%.1f", h.cv))%")
                    if let t7 = h.trend7d {
                        hrvStatRow("7-day Trend", t7.capitalized)
                    }
                    if let t30 = h.trend30d {
                        hrvStatRow("30-day Trend", t30.capitalized)
                    }
                }
                .loCardStyle()
                .padding(.horizontal, Spacing.lg)

                // HRV history chart (simple bar visualization)
                if !h.history.isEmpty {
                    LOSectionHeader(title: "HRV History")
                    VStack(spacing: 0) {
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(Array(h.history.enumerated()), id: \.offset) { _, point in
                                let maxHRV = Double(h.high30d > 0 ? h.high30d : 100)
                                VStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(hrvBarColor(point.hrv, baseline: h.baseline))
                                        .frame(height: max(8, 60 * Double(point.hrv) / maxHRV))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 68)
                        .padding(.horizontal, Spacing.sm)

                        // Baseline line label
                        HStack {
                            Text("baseline \(String(format: "%.0f", h.baseline))")
                                .font(.system(size: 8))
                                .foregroundColor(Color.loTertiaryFallback)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, 2)
                    }
                    .loCardStyle()
                    .padding(.horizontal, Spacing.lg)
                }
            } else {
                noDataCard("No HRV data", "HRV data comes from Apple Watch. Wear it consistently for trends.")
            }
        }
    }

    // MARK: - Shared Components

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

    private func sleepStageRow(_ name: String, hours: Double, percent: Double, ideal: String, color: Color) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.loCaption)
                    .foregroundColor(Color.loPrimaryFallback)
                Text("ideal: \(ideal)")
                    .font(.system(size: 9))
                    .foregroundColor(Color.loTertiaryFallback)
            }
            Spacer()
            Text("\(String(format: "%.1f", hours))h")
                .font(.loMonoSmall)
                .foregroundColor(Color.loPrimaryFallback)
            Text("\(String(format: "%.0f", percent))%")
                .font(.loMicro)
                .foregroundColor(Color.loTertiaryFallback)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private func miniStat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .light, design: .monospaced))
                .foregroundColor(Color.loPrimaryFallback)
            Text(label)
                .font(.loMicro)
                .foregroundColor(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(Color.loSurfaceFallback)
        .cornerRadius(10)
    }

    private func hrvStatRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
            Spacer()
            Text(value)
                .font(.loMonoSmall)
                .foregroundColor(Color.loPrimaryFallback)
        }
    }

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

    private var notConnectedCard: some View {
        VStack(spacing: Spacing.md) {
            Spacer(minLength: 80)
            Image(systemName: "heart.text.square")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Color.loTertiaryFallback)
            Text("Connect Apple Watch")
                .font(.loBody)
                .foregroundColor(Color.loPrimaryFallback)
            Text("Sync sleep, steps, workouts, and heart rate to unlock your recovery, battery, and strain analytics")
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

    private func noDataCard(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Spacer(minLength: 40)
            Text(title)
                .font(.loBody)
                .foregroundColor(Color.loPrimaryFallback)
            Text(subtitle)
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var loadingView: some View {
        VStack {
            Spacer(minLength: 120)
            ProgressView()
                .tint(Color.loAccentFallback)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Colors

    private func recoveryZoneColor(_ zone: String) -> Color {
        switch zone {
        case "green": return .green
        case "yellow": return .orange
        case "red": return .red
        default: return Color.loTertiaryFallback
        }
    }

    private func batteryColor(_ pct: Int) -> Color {
        if pct >= 60 { return .green }
        if pct >= 30 { return .orange }
        return .red
    }

    private func sleepScoreColor(_ score: Int) -> Color {
        if score >= 80 { return .indigo }
        if score >= 60 { return .blue }
        if score >= 40 { return .orange }
        return .red
    }

    private func strainColor(_ strain: Int) -> Color {
        if strain >= 70 { return .red }
        if strain >= 40 { return .orange }
        return .blue
    }

    private func hrvStatusColor(_ status: String) -> Color {
        switch status {
        case "above_baseline": return .green
        case "below_baseline": return .red
        default: return Color.loTertiaryFallback
        }
    }

    private func hrvBarColor(_ value: Int, baseline: Double) -> Color {
        if Double(value) >= baseline * 1.1 { return .green }
        if Double(value) >= baseline * 0.9 { return .cyan }
        return .red.opacity(0.7)
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
            dashboard = try await APIClient.shared.getHealthDashboard()
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
