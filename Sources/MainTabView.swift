import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("概览", systemImage: "square.grid.2x2") }
            KamiView()
                .tabItem { Label("卡密", systemImage: "key") }
            BlackView()
                .tabItem { Label("黑名单", systemImage: "nosign") }
            MonitorView()
                .tabItem { Label("监控", systemImage: "exclamationmark.triangle") }
            CategoryView()
                .tabItem { Label("分类", systemImage: "square.stack.3d.up") }
            ConfigView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var counts: [String: Int] = [:]
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red).font(.footnote).padding(.top)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "卡密总数", value: counts["kami"] ?? -1, color: .blue)
                    StatCard(title: "黑名单", value: counts["black"] ?? -1, color: .red)
                    StatCard(title: "异常监控", value: counts["monitor"] ?? -1, color: .orange)
                    StatCard(title: "软件源App", value: counts["category"] ?? -1, color: .green)
                }
                .padding()
            }
            .navigationTitle("概览")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { state.logout() } label: { Image(systemName: "rectangle.portrait.and.arrow.right") }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        errorMessage = nil
        guard let api = state.api else { return }
        var result: [String: Int] = [:]
        var failed = false
        for (key, path) in [("kami", "kami/index?limit=1"),
                            ("black", "black/index?limit=1"),
                            ("monitor", "monitor/index?limit=1"),
                            ("category", "category/index?limit=1")] {
            if let data = try? await api.getRaw(path: path),
               let list = ResponseParser.list(from: data) {
                result[key] = list.total
            } else {
                result[key] = -1
                failed = true
            }
        }
        if failed { errorMessage = "部分数据加载失败（可能是会话过期），请下拉刷新或退出重登" }
        counts = result
    }
}

struct StatCard: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value >= 0 ? "\(value)" : "—").font(.system(size: 34, weight: .bold))
            Text(title).font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.12)))
    }
}
