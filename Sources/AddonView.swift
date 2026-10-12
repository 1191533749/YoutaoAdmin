import SwiftUI

struct AddonView: View {
    @EnvironmentObject var state: AppState
    @State private var addons: [Row] = []
    @State private var isLoading = false
    @State private var feedback: Feedback?

    var body: some View {
        Group {
            if isLoading && addons.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if let fb = feedback, !fb.isEmpty {
                        FeedbackRow(feedback: fb)
                    }
                    ForEach(addons) { a in
                        let enabled = a.int("state") == 1
                        HStack(spacing: 12) {
                            Image(systemName: "puzzlepiece.extension.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 9).fill(enabled ? Color.appViolet : Color.gray))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(a.str("title").isEmpty ? a.str("name") : a.str("title"))
                                    .font(.subheadline.weight(.semibold))
                                Text("\(a.str("name")) · v\(a.str("version"))").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(enabled ? "禁用" : "启用") {
                                Task { await toggle(a.str("name"), enable: !enabled) }
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                            .tint(enabled ? .appRed : .appGreen)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
            }
        }
        .navigationTitle("插件管理（共 \(addons.count)）")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        guard let api = state.api else { return }
        guard let data = try? await api.getRaw(path: "addon/index"),
              let raw = String(data: data, encoding: .utf8) else {
            feedback = Feedback.failure("加载失败"); return
        }
        let html = HTMLUtil.unescape(raw)
        guard let arr = HTMLUtil.jsonArray(html, key: "addons") else {
            feedback = Feedback.failure("未解析到插件列表"); return
        }
        addons = arr.enumerated().map { (i, dict) in Row(id: i + 1, dict: dict) }
    }

    private func toggle(_ name: String, enable: Bool) async {
        guard !name.isEmpty, let api = state.api else { return }
        let fields = ["name": name, "action": enable ? "enable" : "disable", "force": "0"]
        if let data = try? await api.postForm(path: "addon/state", fields: fields) {
            switch ResponseParser.result(from: data) {
            case .success(let m): feedback = Feedback.success(m)
            case .failure(let e): feedback = Feedback.failure(e.message)
            }
            await load()
        }
    }
}
