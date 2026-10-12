import SwiftUI

// 管理员管理：新增（含分组）/ 编辑（含分组，避免清空权限）/ 重置密码 / 删除
struct AdminView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var editingRow: Row?
    @State private var banner: Feedback?

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rows) { row in
                        Button { editingRow = row } label: { AdminRow(row: row) }
                            .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteRows)
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
            }
        }
        .overlay(alignment: .top) { ToastBanner(feedback: banner) }
        .navigationTitle("管理员（共 \(total)）")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAdd) {
            AdminEditSheet(row: nil) { await load() }.environmentObject(state)
        }
        .sheet(item: $editingRow) { row in
            AdminEditSheet(row: row) { await load() }.environmentObject(state)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "auth/admin/index?offset=0&limit=100"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows; total = list.total
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            if let data = try? await api.postForm(path: "auth/admin/del/ids/\(first)", fields: [:]),
               case .success = ResponseParser.result(from: data) {
                await load()
            }
        }
    }
}

private struct AdminRow: View {
    let row: Row
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.appBlue.opacity(0.15))
                Text(String(row.str("username").prefix(1).uppercased()))
                    .font(.body.weight(.bold)).foregroundColor(.appBlue)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(row.str("username")).font(.body.weight(.semibold))
                    StatusBadge(text: Labels.adminStatusLabel(row.str("status")),
                                color: row.str("status") == "hidden" ? .appRed : .appGreen)
                }
                Text(row.str("email")).font(.caption).foregroundColor(.secondary).lineLimit(1)
                if !row.str("groups_text").isEmpty {
                    Text(row.str("groups_text")).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, 2)
    }
}

// 新增 / 编辑管理员：row: nil = 新增
private struct AdminEditSheet: View {
    let row: Row?
    let onDone: () async -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.presentationMode) var pm

    @State private var username = ""
    @State private var nickname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var status = "normal"
    @State private var groups: [Row] = []
    @State private var selectedGroups: Set<String> = []
    @State private var groupsLoaded = false
    @State private var feedback: Feedback?
    @State private var saving = false

    private var isEdit: Bool { row != nil }
    private var action: String { isEdit ? "auth/admin/edit/ids/\(row!.id)" : "auth/admin/add" }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(isEdit ? "账号（\(row!.str("username"))）" : "新管理员"), footer: Text(isEdit ? "密码留空表示不修改" : "用户名 3-12 位字母数字，密码 6-16 位")) {
                    TextField("用户名", text: $username)
                        .autocapitalization(.none).disableAutocorrection(true)
                    TextField("昵称", text: $nickname)
                    TextField("邮箱", text: $email)
                        .keyboardType(.emailAddress).autocapitalization(.none).disableAutocorrection(true)
                    SecureField(isEdit ? "新密码（留空不改）" : "密码", text: $password)
                    Picker("状态", selection: $status) {
                        Text("正常").tag("normal")
                        Text("禁用").tag("hidden")
                    }
                }
                Section(header: Text("所属分组"), footer: Text("编辑时若一个都不勾选会清空该管理员的全部权限，请至少勾选一个")) {
                    if !groupsLoaded {
                        ProgressView()
                    } else if groups.isEmpty {
                        Text("未读取到分组").font(.footnote).foregroundColor(.secondary)
                    } else {
                        ForEach(groups) { g in
                            Button {
                                let key = String(g.id)
                                if selectedGroups.contains(key) { selectedGroups.remove(key) } else { selectedGroups.insert(key) }
                            } label: {
                                HStack {
                                    Text(g.str("name")).foregroundColor(.primary)
                                    Spacer()
                                    if selectedGroups.contains(String(g.id)) {
                                        Image(systemName: "checkmark").foregroundColor(.appAccent)
                                    }
                                }
                            }
                        }
                    }
                }
                FeedbackSection(feedback: feedback)
                Section {
                    Button { Task { await save() } } label: {
                        if saving { Text("提交中…").frame(maxWidth: .infinity) }
                        else { Text(isEdit ? "保存" : "创建").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(saving || !groupsLoaded)
                }
            }
            .navigationTitle(isEdit ? "编辑管理员" : "添加管理员")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("关闭") { pm.wrappedValue.dismiss() })
            .task { await prepare() }
        }
    }

    private func prepare() async {
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "auth/group/index?offset=0&limit=100"),
           let list = ResponseParser.list(from: data) {
            groups = list.rows
        }
        if let row = row {
            username = row.str("username")
            email = row.str("email")
            nickname = row.str("nickname")
            status = row.str("status").isEmpty ? "normal" : row.str("status")
        }
        // 编辑时从表单页解析当前所属分组 + 隐藏 __token__
        if isEdit {
            if let d = try? await api.getRaw(path: action),
               let html = String(data: d, encoding: .utf8) {
                let h = HTMLUtil.unescape(html)
                for gid in AdminEditSheet.selectedGroupIds(h) { selectedGroups.insert(gid) }
                if username.isEmpty { username = HTMLUtil.inputValue(h, key: "username") ?? "" }
                if email.isEmpty { email = HTMLUtil.inputValue(h, key: "email") ?? "" }
                if nickname.isEmpty { nickname = HTMLUtil.inputValue(h, key: "nickname") ?? "" }
            }
        } else if selectedGroups.isEmpty, let first = groups.first {
            selectedGroups.insert(String(first.id))
        }
        groupsLoaded = true
    }

    private func save() async {
        saving = true
        defer { saving = false }
        feedback = nil
        guard let api = state.api else { feedback = Feedback.failure("未连接服务器"); return }
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { feedback = Feedback.failure("请填写用户名"); return }
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { feedback = Feedback.failure("请填写邮箱"); return }
        if !isEdit && password.count < 6 || isEdit && !password.isEmpty && (password.count < 6 || password.count > 16) {
            feedback = Feedback.failure("密码需 6-16 位"); return
        }
        guard !selectedGroups.isEmpty else { feedback = Feedback.failure("请至少选择一个分组"); return }
        // 一次性 __token__ 必须现场取
        guard let d = try? await api.getRaw(path: action),
              let html = String(data: d, encoding: .utf8),
              let token = ResponseParser.token(from: HTMLUtil.unescape(html)) else {
            feedback = Feedback.failure("获取安全令牌失败，请重试"); return
        }
        var fields = ["row[username]": username, "row[email]": email,
                      "row[nickname]": nickname, "row[status]": status, "__token__": token]
        if !password.isEmpty { fields["row[password]"] = password }
        if isEdit, let row = row {
            let lf = row.str("loginfailure")
            fields["row[loginfailure]"] = lf.isEmpty ? "0" : lf
        }
        for (i, gid) in selectedGroups.sorted().enumerated() { fields["group[\(i)]"] = gid }
        do {
            let data = try await api.postForm(path: action, fields: fields)
            switch ResponseParser.result(from: data) {
            case .success(let m):
                feedback = Feedback.success(m)
                await onDone()
                try? await Task.sleep(nanoseconds: 700_000_000)
                pm.wrappedValue.dismiss()
            case .failure(let e):
                feedback = Feedback.failure(e.message)
            }
        } catch {
            feedback = Feedback.failure("请求失败：\(error.localizedDescription)")
        }
    }

    /// 从编辑页 HTML 的 <select name="group[]"> 里取当前已选分组 ID
    static func selectedGroupIds(_ html: String) -> [String] {
        guard let s = html.range(of: "name=\"group[]\"") else { return [] }
        guard let e = html.range(of: "</select>", options: [], range: s.upperBound..<html.endIndex) else { return [] }
        let block = String(html[s.upperBound..<e.lowerBound])
        var out: [String] = []
        guard let r = try? NSRegularExpression(pattern: "<option value=\"(\\d+)\"[^>]*selected") else { return [] }
        let ns = block as NSString
        for m in r.matches(in: block, range: NSRange(location: 0, length: ns.length)) where m.numberOfRanges > 1 {
            out.append(ns.substring(with: m.range(at: 1)))
        }
        return out
    }
}
