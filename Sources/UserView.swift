import SwiftUI

struct UserView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var search = ""
    @State private var editingRow: Row?
    @State private var banner: Feedback?

    // 对齐 Web 后台 user/user/edit 表单字段
    static let editFields: [FormField] = [
        FormField("nickname", "昵称", required: true, section: "基本资料"),
        FormField("email", "邮箱", placeholder: "user@example.com", section: "基本资料"),
        FormField("mobile", "手机号", kind: .number, section: "基本资料"),
        FormField("avatar", "头像地址", section: "基本资料"),
        FormField("gender", "性别", kind: .options([FieldOption("1", "男"), FieldOption("0", "女"), FieldOption("2", "保密")]), value: "2", section: "基本资料"),
        FormField("birthday", "生日", placeholder: "1990-01-01", section: "基本资料"),
        FormField("bio", "个人简介", kind: .textarea, section: "基本资料"),
        FormField("level", "等级", kind: .number, value: "1", section: "等级与资产"),
        FormField("money", "余额", kind: .decimal, value: "0", section: "等级与资产"),
        FormField("score", "积分", kind: .number, value: "0", section: "等级与资产"),
        FormField("successions", "连续登录天数", kind: .number, value: "0", section: "等级与资产"),
        FormField("maxsuccessions", "最大连续登录", kind: .number, value: "0", section: "等级与资产"),
        FormField("status", "状态", kind: .options([FieldOption("normal", "正常"), FieldOption("hidden", "隐藏")]), value: "normal", section: "状态")
    ]

    private var filtered: [Row] {
        let kw = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { return rows }
        return rows.filter { row in
            row.str("username").contains(kw) || row.str("nickname").contains(kw)
                || row.str("email").contains(kw) || row.str("mobile").contains(kw)
        }
    }

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { row in
                        Button { editingRow = row } label: { UserRow(row: row) }
                            .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteRows)
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
                .searchable(text: $search, prompt: "搜索用户名/昵称/手机号")
            }
        }
        .overlay(alignment: .top) { ToastBanner(feedback: banner) }
        .navigationTitle("会员管理（共 \(total)）")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $editingRow) { row in
            SpecFormView(title: "编辑会员", path: "user", editingId: row.id,
                         fields: UserView.editFields, initial: UserView.initial(from: row)) {
                await load()
                banner = Feedback.success("已保存 @\(row.str("username")) 的资料")
            }
            .environmentObject(state)
        }
    }

    static func initial(from row: Row) -> [String: String] {
        var d = row.stringDict
        if (d["gender"] ?? "").isEmpty { d["gender"] = "2" }
        if (d["status"] ?? "").isEmpty { d["status"] = "normal" }
        return d
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "user/index?offset=0&limit=500"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows; total = list.total
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ filtered[$0].id }).first, let api = state.api else { return }
        Task {
            if let data = try? await api.getRaw(path: "user/del/ids/\(first)") {
                if case .success = ResponseParser.result(from: data) { await load() }
            }
        }
    }
}

private struct UserRow: View {
    let row: Row
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.appTeal.opacity(0.15))
                Text(String((row.str("nickname").isEmpty ? row.str("username") : row.str("nickname")).prefix(1)))
                    .font(.body.weight(.bold)).foregroundColor(.appTeal)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.str("nickname").isEmpty ? row.str("username") : row.str("nickname"))
                        .font(.body.weight(.semibold))
                    StatusBadge(text: Labels.userStatusLabel(row.str("status")),
                                color: row.str("status") == "hidden" ? .appRed : .appGreen)
                }
                Text(row.str("mobile").isEmpty ? "@" + row.str("username") : "@" + row.str("username") + " · " + row.str("mobile"))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("余额 ¥\(row.str("money"))").font(.caption.weight(.semibold)).foregroundColor(.appBlue)
                Text("\(row.str("score")) 积分").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
