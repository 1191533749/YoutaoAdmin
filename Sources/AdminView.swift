import SwiftUI

struct AdminView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var resettingRow: Row?

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rows) { row in
                        Button { resettingRow = row } label: { AdminRow(row: row) }
                            .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteRows)
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
            }
        }
        .navigationTitle("管理员（共 \(total)）")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAdd) { AdminAddSheet { await load() } }
        .sheet(item: $resettingRow) { row in
            AdminResetSheet(row: row) { await load() }
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
            Text("点击重置密码").font(.caption2).foregroundColor(.appAccent)
        }
        .padding(.vertical, 2)
    }
}

private struct AdminAddSheet: View {
    let onDone: () async -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.presentationMode) var pm
    @State private var username = ""
    @State private var nickname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var message: String?
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("新管理员")) {
                    TextField("用户名（3-12位字母数字）", text: $username)
                        .autocapitalization(.none).disableAutocorrection(true)
                    TextField("昵称", text: $nickname)
                    TextField("邮箱", text: $email)
                        .keyboardType(.emailAddress).autocapitalization(.none).disableAutocorrection(true)
                    SecureField("密码（6-16位）", text: $password)
                }
                if let message = message {
                    Section { Text(message).font(.caption).foregroundColor(.green) }
                }
                Section {
                    Button { Task { await save() } } label: {
                        if saving { ProgressView() } else { Text("创建").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(saving)
                }
            }
            .navigationTitle("添加管理员")
            .navigationBarItems(trailing: Button("关闭") { pm.wrappedValue.dismiss() })
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        message = nil
        guard let api = state.api else { return }
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else { message = "请填写完整"; return }

        // 取 CSRF token
        guard let html = String(data: (try? await api.getRaw(path: "auth/admin/add")) ?? Data(), encoding: .utf8),
              let token = ResponseParser.token(from: html), !token.isEmpty else {
            message = "获取令牌失败"; return
        }
        let fields = ["row[username]": username, "row[nickname]": nickname,
                      "row[email]": email, "row[password]": password, "group[0]": "1", "__token__": token]
        if let data = try? await api.postForm(path: "auth/admin/add", fields: fields) {
            switch ResponseParser.result(from: data) {
            case .success(let m): message = m; await onDone(); pm.wrappedValue.dismiss()
            case .failure(let e): message = e.message
            }
        } else { message = "请求失败" }
    }
}

private struct AdminResetSheet: View {
    let row: Row
    let onDone: () async -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.presentationMode) var pm
    @State private var password = ""
    @State private var confirm = ""
    @State private var message: String?
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("重置 \(row.str("username")) 的密码")) {
                    SecureField("新密码（6-16位）", text: $password)
                    SecureField("确认新密码", text: $confirm)
                }
                if let message = message {
                    Section { Text(message).font(.caption).foregroundColor(.green) }
                }
                Section {
                    Button { Task { await save() } } label: {
                        if saving { ProgressView() } else { Text("重置密码").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(saving)
                }
            }
            .navigationTitle("重置密码")
            .navigationBarItems(trailing: Button("关闭") { pm.wrappedValue.dismiss() })
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        message = nil
        guard let api = state.api else { return }
        guard password.count >= 6, password == confirm else {
            message = "密码需 6-16 位且两次一致"; return
        }

        guard let html = String(data: (try? await api.getRaw(path: "auth/admin/edit/ids/\(row.id)")) ?? Data(), encoding: .utf8),
              let token = ResponseParser.token(from: html), !token.isEmpty else {
            message = "获取令牌失败"; return
        }
        let fields = ["row[username]": row.str("username"), "row[email]": row.str("email"),
                      "row[password]": password, "__token__": token]
        if let data = try? await api.postForm(path: "auth/admin/edit/ids/\(row.id)", fields: fields) {
            switch ResponseParser.result(from: data) {
            case .success(let m): message = m; await onDone(); pm.wrappedValue.dismiss()
            case .failure(let e): message = e.message
            }
        } else { message = "请求失败" }
    }
}
