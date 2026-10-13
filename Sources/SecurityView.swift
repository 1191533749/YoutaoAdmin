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

    // 左滑删除（Web 后台 black/del?ids=N）；失败/成功都给可见反馈，不再静默
    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            do {
                let data = try await api.getRaw(path: "black/del/ids/\(first)")
                switch ResponseParser.result(from: data) {
                case .success(let msg):
                    await load()
                    showBanner(Feedback.success("\(msg)：已从黑名单移除"))
                case .failure(let e):
                    showBanner(Feedback.failure(e.message))
                }
            } catch {
                showBanner(Feedback.failure("删除失败：\(error.localizedDescription)"))
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
    @State private var pendingBlack: Row?
    @State private var blacking = false

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(rows) { row in
                        HStack(spacing: 12) {
                            Button {
                                editingRow = row
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 34, height: 34)
                                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.appOrange))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(row.str("udid"))
                                            .font(.system(.subheadline, design: .monospaced))
                                            .foregroundColor(.primary)
                                        Text("\(row.str("identity")) · 异常 \(row.str("count")) 次")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button("拉黑") { pendingBlack = row }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                                .tint(.appRed)
                                .disabled(blacking)
                        }
                    }
                    .onDelete(perform: deleteRows)
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
                // Web 端「拉黑」按钮带「是否拉黑？」确认
                .confirmationDialog("是否拉黑？",
                                    isPresented: Binding(get: { pendingBlack != nil },
                                                         set: { if !$0 { pendingBlack = nil } }),
                                    titleVisibility: .visible) {
                    Button("拉黑", role: .destructive) {
                        if let r = pendingBlack { Task { await black(r.id) } }
                    }
                    Button("取消", role: .cancel) { pendingBlack = nil }
                } message: {
                    Text(pendingBlack.map { "将 \($0.str("udid")) 加入黑名单，并从异常监控移除" } ?? "")
                }
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

    // 后端 Monitor::black() 用 $this->request->request('ids') 取参（等价 $_REQUEST），
    // 路径形式 monitor/black/ids/5 取不到 ids，会直接返回「参数错误」；
    // Web 后台前端调用的就是 monitor/black?ids=N，这里保持一致。
    private func black(_ id: Int) async {
        guard let api = state.api else { return }
        blacking = true
        defer { blacking = false }
        do {
            let data = try await api.getRaw(path: "monitor/black?ids=\(id)")
            switch ResponseParser.result(from: data) {
            case .success(let msg):
                pendingBlack = nil
                await load()
                showBanner(Feedback.success("\(msg)：已拉黑并移出监控"))
            case .failure(let e):
                showBanner(Feedback.failure(e.message))
            }
        } catch {
            showBanner(Feedback.failure("请求失败：\(error.localizedDescription)"))
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

    // 左滑删除（Web 后台 monitor/del?ids=N）
    private func deleteRows(at offsets: IndexSet) {
        guard let first = offsets.map({ rows[$0].id }).first, let api = state.api else { return }
        Task {
            do {
                let data = try await api.getRaw(path: "monitor/del/ids/\(first)")
                switch ResponseParser.result(from: data) {
                case .success(let msg):
                    await load()
                    showBanner(Feedback.success("\(msg)：已删除该监控记录"))
                case .failure(let e):
                    showBanner(Feedback.failure(e.message))
                }
            } catch {
                showBanner(Feedback.failure("删除失败：\(error.localizedDescription)"))
            }
        }
    }
}
