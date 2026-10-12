import SwiftUI

struct CategoryView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading && rows.isEmpty {
                    ProgressView()
                } else {
                    List {
                        ForEach(rows) { row in
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 34, height: 34)
                                    .background(RoundedRectangle(cornerRadius: 9).fill(colorForType(row)))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.str("name")).font(.body.weight(.semibold))
                                    if !row.str("description").isEmpty {
                                        Text(row.str("description")).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                StatusBadge(text: typeText(row), color: colorForType(row))
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteRows)
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("分类（共 \(total)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showAdd) {
                CategoryAddSheet { await load() }
            }
        }
    }

    private func typeText(_ row: Row) -> String {
        let s = row.str("type")
        if let n = Int(s), n >= 1, n <= 5 { return Labels.categoryLabel(n) }
        return s.isEmpty ? "未分类" : s
    }
    private func colorForType(_ row: Row) -> Color {
        let s = row.str("type")
        let n = Int(s) ?? 0
        switch n {
        case 1: return .appBlue
        case 2: return .appViolet
        case 3: return .appTeal
        case 4: return .appOrange
        case 5: return .appGreen
        default: return .appAccent
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "category/index?offset=0&limit=200"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows; total = list.total
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            if let data = try? await api.postForm(path: "category/del/ids/\(first)", fields: [:]),
               case .success = ResponseParser.result(from: data) { await load() }
        }
    }
}

private struct CategoryAddSheet: View {
    let onDone: () async -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.presentationMode) var pm
    @State private var name = ""
    @State private var type = 1
    @State private var desc = ""
    @State private var message: String?
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("新分类")) {
                    TextField("名称", text: $name)
                    Picker("类型", selection: $type) {
                        ForEach(Labels.categoryType.keys.sorted(), id: \.self) { k in
                            Text(Labels.categoryType[k] ?? "").tag(k)
                        }
                    }
                    TextField("描述（可空）", text: $desc)
                }
                if let message = message {
                    Section { Text(message).font(.caption).foregroundColor(.green) }
                }
                Section {
                    Button { Task { await save() } } label: {
                        if saving { ProgressView() } else { Text("添加").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(saving)
                }
            }
            .navigationTitle("添加分类")
            .navigationBarItems(trailing: Button("关闭") { pm.wrappedValue.dismiss() })
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        message = nil
        guard !name.isEmpty else { message = "请输入名称"; return }
        guard let api = state.api else { return }
        var fields = ["row[name]": name, "row[type]": String(type), "row[pid]": "0"]
        if !desc.isEmpty { fields["row[description]"] = desc }
        if let data = try? await api.postForm(path: "category/add", fields: fields) {
            switch ResponseParser.result(from: data) {
            case .success(let m): message = m; await onDone(); pm.wrappedValue.dismiss()
            case .failure(let e): message = e.message
            }
        } else { message = "请求失败" }
    }
}
