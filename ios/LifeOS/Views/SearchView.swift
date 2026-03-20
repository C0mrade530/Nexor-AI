import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @FocusState private var isSearchFocused: Bool

    let examples = [
        "What did we agree with Misha?",
        "My business ideas this month",
        "Unfinished follow-ups",
        "Where I lose focus in meetings",
    ]

    var body: some View {
        ZStack {
            Color.loBackgroundFallback.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                Text("Search")
                    .font(.loTitle)
                    .foregroundColor(Color.loPrimaryFallback)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.sm)

                // Search field
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(Color.loTertiaryFallback)

                    TextField("Ask your memory...", text: $vm.query)
                        .font(.loBody)
                        .foregroundColor(Color.loPrimaryFallback)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await vm.search() }
                        }

                    if !vm.query.isEmpty {
                        Button {
                            vm.query = ""
                            vm.answer = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .light))
                                .foregroundColor(Color.loTertiaryFallback)
                                .frame(width: 20, height: 20)
                                .background(Color.loSurfaceFallback)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.loSurfaceFallback)
                .cornerRadius(10)
                .padding(.horizontal, Spacing.lg)

                LODivider()
                    .padding(.top, Spacing.md)

                // Content
                if vm.isSearching {
                    Spacer()
                    VStack(spacing: Spacing.sm) {
                        // Minimal loading dots
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(Color.loTertiaryFallback)
                                    .frame(width: 4, height: 4)
                                    .opacity(loadingOpacity(index: i))
                            }
                        }
                        Text("Searching...")
                            .font(.loMicro)
                            .foregroundColor(Color.loTertiaryFallback)
                    }
                    Spacer()
                } else if !vm.answer.isEmpty {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "sparkle")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(Color.loAccentFallback)
                                Text("ANSWER")
                                    .font(.loMicro)
                                    .tracking(1.2)
                                    .foregroundColor(Color.loTertiaryFallback)
                            }
                            .padding(.top, Spacing.md)

                            Text(vm.answer)
                                .font(.loBody)
                                .foregroundColor(Color.loPrimaryFallback)
                                .lineSpacing(5)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, Spacing.lg)
                    }
                } else {
                    // Examples
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("TRY ASKING")
                            .font(.loMicro)
                            .tracking(1.2)
                            .foregroundColor(Color.loTertiaryFallback)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.lg)

                        ForEach(examples, id: \.self) { example in
                            Button {
                                vm.query = example
                                Task { await vm.search() }
                            } label: {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 11, weight: .light))
                                        .foregroundColor(Color.loTertiaryFallback)
                                    Text(example)
                                        .font(.loCaption)
                                        .foregroundColor(Color.loSecondaryFallback)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.xs)
                            }
                        }
                    }

                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }

    private func loadingOpacity(index: Int) -> Double {
        // Simple staggered opacity for loading animation
        return 0.3 + Double(index) * 0.3
    }
}
