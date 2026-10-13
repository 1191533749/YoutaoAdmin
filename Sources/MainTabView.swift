import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("概览", systemImage: "square.grid.2x2.fill") }
            KamiView()
                .tabItem { Label("卡密", systemImage: "key.fill") }
            SecurityView()
                .tabItem { Label("安全", systemImage: "shield.fill") }
            CategoryView()
                .tabItem { Label("商品", systemImage: "square.stack.3d.up.fill") }
            SystemView()
                .tabItem { Label("系统", systemImage: "gearshape.fill") }
        }
        .accentColor(.appAccent)
    }
}

// 概览：顶部渐变 + 统计卡片
struct OverviewView: View {
    @EnvironmentObject var state: AppState
    @State private var counts: [String: Int] = [:]
    @State private var isLoading = false

    private var siteRoot: String { state.config?.siteRoot ?? "" }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // 顶部渐变卡片
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("优淘后台").font(.title2.weight(.bold)).foregroundColor(.white)
                            Text(siteRoot).font(.caption).foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        Button {
                            state.logout()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Circle().fill(Color.white.opacity(0.18)))
                        }
                    }
                    HStack(spacing: 6) {
                        StatusBadge(text: "已连接", color: .white)
                            .background(Capsule().fill(Color.white.opacity(0.22)))
                        Text("管理端在线").font(.caption).foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient.app))
                .padding(.horizontal)

                // 统计
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(icon: "key.fill", tint: .appBlue, title: "卡密总数", value: valueText("kami"))
                    StatTile(icon: "nosign", tint: .appRed, title: "黑名单", value: valueText("black"))
                    StatTile(icon: "exclamationmark.triangle.fill", tint: .appOrange, title: "异常监控", value: valueText("monitor"))
                    StatTile(icon: "person.2.fill", tint: .appTeal, title: "会员总数", value: valueText("user"))
                }
                .padding(.horizontal)

                Spacer(minLength: 8)
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if isLoading {
                ProgressView().padding(.trailing, 20).padding(.top, 4)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func valueText(_ key: String) -> String {
        guard let v = counts[key] else { return "—" }
        return v >= 0 ? "\(v)" : "—"
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        var result: [String: Int] = [:]
        for (key, path) in [("kami", "kami/index?limit=1"),
                            ("black", "black/index?limit=1"),
                            ("monitor", "monitor/index?limit=1"),
                            ("user", "user/index?limit=1")] {
            if let data = try? await api.getRaw(path: path),
               let list = ResponseParser.list(from: data) {
                result[key] = list.total
            } else {
                result[key] = -1
            }
        }
        counts = result
    }
}
