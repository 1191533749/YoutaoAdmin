import SwiftUI

struct KamiView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var showGenerate = false
    @State private var editingRow: Row?
    @State private var banner: Feedback?
    @State private var genQuantity = "1"
    @State private var genPrefix = ""
    @State private var genType = 1
    @State private var genFeedback: Feedback?
    @State private var generating = false

    private var siteRoot: String { state.config?.siteRoot ?? "" }

    var body: some View {
        NavigationView {
            Group {
                if isLoading && rows.isEmpty {
                    ProgressView()
                } else {
                    List {
                        ForEach(rows) { row in
                            KamiRow(row: row)
                                .contentShape(Rectangle())
                                .onTapGesture { editingRow = row }
                        }
                        .onDelete(perform: deleteRows)
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await load() }
                }
            }
            .overlay(alignment: .top) { ToastBanner(feedback: banner) }
            .navigationTitle("卡密（共 \(total)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showGenerate = true } label: { Image(systemName: "plus") }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showGenerate) {
                generateSheet
            }
            .sheet(item: $editingRow) { row in
                SpecFormView(title: "编辑卡密", path: "kami", editingId: row.id,
                             fields: Self.editFields, initial: row.stringDict) {
                    await load()
                }
                .environmentObject(state)
            }
        }
    }

    // 对齐 Web 后端 application/admin/view/kami/edit.html
    static let editFields: [FormField] = [
        FormField("kami", "卡密", required: true, section: "卡密信息"),
        FormField("udid", "设备码 UDID", placeholder: "未绑定时为空", section: "卡密信息"),
        FormField("kmyp", "卡密类型", kind: .options([
            FieldOption("4", "日卡"), FieldOption("5", "周卡"), FieldOption("1", "月卡"),
            FieldOption("2", "季卡"), FieldOption("3", "年卡")
        ]), section: "卡密信息"),
        FormField("jh", "激活状态", kind: .options([
            FieldOption("0", "未激活"), FieldOption("1", "已激活")
        ]), section: "卡密信息"),
        FormField("addtime", "生成时间（时间戳）", kind: .number, section: "时间"),
        FormField("usetime", "使用时间（时间戳）", kind: .number, section: "时间"),
        FormField("endtime", "到期时间（时间戳）", kind: .number, section: "时间")
    ]

    private var generateSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("生成卡密")) {
                    HStack {
                        Text("数量")
                        Spacer()
                        TextField("1", text: $genQuantity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                    TextField("前缀（可空，如 YT）", text: $genPrefix)
                        .autocapitalization(.allCharacters).disableAutocorrection(true)
                    Picker("类型", selection: $genType) {
                        ForEach(Labels.kamiType.keys.sorted(), id: \.self) { k in
                            Text(Labels.kamiType[k] ?? "").tag(k)
                        }
                    }
                }
                FeedbackSection(feedback: genFeedback)
                Section {
                    Button {
                        Task { await generate() }
                    } label: {
                        if generating {
                            Text("生成中…").frame(maxWidth: .infinity)
                        } else {
                            Text("生成").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(generating)
                }
            }
            .navigationTitle("生成卡密")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("关闭") { showGenerate = false })
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

    private func showBanner(_ fb: Feedback) {
        banner = fb
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if banner == fb { banner = nil }
        }
    }

    private func generate() async {
        generating = true
        defer { generating = false }
        genFeedback = nil
        let qty = Int(genQuantity) ?? 0
        guard qty > 0 else { genFeedback = Feedback.failure("数量必须大于 0"); return }
        guard qty <= 5000 else { genFeedback = Feedback.failure("单次生成数量不能超过 5000"); return }
        guard let api = state.api else { genFeedback = Feedback.failure("未连接服务器"); return }
        let fields = ["row[kami]": String(qty), "row[udid]": genPrefix, "row[Kmyp]": String(genType)]
        do {
            let data = try await api.postForm(path: "kami/add", fields: fields)
            switch ResponseParser.result(from: data) {
            case .success(let msg):
                await load()
                showGenerate = false
                showBanner(Feedback.success("\(msg)：已生成 \(qty) 张\(Labels.kamiLabel(genType))"))
                genQuantity = "1"
            case .failure(let e):
                genFeedback = Feedback.failure(e.message)
            }
        } catch {
            genFeedback = Feedback.failure("请求失败：\(error.localizedDescription)")
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            if let data = try? await api.postForm(path: "kami/del/ids/\(first)", fields: [:]),
               case .success = ResponseParser.result(from: data) {
                await load()
            }
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
                if !row.str("udid").isEmpty {
                    Text(row.str("udid")).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
            }
            if !row.str("usetime_text").isEmpty {
                Text("激活于 \(row.str("usetime_text"))").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
