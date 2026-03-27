import SwiftUI

/// Lab results — upload blood tests, view biomarkers, track trends, AI analysis.
struct LabResultsView: View {
    @State private var results: [LabResult] = []
    @State private var isLoading = true
    @State private var showAddSheet = false
    @State private var selectedResult: LabResult?

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Lab Results")
                            .font(.loTitle)
                            .foregroundColor(Color.loPrimaryFallback)
                        Spacer()
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(Color.loAccentFallback)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.lg)

                    if isLoading {
                        VStack {
                            Spacer(minLength: 80)
                            ProgressView().tint(Color.loAccentFallback)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else if results.isEmpty {
                        emptyState
                    } else {
                        resultsList
                    }

                    Spacer(minLength: Spacing.xxl)
                }
            }
        }
        .task { await loadResults() }
        .sheet(isPresented: $showAddSheet) {
            AddLabResultSheet(isPresented: $showAddSheet, onAdded: {
                Task { await loadResults() }
            })
        }
        .sheet(item: $selectedResult) { result in
            LabResultDetailView(result: result)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer(minLength: 60)
            Image(systemName: "cross.case")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Color.loTertiaryFallback)
            Text("No lab results yet")
                .font(.loBody)
                .foregroundColor(Color.loPrimaryFallback)
            Text("Upload blood test results to track biomarkers over time and get AI-powered health insights")
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            LOButton(title: "Add Results", style: .primary) {
                showAddSheet = true
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results List

    private var resultsList: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(results) { result in
                Button {
                    selectedResult = result
                } label: {
                    resultCard(result)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    private func resultCard(_ result: LabResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.labName?.isEmpty == false ? result.labName! : "Blood Test")
                        .font(.loBody)
                        .foregroundColor(Color.loPrimaryFallback)
                    Text(result.date)
                        .font(.loMicro)
                        .foregroundColor(Color.loTertiaryFallback)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(Color.loTertiaryFallback)
            }

            // Biomarker summary
            HStack(spacing: Spacing.md) {
                biomarkerBadge("\(result.biomarkersCount)", "total", .blue)
                if result.optimal > 0 {
                    biomarkerBadge("\(result.optimal)", "optimal", .green)
                }
                if result.borderline > 0 {
                    biomarkerBadge("\(result.borderline)", "borderline", .orange)
                }
                if result.outOfRange > 0 {
                    biomarkerBadge("\(result.outOfRange)", "out of range", .red)
                }
                Spacer()
            }

            // Top biomarkers preview
            if !result.topBiomarkers.isEmpty {
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(result.topBiomarkers.prefix(4))) { bm in
                        VStack(spacing: 2) {
                            Text(String(bm.name.prefix(6)))
                                .font(.system(size: 9))
                                .foregroundColor(Color.loTertiaryFallback)
                            Text(bm.displayValue)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(statusColor(bm.status))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.loSurfaceFallback)
        .cornerRadius(12)
    }

    private func biomarkerBadge(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(Color.loTertiaryFallback)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "optimal": return .green
        case "normal": return Color.loPrimaryFallback
        case "borderline": return .orange
        case "out_of_range": return .red
        default: return Color.loTertiaryFallback
        }
    }

    private func loadResults() async {
        isLoading = true
        do {
            let response = try await APIClient.shared.getLabResults()
            results = response.results
        } catch {}
        isLoading = false
    }
}

// MARK: - Add Lab Result Sheet

struct AddLabResultSheet: View {
    @Binding var isPresented: Bool
    var onAdded: () -> Void

    @State private var mode = 0  // 0 = paste text, 1 = manual entry
    @State private var pastedText = ""
    @State private var date = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    // Manual entry
    @State private var manualNames: [String] = [""]
    @State private var manualValues: [String] = [""]

    var body: some View {
        NavigationView {
            ZStack {
                Color.loBackgroundFallback.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text("Add Lab Results")
                            .font(.loTitle)
                            .foregroundColor(Color.loPrimaryFallback)

                        // Mode selector
                        Picker("", selection: $mode) {
                            Text("Paste Text").tag(0)
                            Text("Manual").tag(1)
                        }
                        .pickerStyle(.segmented)

                        if mode == 0 {
                            pasteTextMode
                        } else {
                            manualEntryMode
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.loCaption)
                                .foregroundColor(.red)
                        }

                        LOButton(title: isSubmitting ? "Uploading..." : "Upload Results", style: .primary) {
                            Task { await submit() }
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundColor(Color.loTertiaryFallback)
                }
            }
        }
    }

    private var pasteTextMode: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Paste your lab report text below. AI will extract all biomarkers automatically.")
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)
                .lineSpacing(2)

            Text("Supports Russian and English lab formats")
                .font(.loMicro)
                .foregroundColor(Color.loAccentFallback)

            TextEditor(text: $pastedText)
                .font(.loMonoSmall)
                .foregroundColor(Color.loPrimaryFallback)
                .frame(minHeight: 200)
                .padding(Spacing.sm)
                .background(Color.loSurfaceFallback)
                .cornerRadius(8)
                .scrollContentBackground(.hidden)
        }
    }

    private var manualEntryMode: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Enter biomarker values manually")
                .font(.loCaption)
                .foregroundColor(Color.loTertiaryFallback)

            ForEach(manualNames.indices, id: \.self) { index in
                HStack(spacing: Spacing.sm) {
                    TextField("Biomarker", text: $manualNames[index])
                        .font(.loCaption)
                        .foregroundColor(Color.loPrimaryFallback)
                        .padding(Spacing.xs)
                        .background(Color.loSurfaceFallback)
                        .cornerRadius(6)

                    TextField("Value", text: $manualValues[index])
                        .font(.loMonoSmall)
                        .keyboardType(.decimalPad)
                        .foregroundColor(Color.loPrimaryFallback)
                        .frame(width: 80)
                        .padding(Spacing.xs)
                        .background(Color.loSurfaceFallback)
                        .cornerRadius(6)

                    if manualNames.count > 1 {
                        Button {
                            manualNames.remove(at: index)
                            manualValues.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.red.opacity(0.6))
                        }
                    }
                }
            }

            Button {
                manualNames.append("")
                manualValues.append("")
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14, weight: .light))
                    Text("Add biomarker")
                        .font(.loCaption)
                }
                .foregroundColor(Color.loAccentFallback)
            }

            // Common biomarker chips
            Text("COMMON")
                .font(.loMicro)
                .tracking(1)
                .foregroundColor(Color.loTertiaryFallback)
                .padding(.top, Spacing.sm)

            FlowLayout(spacing: 6) {
                ForEach(["Hemoglobin", "Glucose", "Vitamin D", "Ferritin", "TSH", "Total Cholesterol", "LDL", "HDL", "ALT", "Creatinine", "Vitamin B12", "Iron"], id: \.self) { name in
                    Button {
                        if !manualNames.contains(name) {
                            if manualNames.last?.isEmpty == true {
                                manualNames[manualNames.count - 1] = name
                            } else {
                                manualNames.append(name)
                                manualValues.append("")
                            }
                        }
                    } label: {
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundColor(Color.loAccentFallback)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.loAccentFallback.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil

        do {
            if mode == 0 {
                guard !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    errorMessage = "Please paste your lab results text"
                    isSubmitting = false
                    return
                }
                _ = try await APIClient.shared.parseLabText(text: pastedText, date: date.isEmpty ? nil : date)
            } else {
                var biomarkers: [String: Double] = [:]
                for i in manualNames.indices {
                    let name = manualNames[i]
                    let value = manualValues[i]
                    if !name.isEmpty, let v = Double(value) {
                        biomarkers[name] = v
                    }
                }
                guard !biomarkers.isEmpty else {
                    errorMessage = "Please enter at least one biomarker with a value"
                    isSubmitting = false
                    return
                }
                _ = try await APIClient.shared.addLabResults(biomarkers: biomarkers)
            }
            onAdded()
            isPresented = false
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
        isSubmitting = false
    }
}

// MARK: - Lab Result Detail View

struct LabResultDetailView: View {
    let result: LabResult
    @State private var isAnalyzing = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.loBackgroundFallback.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(result.labName?.isEmpty == false ? result.labName! : "Blood Test")
                                .font(.loTitle)
                                .foregroundColor(Color.loPrimaryFallback)
                            Text(result.date)
                                .font(.loCaption)
                                .foregroundColor(Color.loTertiaryFallback)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.lg)

                        // Summary badges
                        HStack(spacing: Spacing.md) {
                            summaryBadge("\(result.biomarkersCount)", "Biomarkers", .blue)
                            summaryBadge("\(result.optimal)", "Optimal", .green)
                            summaryBadge("\(result.borderline)", "Borderline", .orange)
                            summaryBadge("\(result.outOfRange)", "Out of Range", .red)
                        }
                        .padding(.horizontal, Spacing.lg)

                        // Biomarker list
                        LOSectionHeader(title: "Biomarkers")

                        VStack(spacing: 1) {
                            ForEach(result.topBiomarkers) { bm in
                                biomarkerRow(bm)
                            }
                        }
                        .background(Color.loSurfaceFallback)
                        .cornerRadius(12)
                        .padding(.horizontal, Spacing.lg)

                        // AI Analyze button
                        LOSectionHeader(title: "AI Analysis")

                        LOButton(title: isAnalyzing ? "Analyzing..." : "Analyze with AI", style: .primary) {
                            // TODO: trigger AI analysis
                        }
                        .padding(.horizontal, Spacing.lg)
                        .disabled(isAnalyzing)

                        Spacer(minLength: Spacing.xxl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func summaryBadge(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .light, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Color.loTertiaryFallback)
        }
        .frame(maxWidth: .infinity)
    }

    private func biomarkerRow(_ bm: BiomarkerPreview) -> some View {
        HStack {
            Circle()
                .fill(statusColor(bm.status))
                .frame(width: 6, height: 6)

            Text(bm.name)
                .font(.loCaption)
                .foregroundColor(Color.loPrimaryFallback)

            Spacer()

            Text(bm.displayValue)
                .font(.loMonoSmall)
                .foregroundColor(statusColor(bm.status))

            if !bm.unit.isEmpty {
                Text(bm.unit)
                    .font(.system(size: 9))
                    .foregroundColor(Color.loTertiaryFallback)
                    .frame(width: 40, alignment: .leading)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "optimal": return .green
        case "normal": return Color.loPrimaryFallback
        case "borderline": return .orange
        case "out_of_range": return .red
        default: return Color.loTertiaryFallback
        }
    }
}

// MARK: - Flow Layout helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
