import SwiftUI

/// Finance dashboard — spending summary, category breakdown, AI analysis.
struct FinanceView: View {
    @State private var summary: FinanceMonthlySummary?
    @State private var isLoading = true
    @State private var isAnalyzing = false
    @State private var analysisResult: [String: Any]?

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .bottom) {
                        Text("Finance")
                            .font(.loTitle)
                            .foregroundColor(Color.loPrimaryFallback)
                        Spacer()
                        Text(currentMonth)
                            .font(.loCaption)
                            .foregroundColor(Color.loTertiaryFallback)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.lg)

                    if isLoading {
                        VStack {
                            Spacer(minLength: 120)
                            ProgressView().tint(Color.loAccentFallback)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else if let summary = summary {
                        // Balance overview
                        balanceCard(summary)

                        // Category breakdown
                        if let categories = summary.byCategory, !categories.isEmpty {
                            LOSectionHeader(title: "Spending by Category")
                            categoryList(categories, total: summary.expenses ?? 0)
                        }

                        // AI Analysis button
                        LOSectionHeader(title: "AI Analysis")
                        aiAnalysisSection

                    } else {
                        emptyState
                    }

                    Spacer(minLength: Spacing.xxl)
                }
            }
        }
        .task { await loadData() }
    }

    // MARK: - Balance Card

    private func balanceCard(_ summary: FinanceMonthlySummary) -> some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("INCOME")
                        .font(.loMicro)
                        .tracking(1)
                        .foregroundColor(Color.loTertiaryFallback)
                    Text(formatMoney(summary.income ?? 0))
                        .font(.system(size: 20, weight: .light, design: .monospaced))
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("EXPENSES")
                        .font(.loMicro)
                        .tracking(1)
                        .foregroundColor(Color.loTertiaryFallback)
                    Text(formatMoney(summary.expenses ?? 0))
                        .font(.system(size: 20, weight: .light, design: .monospaced))
                        .foregroundColor(.red)
                }
            }

            LODivider()

            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("NET")
                        .font(.loMicro)
                        .tracking(1)
                        .foregroundColor(Color.loTertiaryFallback)
                    let net = summary.net ?? 0
                    Text(formatMoney(net))
                        .font(.system(size: 24, weight: .light, design: .monospaced))
                        .foregroundColor(net >= 0 ? .green : .red)
                }
                Spacer()
                if let rate = summary.savingsRate {
                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text("SAVINGS RATE")
                            .font(.loMicro)
                            .tracking(1)
                            .foregroundColor(Color.loTertiaryFallback)
                        Text("\(String(format: "%.0f", rate))%")
                            .font(.system(size: 24, weight: .light, design: .monospaced))
                            .foregroundColor(rate >= 20 ? .green : Color.loAccentFallback)
                    }
                }
            }
        }
        .loCardStyle()
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Categories

    private func categoryList(_ categories: [CategorySpend], total: Double) -> some View {
        VStack(spacing: 0) {
            ForEach(categories.prefix(8)) { cat in
                HStack {
                    Image(systemName: categoryIcon(cat.category))
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color.loAccentFallback)
                        .frame(width: 24)
                    Text(cat.category.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.loCaption)
                        .foregroundColor(Color.loPrimaryFallback)
                    Spacer()
                    Text(formatMoney(cat.amount))
                        .font(.loMonoSmall)
                        .foregroundColor(Color.loPrimaryFallback)
                    if total > 0 {
                        Text("\(Int(cat.amount / total * 100))%")
                            .font(.loMicro)
                            .foregroundColor(Color.loTertiaryFallback)
                            .frame(width: 35, alignment: .trailing)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)

                if cat.id != categories.prefix(8).last?.id {
                    LODivider().padding(.leading, Spacing.xl + Spacing.sm)
                }
            }
        }
        .loCardStyle()
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - AI Analysis

    private var aiAnalysisSection: some View {
        VStack(spacing: Spacing.sm) {
            LOButton(title: isAnalyzing ? "Analyzing..." : "Run AI Spending Analysis", style: .primary) {
                Task { await analyzeSpending() }
            }
            .disabled(isAnalyzing)
            .padding(.horizontal, Spacing.lg)

            if isAnalyzing {
                HStack {
                    ProgressView().tint(Color.loAccentFallback)
                    Text("Claude analyzes your transactions...")
                        .font(.loCaption)
                        .foregroundColor(Color.loTertiaryFallback)
                }
            }

            if let result = analysisResult {
                if let score = result["financial_health_score"] as? Int {
                    HStack {
                        Text("Financial Health Score:")
                            .font(.loCaption)
                            .foregroundColor(Color.loTertiaryFallback)
                        Text("\(score)/100")
                            .font(.loMonoSmall)
                            .foregroundColor(score >= 70 ? .green : Color.loAccentFallback)
                    }
                    .padding(.horizontal, Spacing.lg)
                }

                if let oneThing = result["one_thing"] as? String {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("TOP PRIORITY")
                            .font(.loMicro)
                            .tracking(1)
                            .foregroundColor(Color.loTertiaryFallback)
                        Text(oneThing)
                            .font(.loCaption)
                            .foregroundColor(Color.loPrimaryFallback)
                    }
                    .loCardStyle()
                    .padding(.horizontal, Spacing.lg)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer(minLength: 80)
            Image(systemName: "banknote")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Color.loTertiaryFallback)
            Text("No transactions yet")
                .font(.loBody)
                .foregroundColor(Color.loPrimaryFallback)
            Text("Add transactions manually or import a bank statement to get AI-powered spending insights")
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var currentMonth: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }

    private func formatMoney(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))") + " ₽"
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "food_delivery", "restaurants": return "fork.knife"
        case "groceries": return "cart"
        case "transport", "taxi": return "car"
        case "subscriptions": return "repeat"
        case "entertainment": return "film"
        case "shopping": return "bag"
        case "health", "pharmacy": return "heart"
        case "utilities": return "bolt"
        case "education": return "book"
        case "travel": return "airplane"
        default: return "creditcard"
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        do {
            summary = try await APIClient.shared.getFinanceSummary()
        } catch {}
        isLoading = false
    }

    private func analyzeSpending() async {
        isAnalyzing = true
        do {
            analysisResult = try await APIClient.shared.analyzeSpending()
        } catch {}
        isAnalyzing = false
    }
}
