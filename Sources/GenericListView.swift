import SwiftUI

/// 通用列表：列表 + 下拉刷新 + 左滑删除（FastAdmin 标准 CRUD）
/// 传 formFields 即自动获得「+ 新增」与「点击编辑」能力
struct GenericListView: View {
    @EnvironmentObject var state: AppState
    let title: String
    let path: String          // e.g. "auth/group"（不含 /index）
    let icon: String
    let color: Color
    let primaryKey: String
    let secondaryKeys: [String]
    let statusKey: String?    // 可选状态字段，用于徽章

    // 可选：表单能力
    var formFields: [FormField]? = nil
    var useToken: Bool = false
    var addTitle: String? = nil
    var formDefaults: [String: String] = [:]
    var editInitial: ((Row) -> [String: String])? = nil

    @State private var rows: [Row] = []
    @State private var total = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAdd = false
    @State private var editingRow: Row?
    @State private var banner: Feedback?

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if let errorMessage = errorMessage {
                        Text(errorMessage).font(.footnote).foregroundColor(.appRed)
                    }
                    ForEach(rows) { row in
                        HStack(spacing: 12) {
                            Image(systemName: icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 9).fill(color))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(primaryText(row)).font(.subheadline.weight(.semibold)).lineLimit(1)
                                let sub = secondaryText(row)
                                if !sub.isEmpty {
                                    Text(sub).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            if let statusKey = statusKey {
                                let s = row.str(statusKey)
                                if !s.isEmpty {
                                    StatusBadge(text: statusText(s), color: isBad(s) ? .appRed : .appGreen)
                                }
                            }
                            if canEdit {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Color(UIColor.tertiaryLabel))
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture { if canEdit { editingRow = row } }
                    }
                    .onDelete(perform: deleteRows)
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
            }
        }
        .overlay(alignment: .top) { ToastBanner(feedback: banner) }
        .navigationTitle("\(title)（共 \(total)）")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if canAdd {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAdd) {
            if let fields = formFields {
                SpecFormView(title: addTitle ?? "新增\(title)", path: path,
                             fields: fields, initial: formDefaults, useToken: useToken) { await load() }
                    .environmentObject(state)
            }
        }
        .sheet(item: $editingRow) { row in
            if let fields = formFields {
                SpecFormView(title: "编辑\(title)", path: path, editingId: row.id,
                             fields: fields, initial: editInitial?(row) ?? row.stringDict,
                             useToken: useToken) { await load() }
                    .environmentObject(state)
            }
        }
    }

    private var canAdd: Bool { (formFields?.isEmpty == false) }
    private var canEdit: Bool { canAdd && editInitial != nil }

    private func primaryText(_ row: Row) -> String {
        let v = row.str(primaryKey)
        if !v.isEmpty { return v }
        return "ID \(row.id)"
    }
    private func secondaryText(_ row: Row) -> String {
        let parts = secondaryKeys.compactMap { key -> String? in
            let v = row.str(key)
            return v.isEmpty ? nil : "\(key)=\(v)"
        }
        return parts.joined(separator: " · ")
    }
    private func statusText(_ s: String) -> String {
        if s == "hidden" { return "禁用" }
        if s == "normal" { return "正常" }
        return s
    }
    private func isBad(_ s: String) -> Bool { s == "hidden" }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        guard let api = state.api else { return }
        if let data = try? await api.getRaw(path: "\(path)/index?offset=0&limit=200"),
           let list = ResponseParser.list(from: data) {
            rows = list.rows
            total = list.total
        } else {
            errorMessage = "加载失败（可能无权限或接口不可用）"
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            if let data = try? await api.postForm(path: "\(path)/del/ids/\(first)", fields: [:] ),
               case .success = ResponseParser.result(from: data) {
                await load()
            }
        }
    }
}
