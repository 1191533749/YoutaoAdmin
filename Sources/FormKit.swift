import SwiftUI

// MARK: - 统一反馈：杜绝 FastAdmin 空 msg 造成的「白框」

struct Feedback: Equatable {
    var text: String = ""
    var isError: Bool = false

    static func success(_ msg: String) -> Feedback {
        let t = msg.trimmingCharacters(in: .whitespacesAndNewlines)
        return Feedback(text: t.isEmpty ? "操作成功" : t, isError: false)
    }
    static func failure(_ msg: String) -> Feedback {
        let t = msg.trimmingCharacters(in: .whitespacesAndNewlines)
        return Feedback(text: t.isEmpty ? "操作失败" : t, isError: true)
    }
    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct FeedbackRow: View {
    let feedback: Feedback
    var body: some View {
        Label(feedback.text, systemImage: feedback.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundColor(feedback.isError ? .appRed : .appGreen)
    }
}

/// 内容为空时整行不渲染、不占高度 —— 修复「多出来的白框」
struct FeedbackSection: View {
    let feedback: Feedback?
    var body: some View {
        Group {
            if let fb = feedback, !fb.isEmpty {
                Section { FeedbackRow(feedback: fb) }
            }
        }
    }
}

/// 列表页顶部横幅（用于「已生成 N 张卡密」这类跨页面反馈）
struct ToastBanner: View {
    let feedback: Feedback?
    var body: some View {
        Group {
            if let fb = feedback, !fb.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: fb.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    Text(fb.text).font(.subheadline.weight(.medium)).lineLimit(2)
                    Spacer(minLength: 0)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fb.isError ? Color.appRed : Color.appGreen))
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - 声明式表单（对齐 Web 后端 add / edit 表单字段）

struct FieldOption: Identifiable, Equatable {
    let value: String
    let label: String
    var id: String { value }
    init(_ value: String, _ label: String) { self.value = value; self.label = label }
}

enum FieldKind: Equatable {
    case text
    case number
    case decimal
    case secure
    case textarea
    case options([FieldOption])
    case toggle
    case color
}

struct FormField {
    let key: String
    let label: String
    var kind: FieldKind = .text
    var placeholder: String = ""
    var required: Bool = false
    var defaultValue: String = ""
    var section: String = ""
    var footer: String = ""

    init(_ key: String, _ label: String, kind: FieldKind = .text, placeholder: String = "",
         required: Bool = false, value: String = "", section: String = "", footer: String = "") {
        self.key = key
        self.label = label
        self.kind = kind
        self.placeholder = placeholder
        self.required = required
        self.defaultValue = value
        self.section = section
        self.footer = footer
    }
}

/// 通用新增 / 编辑表单：POST <path>/add 或 <path>/edit/ids/<id>，字段名 row[key]
struct SpecFormView: View {
    let title: String
    let path: String
    let editingId: Int?
    let fields: [FormField]
    let closeAfterSave: Bool
    let useToken: Bool
    let onDone: () async -> Void

    @EnvironmentObject var state: AppState
    @Environment(\.presentationMode) private var pm

    @State private var values: [String: String]
    @State private var feedback: Feedback?
    @State private var saving = false

    init(title: String, path: String, editingId: Int? = nil, fields: [FormField],
         initial: [String: String] = [:], closeAfterSave: Bool = true,
         useToken: Bool = false, onDone: @escaping () async -> Void) {
        self.title = title
        self.path = path
        self.editingId = editingId
        self.fields = fields
        self.closeAfterSave = closeAfterSave
        self.useToken = useToken
        self.onDone = onDone
        var v: [String: String] = [:]
        for f in fields { v[f.key] = initial[f.key] ?? f.defaultValue }
        _values = State(initialValue: v)
    }

    private var sectionNames: [String] {
        var seen: [String] = []
        for f in fields where !seen.contains(f.section) { seen.append(f.section) }
        return seen
    }

    var body: some View {
        NavigationView {
            Form {
                ForEach(sectionNames, id: \.self) { sec in
                    Section(header: Text(sec)) {
                        ForEach(fields.filter { $0.section == sec }, id: \.key) { f in
                            fieldRow(f)
                        }
                    }
                }
                FeedbackSection(feedback: feedback)
                Section {
                    Button { Task { await save() } } label: {
                        if saving {
                            Text("提交中…").frame(maxWidth: .infinity)
                        } else {
                            Text(editingId == nil ? "添加" : "保存").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(saving)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("关闭") { pm.wrappedValue.dismiss() })
        }
    }

    @ViewBuilder
    private func fieldRow(_ f: FormField) -> some View {
        switch f.kind {
        case .textarea:
            VStack(alignment: .leading, spacing: 6) {
                Text(f.label).font(.caption).foregroundColor(.secondary)
                TextEditor(text: binding(f.key))
                    .frame(minHeight: 100)
                    .font(.system(.footnote, design: .monospaced))
                if !f.footer.isEmpty {
                    Text(f.footer).font(.caption2).foregroundColor(.secondary)
                }
            }
        case .options(let opts):
            Picker(f.label, selection: binding(f.key)) {
                ForEach(opts) { o in Text(o.label).tag(o.value) }
            }
        case .toggle:
            Toggle(f.label, isOn: boolBinding(f.key))
        case .secure:
            SecureField(f.label, text: binding(f.key))
        case .number, .decimal:
            HStack {
                Text(f.label)
                Spacer()
                TextField(f.placeholder.isEmpty ? "0" : f.placeholder, text: binding(f.key))
                    .keyboardType(f.kind == .number ? .numberPad : .decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 160)
            }
        case .color:
            HStack {
                Text(f.label)
                Spacer()
                TextField("#000000", text: binding(f.key))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }
        case .text:
            TextField(f.placeholder.isEmpty ? f.label : f.placeholder, text: binding(f.key))
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }
    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { (values[key] ?? "0") == "1" },
                set: { values[key] = $0 ? "1" : "0" })
    }

    private func save() async {
        saving = true
        defer { saving = false }
        feedback = nil
        guard let api = state.api else { feedback = Feedback.failure("未连接服务器"); return }
        for f in fields where f.required {
            if (values[f.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                feedback = Feedback.failure("请填写「\(f.label)」")
                return
            }
        }
        var body: [String: String] = [:]
        for f in fields {
            let v = values[f.key] ?? ""
            if f.required || !v.isEmpty { body["row[\(f.key)]"] = v }
        }
        let action = editingId == nil ? "\(path)/add" : "\(path)/edit/ids/\(editingId!)"
        // auth/group、auth/rule、auth/admin、general/config、general/profile 走 $this->token() 校验，
        // 必须先 GET 表单页取到隐藏的 __token__（一次性，取完即用）。
        if useToken {
            if let d = try? await api.getRaw(path: action),
               let html = String(data: d, encoding: .utf8),
               let t = ResponseParser.token(from: HTMLUtil.unescape(html)) {
                body["__token__"] = t
            } else {
                feedback = Feedback.failure("获取安全令牌失败，请重试")
                return
            }
        }
        do {
            let data = try await api.postForm(path: action, fields: body)
            switch ResponseParser.result(from: data) {
            case .success(let m):
                feedback = Feedback.success(m)
                await onDone()
                if closeAfterSave {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    pm.wrappedValue.dismiss()
                }
            case .failure(let e):
                feedback = Feedback.failure(e.message)
            }
        } catch {
            feedback = Feedback.failure("请求失败：\(error.localizedDescription)")
        }
    }
}

/// 远端图标（后端 image 字段存的是相对路径 /uploads/...）
struct RemoteIcon: View {
    let path: String
    let siteRoot: String
    var size: CGFloat = 34
    var fallbackIcon: String = "app.fill"
    var tint: Color = .appAccent

    private var url: URL? {
        let p = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if p.isEmpty { return nil }
        if p.hasPrefix("http") { return URL(string: p) }
        let root = siteRoot.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return URL(string: root + (p.hasPrefix("/") ? p : "/" + p))
    }

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.15)))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var placeholder: some View {
        Image(systemName: fallbackIcon).font(.system(size: size * 0.45, weight: .semibold)).foregroundColor(tint)
    }
}
