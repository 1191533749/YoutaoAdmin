import SwiftUI

// 安全：黑名单 + 异常监控（分段切换）
struct SecurityView: View {
    @State private var segment = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    Text("黑名单").tag(0)
                    Text("异常监控").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if segment == 0 { BlackListView() } else { MonitorListView() }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("安全")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// 黑名单列表
private struct BlackListView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var newUDID = ""
    @State private var actionMessage: String?

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rows) { row in
                        HStack(spacing: 12) {
                            Image(systemName: "nosign")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Color.appRed))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.str("udid")).font(.system(.subheadline, design: .monospaced))
                                Text("添加于 \(row.str("addtime_text"))").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteRows)
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAdd) {
            NavigationView {
                Form {
                    Section(header: Text("拉黑 UDID")) {
                        TextField("UDID", text: $newUDID)
                            .autocapitalization(.none).disableAutocorrection(true)
                    }
                    if let actionMessage = actionMessage {
                        Section { Text(actionMessage).font(.caption).foregroundColor(.green) }
                    }
                    Section { Button("添加") { Task { await add() } }.buttonStyle(PrimaryButtonStyle()) }
                }
                .navigationTitle("拉黑 UDID")
                .navigationBarItems(trailing: Button("关闭") { showAdd = false })
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "black/index?offset=0&limit=100&sort=addtime&order=desc"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows; total = list.total
        }
    }

    private func add() async {
        actionMessage = nil
        let udid = newUDID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !udid.isEmpty else { actionMessage = "请输入 UDID"; return }
        guard let api = state.api else { return }
        if let data = try? await api.postForm(path: "black/add", fields: ["row[udid]": udid]) {
            switch ResponseParser.result(from: data) {
            case .success(let msg): actionMessage = msg; newUDID = ""; await load()
            case .failure(let e): actionMessage = e.message
            }
        } else { actionMessage = "请求失败" }
    }

    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            if let data = try? await api.getRaw(path: "black/del/ids/\(first)") {
                if case .success = ResponseParser.result(from: data) { await load() }
            }
        }
    }
}

// 异常监控列表
private struct MonitorListView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var newUDID = ""
    @State private var actionMessage: String?

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rows) { row in
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Color.appOrange))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.str("udid")).font(.system(.subheadline, design: .monospaced))
                                Text("\(row.str("identity")) · 异常 \(row.str("count")) 次")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("拉黑") { Task { await black(row.id) } }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                                .tint(.appRed)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAdd) {
            NavigationView {
                Form {
                    Section(header: Text("手动添加监控")) {
                        TextField("UDID", text: $newUDID)
                            .autocapitalization(.none).disableAutocorrection(true)
                    }
                    if let actionMessage = actionMessage {
                        Section { Text(actionMessage).font(.caption).foregroundColor(.green) }
                    }
                    Section { Button("添加") { Task { await add() } }.buttonStyle(PrimaryButtonStyle()) }
                }
                .navigationTitle("添加监控")
                .navigationBarItems(trailing: Button("关闭") { showAdd = false })
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "monitor/index?offset=0&limit=100"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows; total = list.total
        }
    }

    private func black(_ id: Int) async {
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "monitor/black/ids/\(id)") {
            if case .success = ResponseParser.result(from: data) { await load() }
        }
    }

    private func add() async {
        actionMessage = nil
        let udid = newUDID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !udid.isEmpty else { actionMessage = "请输入 UDID"; return }
        guard let api = state.api else { return }
        if let data = try? await api.postForm(path: "monitor/add", fields: ["row[udid]": udid]) {
            switch ResponseParser.result(from: data) {
            case .success(let msg): actionMessage = msg; newUDID = ""; await load()
            case .failure(let e): actionMessage = e.message
            }
        } else { actionMessage = "请求失败" }
    }
}
