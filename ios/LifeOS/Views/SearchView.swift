import SwiftUI

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()

    let examples = [
        "What did I discuss with the team last week?",
        "My business ideas from this month",
        "When did I promise to send the proposal?",
        "Recurring problems in my meetings",
        "Unfinished follow-ups",
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Ask your memory...", text: $vm.query)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await vm.search() }
                        }

                    if !vm.query.isEmpty {
                        Button {
                            vm.query = ""
                            vm.answer = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        Task { await vm.search() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(vm.query.isEmpty ? .gray : .blue)
                    }
                    .disabled(vm.query.isEmpty || vm.isSearching)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()

                if vm.isSearching {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Searching your memory...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if !vm.answer.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Answer", systemImage: "sparkles")
                                .font(.headline)

                            Text(vm.answer)
                                .font(.body)
                                .textSelection(.enabled)
                        }
                        .padding()
                    }
                } else {
                    // Examples
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Try asking:")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        ForEach(examples, id: \.self) { example in
                            Button {
                                vm.query = example
                                Task { await vm.search() }
                            } label: {
                                HStack {
                                    Image(systemName: "text.bubble")
                                        .foregroundColor(.blue)
                                    Text(example)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)

                    Spacer()
                }
            }
            .navigationTitle("Memory Search")
        }
    }
}
