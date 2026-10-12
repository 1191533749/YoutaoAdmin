import SwiftUI

struct ConfigView: View {
    @EnvironmentObject var state: AppState
    @State private var dylibOn = false
    @State private var look = "1"
    @State private var control = 0
    @State private var notice = ""
    @State private var time = "5"
    @State private var isLoading = false
    @State private var message: String?
    @State private var token = ""

    var body: some View {
        Form {
            Section(header: Text("动态库 UDID 验证（授权弹窗）")) {
                Toggle("总开关", isOn: $dylibOn).tint(.appAccent)
                HStack {
                    Text("远程时间锁（分钟）")
                    Spacer()
                    TextField("分钟", text: $look)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Picker("公告模式", selection: $control) {
                    ForEach(0..<Labels.controlOptions.count, id: \.self) { i in
                        Text(Labels.controlOptions[i].label).tag(Labels.controlOptions[i].value)
                    }
                }
                HStack {
                    Text("公告消失（秒）")
                    Spacer()
                    TextField("秒", text: $time)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
            Section(header: Text("公告文本")) {
                TextEditor(text: $notice)
                    .frame(minHeight: 140)
                    .font(.system(.footnote, design: .monospaced))
            }
            if let message = message {
                Section { Text(message).font(.footnote).foregroundColor(.green) }
            }
            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isLoading { ProgressView() } else { Text("保存配置").frame(maxWidth: .infinity) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading)
            }
        }
        .navigationTitle("授权弹窗设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        do {
            let html = String(data: try await api.getRaw(path: "general/config/index"), encoding: .utf8) ?? ""
            token = ResponseParser.token(from: html) ?? ""
            dylibOn = (Self.inputValue(html, key: "dylib-on") ?? "0") == "1"
            look = Self.inputValue(html, key: "dylib-look") ?? "1"
            time = Self.inputValue(html, key: "dylib-time") ?? "5"
            control = Int(Self.selectValue(html, key: "dylib-control") ?? "0") ?? 0
            notice = ResponseParser.decodeHTML(Self.textareaValue(html, key: "dylib-notice") ?? "")
        } catch {
            message = "读取配置失败：\(error.localizedDescription)"
        }
    }

    private func save() async {
        isLoading = true
        defer { isLoading = false }
        message = nil
        guard let api = state.api else { return }
        let fields = [
            "row[dylib-on]": dylibOn ? "1" : "0",
            "row[dylib-look]": look,
            "row[dylib-time]": time,
            "row[dylib-control]": String(control),
            "row[dylib-notice]": notice,
            "__token__": token
        ]
        do {
            let data = try await api.postForm(path: "general/config/edit", fields: fields)
            switch ResponseParser.result(from: data) {
            case .success(let msg): message = msg
            case .failure(let e): message = e.message
            }
            await load()
        } catch {
            message = "保存失败：\(error.localizedDescription)"
        }
    }

    private static func inputValue(_ html: String, key: String) -> String? {
        let pattern = "name=\"row\\[\(key)\\]\"[^>]*value=\"([^\"]*)\""
        return firstMatch(html, pattern: pattern)
    }
    private static func selectValue(_ html: String, key: String) -> String? {
        let blockPattern = "<select[^>]*name=\"row\\[\(key)\\]\"[^>]*>([\\s\\S]*?)</select>"
        guard let block = firstMatch(html, pattern: blockPattern) else { return nil }
        if let v = firstMatch(block, pattern: "<option[^>]*value=\"([^\"]*)\"[^>]*selected") { return v }
        return firstMatch(block, pattern: "<option[^>]*selected[^>]*value=\"([^\"]*)\"")
    }
    private static func textareaValue(_ html: String, key: String) -> String? {
        let pattern = "<textarea[^>]*name=\"row\\[\(key)\]\"[^>]*>([\\s\\S]*?)</textarea>"
        return firstMatch(html, pattern: pattern)
    }
    private static func firstMatch(_ html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = html as NSString
        guard let m = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1 else { return nil }
        return ns.substring(with: m.range(at: 1))
    }
}
