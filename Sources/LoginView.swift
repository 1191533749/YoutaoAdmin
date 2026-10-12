import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject var state: AppState
    @State private var username = ""
    @State private var password = ""
    @State private var captchaText = ""
    @State private var captchaImage: UIImage?
    @State private var token = ""
    @State private var captchaBaseURL = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 40)).foregroundColor(.white)
                        Text("优淘后台").font(.title.bold()).foregroundColor(.white)
                        Text(state.config?.siteRoot ?? "").font(.caption).foregroundColor(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient.app))
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        FieldCard(icon: "person", title: "账号") {
                            TextField("账号", text: $username)
                                .autocapitalization(.none).disableAutocorrection(true)
                        }
                        FieldCard(icon: "lock", title: "密码") {
                            SecureField("密码", text: $password)
                        }
                        // 验证码
                        HStack(spacing: 12) {
                            Image(systemName: "shield")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Color.appViolet))
                            TextField("验证码", text: $captchaText)
                                .keyboardType(.asciiCapable)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                            if let img = captchaImage {
                                Image(uiImage: img)
                                    .resizable().scaledToFit()
                                    .frame(width: 96, height: 34)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .onTapGesture { Task { await refreshCaptcha() } }
                            } else {
                                Text("点击刷新")
                                    .font(.caption2).foregroundColor(.appAccent)
                                    .frame(width: 96, height: 34)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.appAccent.opacity(0.12)))
                                    .onTapGesture { Task { await refreshCaptcha() } }
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground)))
                    }
                    .padding(.horizontal)

                    if let errorMessage = errorMessage {
                        Text(errorMessage).font(.footnote).foregroundColor(.appRed)
                            .padding(.horizontal)
                    }

                    Button {
                        Task { await doLogin() }
                    } label: {
                        if isLoading { ProgressView().tint(.white) } else { Text("登录").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading)
                    .padding(.horizontal)

                    Button("重置服务器设置") { state.reset() }
                        .font(.footnote).foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                username = state.config?.username ?? ""
                password = state.config?.password ?? ""
                Task { await loadLoginPage() }
            }
        }
    }

    private func loadLoginPage() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        do {
            let html = String(data: try await api.getRaw(path: "index/login"), encoding: .utf8) ?? ""
            token = ResponseParser.token(from: html) ?? ""
            if let src = ResponseParser.captchaURL(from: html) {
                let full = resolveCaptcha(src)
                captchaBaseURL = full
                await fetchCaptcha(full)
            }
        } catch {
            errorMessage = "加载登录页失败：\(error.localizedDescription)"
        }
    }

    private func resolveCaptcha(_ src: String) -> String {
        if src.hasPrefix("http") { return src }
        let root = (state.config?.siteRoot ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if src.hasPrefix("/") { return "\(root)\(src)" }
        return "\(root)/\(src)"
    }

    private func refreshCaptcha() async {
        guard !captchaBaseURL.isEmpty else { return }
        let url = captchaBaseURL + "&r=\(Int.random(in: 100000...999999))"
        await fetchCaptcha(url)
    }

    private func fetchCaptcha(_ url: String) async {
        guard let api = state.api else { return }
        do {
            let data = try await api.getAbsolute(url)
            captchaImage = UIImage(data: data)
        } catch {
            captchaImage = nil
        }
    }

    private func doLogin() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        guard let api = state.api else { return }
        let fields = [
            "username": username,
            "password": password,
            "captcha": captchaText,
            "__token__": token,
            "keeplogin": "1"
        ]
        do {
            let data = try await api.postForm(path: "index/login", fields: fields)
            switch ResponseParser.result(from: data) {
            case .success:
                state.markLoggedIn()
            case .failure(let e):
                errorMessage = e.message
                captchaText = ""
                await loadLoginPage()
            }
        } catch {
            errorMessage = "登录失败：\(error.localizedDescription)"
        }
    }
}
