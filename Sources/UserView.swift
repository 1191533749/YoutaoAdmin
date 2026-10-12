import SwiftUI

struct UserView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var search = ""
    @State private var editingRow: Row?

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
        .navigationTitle("会员管理（共 \(total)）")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $editingRow) { row in
            UserEditSheet(row: row) { await load() }
        }
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
                    Text(row.str("nickname")).font(.body.weight(.semibold))
                    StatusBadge(text: Labels.userStatusLabel(row.str("status")),
                                color: row.str("status") == "hidden" ? .appRed : .appGreen)
                }
                Text("@\(row.str("username"))\(row.str("mobile").isEmpty ? "" : " · \(row.str("mobile"))")
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

private struct UserEditSheet: View {
    let row: Row
    let onDone: () async -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.presentationMode) var pm
    @State private var nickname = ""
    @State private var money = ""
    @State private var score = ""
    @State private var status = "normal"
    @State private var message: String?
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("会员 @\(row.str("username"))")) {
                    TextField("昵称", text: $nickname)
                    TextField("余额", text: $money).keyboardType(.decimalPad)
                    TextField("积分", text: $score).keyboardType(.numberPad)
                    Picker("状态", selection: $status) {
                        Text("正常").tag("normal")
                        Text("隐藏").tag("hidden")
                    }
                }
                if let message = message {
                    Section { Text(message).font(.caption).foregroundColor(.green) }
                }
                Section {
                    Button { Task { await save() } } label: {
                        if saving { ProgressView() } else { Text("保存").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(saving)
                }
            }
            .navigationTitle("编辑会员")
            .navigationBarItems(trailing: Button("关闭") { pm.wrappedValue.dismiss() })
            .onAppear {
                nickname = row.str("nickname")
                money = row.str("money")
                score = row.str("score")
                status = row.str("status")
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        message = nil
        guard let api = state.api else { return }
        let fields = ["row[nickname]": nickname, "row[money]": money, "row[score]": score, "row[status]": status]
        if let data = try? await api.postForm(path: "user/edit/ids/\(row.id)", fields: fields) {
            switch ResponseParser.result(from: data) {
            case .success(let m): message = m; await onDone(); pm.wrappedValue.dismiss()
            case .failure(let e): message = e.message
            }
        } else { message = "请求失败" }
    }
}
