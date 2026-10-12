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
    @State private var editingRow: Row?
    @State private var banner: Feedback?
    @State private var newUDID = ""
    @State private var addFeedback: Feedback?
    @State private var saving = false

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
                    FeedbackSection(feedback: addFeedback)
                    Section {
                        Button {
                            Task { await add() }
                        } label: {
                            Text(saving ? "提交中…" : "添加").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(saving)
                    }
                }
                .navigationTitle("拉黑 UDID")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("关闭") { showAdd = false })
            }
        }
        .sheet(item: $editingRow) { row in
            SpecFormView(title: "编辑黑名单", path: "black", editingId: row.id,
                         fields: [
                            FormField("udid", "UDID", required: true, section: "设备"),
                            FormField("addtime", "添加时间（时间戳）", kind: .number, section: "时间")
                         ],
                         initial: row.stringDict) { await load() }
                .environmentObject(state)
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
        saving = true
        defer { saving = false }
        addFeedback = nil
        let udid = newUDID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !udid.isEmpty else { addFeedback = Feedback.failure("请输入 UDID"); return }
        guard udid.count <= 128 else { addFeedback = Feedback.failure("UDID 长度不能超过 128 个字符"); return }
        guard let api = state.api else { addFeedback = Feedback.failure("未连接服务器"); return }
        do {
            let data = try await api.postForm(path: "black/add", fields: ["row[udid]": udid])
            switch ResponseParser.result(from: data) {
            case .success(let msg):
                newUDID = ""
                await load()
                showAdd = false
                showBanner(Feedback.success("\(msg)：已拉黑 \(udid)"))
            case .failure(let e):
                addFeedback = Feedback.failure(e.message)
            }
        } catch {
            addFeedback = Feedback.failure("请求失败：\(error.localizedDescription)")
        }
    }

    private func showBanner(_ fb: Feedback) {
        banner = fb
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if banner == fb { banner = nil }
        }
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
    @State private var editingRow: Row?
    @State private var banner: Feedback?
    @State private var newUDID = ""
    @State private var newIdentity = ""
    @State private var addFeedback: Feedback?
    @State private var saving = false

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
                        TextField("身份（默认「手动添加」）", text: $newIdentity)
                    }
                    FeedbackSection(feedback: addFeedback)
                    Section {
                        Button {
                            Task { await add() }
                        } label: {
                            Text(saving ? "提交中…" : "添加").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(saving)
                    }
                }
                .navigationTitle("添加监控")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("关闭") { showAdd = false })
            }
        }
        .sheet(item: $editingRow) { row in
            SpecFormView(title: "编辑监控", path: "monitor", editingId: row.id,
                         fields: [
                            FormField("udid", "UDID", required: true, section: "设备"),
                            FormField("identity", "身份", placeholder: "添加者 / 破解者", section: "设备"),
                            FormField("count", "次数", kind: .number, section: "设备"),
                            FormField("addtime", "添加时间", section: "时间")
                         ],
                         initial: row.stringDict) { await load() }
                .environmentObject(state)
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
            switch ResponseParser.result(from: data) {
            case .success(let msg):
                await load()
                showBanner(Feedback.success(msg))
            case .failure(let e):
                showBanner(Feedback.failure(e.message))
            }
        }
    }

    private func add() async {
        saving = true
        defer { saving = false }
        addFeedback = nil
        let udid = newUDID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !udid.isEmpty else { addFeedback = Feedback.failure("请输入 UDID"); return }
        guard let api = state.api else { addFeedback = Feedback.failure("未连接服务器"); return }
        var fields = ["row[udid]": udid]
        let identity = newIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !identity.isEmpty { fields["row[identity]"] = identity }
        do {
            let data = try? await api.postForm(path: "monitor/add", fields: fields)
            guard let data = data else { addFeedback = Feedback.failure("请求失败"); return }
            switch ResponseParser.result(from: data) {
            case .success(let msg):
                newUDID = ""; newIdentity = ""
                await load()
                showAdd = false
                showBanner(Feedback.success("\(msg)：已加入监控 \(udid)"))
            case .failure(let e):
                addFeedback = Feedback.failure(e.message)
            }
        }
    }

    private func showBanner(_ fb: Feedback) {
        banner = fb
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if banner == fb { banner = nil }
        }
    }

    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            if let data = try? await api.getRaw(path: "monitor/del/ids/\(first)") {
                if case .success = ResponseParser.result(from: data) { await load() }
            }
        }
    }
}
