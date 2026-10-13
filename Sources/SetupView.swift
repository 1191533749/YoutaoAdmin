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
            ScrollView {
                VStack(spacing: 20) {
                    // 顶部品牌
                    VStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 40)).foregroundColor(.white)
                        Text("优淘软件源").font(.title.bold()).foregroundColor(.white)
                        Text("连接你的软件源管理后台").font(.caption).foregroundColor(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient.app))
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        FieldCard(icon: "globe", title: "站点地址") {
                            TextField("https://r.ytw.asia", text: $siteRoot)
                                .keyboardType(.URL).autocapitalization(.none).disableAutocorrection(true)
                        }
                        FieldCard(icon: "doc.badge.gearshape", title: "后台入口文件名") {
                            TextField("FRKToHDckx.php", text: $adminEntry)
                                .autocapitalization(.none).disableAutocorrection(true)
                        }
                        FieldCard(icon: "person", title: "管理员账号") {
                            TextField("admin", text: $username)
                                .autocapitalization(.none).disableAutocorrection(true)
                        }
                        FieldCard(icon: "lock", title: "管理员密码") {
                            SecureField("密码", text: $password)
                        }
                    }
                    .padding(.horizontal)

                    if let errorMessage = errorMessage {
                        Text(errorMessage).font(.footnote).foregroundColor(.appRed)
                            .padding(.horizontal)
                    }

                    Button("保存并去登录") { save() }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal)

                    Text("账号密码只保存在本机钥匙串，不会上传。")
                        .font(.caption2).foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    private func save() {
        let root = siteRoot.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !root.isEmpty else { errorMessage = "请填写站点地址"; return }
        let entry = adminEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        let cfg = ServerConfig(siteRoot: root,
                               adminEntry: entry.isEmpty ? "FRKToHDckx.php" : entry,
                               username: username,
                               password: password)
        state.saveConfig(cfg)
    }
}

struct FieldCard<Content: View>: View {
    let icon: String
    let title: String
    let content: Content

    init(icon: String, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.appAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundColor(.secondary)
                content
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(UIColor.secondarySystemGroupedBackground)))
    }
}
