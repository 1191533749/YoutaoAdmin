import SwiftUI

struct CategoryView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading && rows.isEmpty {
                    ProgressView()
                } else {
                    List {
                        if let errorMessage = errorMessage {
                            Text(errorMessage).foregroundColor(.red).font(.footnote)
                        }
                        ForEach(rows) { row in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.str("name")).font(.body)
                                    if !row.str("description").isEmpty {
                                        Text(row.str("description")).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text(Labels.categoryLabel(row.int("type")))
                                    .font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(Color.gray.opacity(0.15)))
                            }
                        }
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("软件源分类（共 \(total)）")
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "category/index?offset=0&limit=100"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows
            total = list.total
        } else {
            errorMessage = "加载失败"
        }
    }
}
