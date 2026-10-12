import SwiftUI

struct KamiView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var showGenerate = false
    @State private var genQuantity = "1"
    @State private var genPrefix = ""
    @State private var genType = 1
    @State private var genMessage: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading && rows.isEmpty {
                    ProgressView()
                } else {
                    List {
                        ForEach(rows) { row in
                            KamiRow(row: row)
                        }
                        .onDelete(perform: deleteRows)
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("卡密（共 \(total)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showGenerate = true } label: { Image(systemName: "plus") }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showGenerate) {
                NavigationView {
                    Form {
                        Section(header: Text("生成卡密")) {
                            TextField("数量", text: $genQuantity).keyboardType(.numberPad)
                            TextField("前缀（可空）", text: $genPrefix)
                                .autocapitalization(.none).disableAutocorrection(true)
                            Picker("类型", selection: $genType) {
                                ForEach(Labels.kamiType.keys.sorted(), id: \.self) { k in
                                    Text(Labels.kamiType[k] ?? "").tag(k)
                                }
                            }
                        }
                        if let genMessage = genMessage {
                            Section { Text(genMessage).font(.caption).foregroundColor(.green) }
                        }
                        Section {
                            Button("生成") { Task { await generate() } }.buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    .navigationTitle("生成卡密")
                    .navigationBarItems(trailing: Button("关闭") { showGenerate = false })
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "kami/index?offset=0&limit=200&sort=addtime&order=desc"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows; total = list.total
        }
    }

    private func generate() async {
        genMessage = nil
        let qty = Int(genQuantity) ?? 0
        guard qty > 0 else { genMessage = "数量必须大于 0"; return }
        guard let api = state.api else { return }
        let fields = ["row[kami]": String(qty), "row[udid]": genPrefix, "row[Kmyp]": String(genType)]
        if let data = try? await api.postForm(path: "kami/add", fields: fields) {
            switch ResponseParser.result(from: data) {
            case .success(let msg): genMessage = msg; genQuantity = "1"; await load()
            case .failure(let e): genMessage = e.message
            }
        } else { genMessage = "请求失败" }
    }

    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            if let data = try? await api.postForm(path: "kami/del/ids/\(first)", fields: [:]),
               case .success = ResponseParser.result(from: data) { await load() }
        }
    }
}

private struct KamiRow: View {
    let row: Row
    private var typeColor: Color {
        switch row.int("kmyp") {
        case 1: return .appBlue
        case 2: return .appViolet
        case 3: return .appTeal
        case 4: return .appOrange
        case 5: return .appGreen
        default: return .gray
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.str("kami")).font(.system(.body, design: .monospaced))
            HStack(spacing: 6) {
                StatusBadge(text: Labels.kamiLabel(row.int("kmyp")), color: typeColor)
                let active = !row.str("jh_text").isEmpty ? row.str("jh_text") : row.str("jh")
                if active == "1" || active == "是" || active.contains("激活") {
                    StatusBadge(text: "已激活", color: .appGreen)
                } else {
                    StatusBadge(text: "未激活", color: .gray)
                }
                if !row.str("usetime_text").isEmpty {
                    Text("激活于 \(row.str("usetime_text"))").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
