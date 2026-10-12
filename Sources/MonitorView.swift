import SwiftUI

struct MonitorView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var newUDID = ""
    @State private var showAdd = false
    @State private var actionMessage: String?

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
                                    Text(row.str("udid")).font(.system(.body, design: .monospaced))
                                    Text("\(row.str("identity")) · 异常 \(row.str("count")) 次")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("拉黑") { Task { await black(row.id) } }
                                    .buttonStyle(.bordered).font(.caption)
                            }
                        }
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("异常监控（共 \(total)）")
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
                        Section { Button("添加") { Task { await add() } } }
                    }
                    .navigationTitle("添加监控")
                    .navigationBarItems(trailing: Button("关闭") { showAdd = false })
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "monitor/index?offset=0&limit=100"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows
            total = list.total
        } else {
            errorMessage = "加载失败"
        }
    }

    private func black(_ id: Int) async {
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "monitor/black/ids/\(id)") {
            switch ResponseParser.result(from: data) {
            case .success: await load()
            case .failure: break
            }
        }
    }

    private func add() async {
        actionMessage = nil
        let udid = newUDID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !udid.isEmpty else { actionMessage = "请输入 UDID"; return }
        guard let api = state.api else { return }
        if let data = try? await api.postForm(path: "monitor/add", fields: ["row[udid]": udid]) {
            switch ResponseParser.result(from: data) {
            case .success(let msg):
                actionMessage = msg
                newUDID = ""
                await load()
            case .failure(let e):
                actionMessage = e.message
            }
        } else {
            actionMessage = "请求失败"
        }
    }
}
