import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var state: AppState
    @State private var nickname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var token = ""
    @State private var isLoading = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        Form {
            Section(header: Text("账号信息")) {
                HStack { Text("昵称"); Spacer(); TextField("昵称", text: $nickname).multilineTextAlignment(.trailing) }
                HStack { Text("邮箱"); Spacer(); TextField("邮箱", text: $email)
                    .keyboardType(.emailAddress).autocapitalization(.none).disableAutocorrection(true)
                    .multilineTextAlignment(.trailing) }
            }
            Section(header: Text("修改密码（不改就留空）")) {
                SecureField("新密码（6-16位）", text: $password)
                SecureField("确认新密码", text: $confirm)
            }
            if let message = message {
                Section { Text(message).font(.footnote).foregroundColor(isError ? .appRed : .appGreen) }
            }
            Section {
                Button { Task { await save() } } label: {
                    if isLoading { ProgressView() } else { Text("保存").frame(maxWidth: .infinity) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading)
            }
        }
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let api = state.api else { return }
        guard let data = try? await api.getRaw(path: "general/profile/index"),
              let raw = String(data: data, encoding: .utf8) else { return }
        let html = HTMLUtil.unescape(raw)
        token = ResponseParser.token(from: html) ?? ""
        nickname = HTMLUtil.inputValue(html, key: "nickname") ?? ""
        email = HTMLUtil.inputValue(html, key: "email") ?? ""
    }

    private func save() async {
        isLoading = true
        defer { isLoading = false }
        message = nil
        isError = false
        guard let api = state.api else { return }
        guard !email.isEmpty else { message = "请填写邮箱"; isError = true; return }
        if !password.isEmpty {
            guard password.count >= 6, password.count <= 16, password == confirm else {
                message = "新密码需 6-16 位且两次一致"; isError = true; return
            }
        }
        // 刷新 token（一次性）
        if let d = try? await api.getRaw(path: "general/profile/index"),
           let h = String(data: d, encoding: .utf8), let t = ResponseParser.token(from: HTMLUtil.unescape(h)) {
            token = t
        }
        var fields = ["row[nickname]": nickname, "row[email]": email, "__token__": token]
        if !password.isEmpty { fields["row[password]"] = password }
        if let data = try? await api.postForm(path: "general/profile/update", fields: fields) {
            switch ResponseParser.result(from: data) {
            case .success(let m): message = m; password = ""; confirm = ""
            case .failure(let e): message = e.message; isError = true
            }
        } else {
            message = "请求失败"; isError = true
        }
    }
}
