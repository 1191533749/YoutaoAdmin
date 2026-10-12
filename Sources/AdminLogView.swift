import SwiftUI

struct AdminLogView: View {
    @EnvironmentObject var state: AppState
    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var selected: Row?

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rows) { row in
                        Button { selected = row } label: { LogRow(row: row) }
                            .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteRows)
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
            }
        }
        .navigationTitle("操作日志（共 \(total)）")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $selected) { row in LogDetailSheet(row: row) }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "auth/adminlog/index?offset=0&limit=100&sort=createtime&order=desc"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows; total = list.total
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            if let data = try? await api.postForm(path: "auth/adminlog/del/ids/\(first)", fields: [:]),
               case .success = ResponseParser.result(from: data) {
                await load()
            }
        }
    }
}

private struct LogRow: View {
    let row: Row
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.appOrange))
            VStack(alignment: .leading, spacing: 3) {
                Text(row.str("title")).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(row.str("username")) · \(row.str("ip"))")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(DateUtil.format(row.str("createtime"))).font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct LogDetailSheet: View {
    let row: Row
    @Environment(\.presentationMode) var pm
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("操作")) {
                    Text(row.str("title")).font(.body.weight(.semibold))
                }
                Section(header: Text("内容")) {
                    Text(row.str("content")).font(.system(.footnote, design: .monospaced))
                }
                Section(header: Text("详情")) {
                    DetailRow(label: "管理员", value: row.str("username"))
                    DetailRow(label: "IP", value: row.str("ip"))
                    DetailRow(label: "时间", value: DateUtil.format(row.str("createtime")))
                    DetailRow(label: "URL", value: row.str("url"))
                    DetailRow(label: "设备", value: row.str("useragent"))
                }
            }
            .navigationTitle("日志详情")
            .navigationBarItems(trailing: Button("关闭") { pm.wrappedValue.dismiss() })
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value.isEmpty ? "—" : value).font(.footnote)
        }
        .padding(.vertical, 2)
    }
}
