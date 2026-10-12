import SwiftUI

struct SetupView: View {
    @EnvironmentObject var state: AppState
    @State private var siteRoot = "https://r.ytw.asia"
    @State private var adminEntry = "FRKToHDckx.php"
    @State private var username = "admin"
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("服务器设置")) {
                    TextField("站点地址", text: $siteRoot)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("后台入口文件名", text: $adminEntry)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("管理员账号", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("管理员密码", text: $password)
                }
                if let errorMessage = errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red).font(.footnote) }
                }
                Section {
                    Button("保存并去登录") { save() }
                }
                Section(footer: Text("账号密码只保存在本机钥匙串，不会上传到任何地方。")) {
                    EmptyView()
                }
            }
            .navigationTitle("优淘后台")
        }
    }

    private func save() {
        let root = siteRoot.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !root.isEmpty else {
            errorMessage = "请填写站点地址"
            return
        }
        let entry = adminEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        let cfg = ServerConfig(siteRoot: root,
                               adminEntry: entry.isEmpty ? "FRKToHDckx.php" : entry,
                               username: username,
                               password: password)
        state.saveConfig(cfg)
    }
}
