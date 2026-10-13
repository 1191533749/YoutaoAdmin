import SwiftUI

/// 应用管理（Web 后端「项目管理 / category」控制器）
/// 字段完整对齐 application/admin/view/category/add.html 与 edit.html
struct CategoryView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var editingRow: Row?
    @State private var banner: Feedback?
    @State private var keyword = ""

    private var siteRoot: String { state.config?.siteRoot ?? "" }

    private var filtered: [Row] {
        let k = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if k.isEmpty { return rows }
        return rows.filter {
            $0.str("name").lowercased().contains(k)
                || $0.str("nickname").lowercased().contains(k)
                || $0.str("beizhu").lowercased().contains(k)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if isLoading && rows.isEmpty {
                    ProgressView()
                } else {
                    List {
                        ForEach(filtered) { row in
                            CategoryRow(row: row, siteRoot: siteRoot)
                                .contentShape(Rectangle())
                                .onTapGesture { editingRow = row }
                        }
                        .onDelete(perform: deleteRows)
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await load() }
                    .searchable(text: $keyword, prompt: "搜索商品名称 / 版本号")
                }
            }
            .overlay(alignment: .top) { ToastBanner(feedback: banner) }
            .navigationTitle("商品管理（共 \(total)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showAdd) {
                SpecFormView(title: "添加商品", path: "category",
                             fields: Self.fields,
                             initial: Self.addDefaults) { await load() }
                    .environmentObject(state)
            }
            .sheet(item: $editingRow) { row in
                SpecFormView(title: "编辑商品", path: "category", editingId: row.id,
                             fields: Self.fields,
                             initial: Self.initial(from: row)) { await load() }
                    .environmentObject(state)
            }
        }
    }

    // MARK: - 字段定义（对齐 category/add.html）

    static let typeOptions = [
        FieldOption("1", "应用"), FieldOption("2", "游戏"), FieldOption("3", "影音"),
        FieldOption("4", "工具"), FieldOption("5", "插件")
    ]

    static var fields: [FormField] {
        [
            FormField("type", "类型", kind: .options(typeOptions), required: true, value: "1", section: "基本信息"),
            FormField("name", "应用名称", required: true, section: "基本信息"),
            FormField("nickname", "版本号", placeholder: "如 1.0.0", required: true, section: "基本信息"),
            FormField("image", "图标地址", placeholder: "上传后可填 /uploads/... 或完整 URL", section: "基本信息"),
            FormField("keywords", "软件说明", kind: .textarea, section: "基本信息",
                      footer: "支持换行，后端会转成字面量 \\n 存储"),
            FormField("weigh", "权重", kind: .number, value: "0", section: "基本信息"),
            FormField("bt1a", "安装包地址", placeholder: "ipa / plist 下载地址", section: "下载与付费"),
            FormField("flag", "是否蓝奏云链接", kind: .options([
                FieldOption("0", "非蓝奏云"), FieldOption("1", "蓝奏云")
            ]), value: "0", section: "下载与付费"),
            FormField("bt1b", "按钮颜色", kind: .color, value: "018084", section: "下载与付费",
                      footer: "十六进制，不带 #，例如 018084"),
            FormField("bt2a", "文件大小（MB）", kind: .decimal, placeholder: "0", value: "0", section: "下载与付费"),
            FormField("bt2b", "是否付费", kind: .options([
                FieldOption("0", "免费"), FieldOption("1", "付费")
            ]), value: "0", section: "下载与付费"),
            FormField("beizhu", "备注", section: "其他"),
            FormField("pid", "父级 ID", kind: .number, value: "0", section: "其他",
                      footer: "0 = 顶级分类，与 Web 后端保持一致"),
            FormField("status", "状态", kind: .options([
                FieldOption("normal", "正常"), FieldOption("hidden", "隐藏")
            ]), value: "normal", section: "其他")
        ]
    }

    static var addDefaults: [String: String] {
        ["type": "1", "weigh": "0", "flag": "0", "bt1b": "018084", "bt2a": "0",
         "bt2b": "0", "pid": "0", "status": "normal"]
    }

    /// 列表接口把 type 转成了中文，编辑回填时必须映射回数字；
    /// bt2a 后端存的是字节，表单按 MB 显示。
    static func initial(from row: Row) -> [String: String] {
        var d = row.stringDict
        let typeText = row.str("type")
        switch typeText {
        case "应用": d["type"] = "1"
        case "游戏": d["type"] = "2"
        case "影音": d["type"] = "3"
        case "工具": d["type"] = "4"
        case "插件": d["type"] = "5"
        default: break
        }
        let bytes = row.int("bt2a")
        d["bt2a"] = bytes > 0 ? String(format: "%.2f", Double(bytes) / 1024.0 / 1024.0) : "0"
        if d["flag"] == nil || d["flag"]!.isEmpty { d["flag"] = "0" }
        if d["bt2b"] == nil || d["bt2b"]!.isEmpty { d["bt2b"] = "0" }
        if d["bt1b"] == nil { d["bt1b"] = "018084" }
        if d["status"] == nil || d["status"]!.isEmpty { d["status"] = "normal" }
        if d["pid"] == nil { d["pid"] = "0" }
        if d["weigh"] == nil { d["weigh"] = "0" }
        if !d.keys.contains("keywords") { d["keywords"] = "" }
        if let kw = d["keywords"] { d["keywords"] = kw.replacingOccurrences(of: "\\n", with: "\n") }
        return d
    }

    // MARK: - 数据

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
        let ids = offsets.map { filtered[$0].id }
        guard let first = ids.first, let api = state.api else { return }
        Task {
            if let data = try? await api.postForm(path: "category/del/ids/\(first)", fields: [:]),
               case .success = ResponseParser.result(from: data) { await load() }
        }
    }
}

private struct CategoryRow: View {
    let row: Row
    let siteRoot: String

    private var typeColor: Color {
        switch row.str("type") {
        case "应用": return .appBlue
        case "游戏": return .appViolet
        case "影音": return .appTeal
        case "工具": return .appOrange
        case "插件": return .appGreen
        default: return .appAccent
        }
    }

    private var sizeText: String {
        let bytes = row.int("bt2a")
        guard bytes > 0 else { return "" }
        return String(format: "%.2f MB", Double(bytes) / 1024.0 / 1024.0)
    }

    var body: some View {
        HStack(spacing: 12) {
            RemoteIcon(path: row.str("image"), siteRoot: siteRoot, size: 40, tint: typeColor)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.str("name").isEmpty ? "未命名" : row.str("name"))
                        .font(.body.weight(.semibold)).lineLimit(1)
                    if !row.str("nickname").isEmpty {
                        Text("v\(row.str("nickname"))").font(.caption2).foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    StatusBadge(text: typeText, color: typeColor)
                    StatusBadge(text: row.str("bt2b") == "1" ? "付费" : "免费",
                                color: row.str("bt2b") == "1" ? .appRed : .appGreen)
                    if !sizeText.isEmpty {
                        Text(sizeText).font(.caption2).foregroundColor(.secondary)
                    }
                    if row.str("flag") == "1" {
                        StatusBadge(text: "蓝奏云", color: .appBlue)
                    }
                }
                if !row.str("beizhu").isEmpty {
                    Text(row.str("beizhu")).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if row.str("status") == "hidden" {
                StatusBadge(text: "已隐藏", color: .gray)
            }
        }
        .padding(.vertical, 3)
    }

    private var typeText: String {
        let t = row.str("type")
        return t.isEmpty ? "未分类" : t
    }
}
