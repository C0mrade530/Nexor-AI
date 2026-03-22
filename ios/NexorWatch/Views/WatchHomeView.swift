import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject var healthMonitor: WatchHealthMonitor

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    energyRing
                    statsGrid
                    recordButton
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Nexor")
            .task {
                if !healthMonitor.isAuthorized {
                    _ = await healthMonitor.requestAuthorization()
                }
            }
        }
    }

    // MARK: - Energy Ring

    private var energyRing: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 8)

            Circle()
                .trim(from: 0, to: CGFloat(healthMonitor.energyScore) / 100.0)
                .stroke(
                    energyColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: healthMonitor.energyScore)

            VStack(spacing: 2) {
                Text("\(healthMonitor.energyScore)")
                    .font(.system(size: 32, weight: .ultraLight, design: .rounded))
                    .foregroundColor(energyColor)
                Text("energy")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 100, height: 100)
        .padding(.top, 4)
    }

    private var energyColor: Color {
        let score = healthMonitor.energyScore
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 8) {
            statCard(icon: "figure.walk", value: "\(healthMonitor.steps)", label: "steps")
            statCard(icon: "flame", value: "\(healthMonitor.activeCalories)", label: "kcal")
            statCard(icon: "bed.double", value: String(format: "%.1f", healthMonitor.sleepHours), label: "sleep h")
            statCard(icon: "heart", value: healthMonitor.heartRate > 0 ? "\(healthMonitor.heartRate)" : "--", label: "bpm")
        }
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.orange)
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .rounded))
            Text(label)
                .font(.system(size: 9, weight: .light))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
    }

    // MARK: - Record Button

    private var recordButton: some View {
        NavigationLink(destination: WatchRecordView()) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .light))
                Text("Record")
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.orange)
            .foregroundColor(.black)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
