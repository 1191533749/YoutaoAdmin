import SwiftUI

struct KamiView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
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
                        if let errorMessage = errorMessage {
                            Text(errorMessage).foregroundColor(.red).font(.footnote)
                        }
                        ForEach(rows) { row in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.str("kami")).font(.system(.body, design: .monospaced))
                                    Text("\(Labels.kamiLabel(row.int("kmyp"))) · 生成于 \(row.str("addtime_text"))")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if row.str("jh") == "1" || row.str("jh") == "是" {
                                    Text("已激活").font(.caption).foregroundColor(.green)
                                } else {
                                    Text("未激活").font(.caption).foregroundColor(.gray)
                                }
                            }
                        }
                        .onDelete(perform: deleteRows)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("卡密（共 \(total)）")
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
                            Button("生成") { Task { await generate() } }
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
        errorMessage = nil
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "kami/index?offset=0&limit=100&sort=addtime&order=desc"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows
            total = list.total
        } else {
            errorMessage = "加载失败"
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
            case .success(let msg):
                genMessage = msg
                genQuantity = "1"
                await load()
            case .failure(let e):
                genMessage = e.message
            }
        } else {
            genMessage = "请求失败"
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            if let data = try? await api.getRaw(path: "kami/del/ids/\(first)") {
                switch ResponseParser.result(from: data) {
                case .success: await load()
                case .failure: break
                }
            }
        }
    }
}
