import Foundation

// 一行列表数据的轻量封装：字段按需取值，避免 Codable 对多模块字段差异敏感
struct Row: Identifiable {
    let id: Int
    let dict: [String: Any]

    func str(_ key: String) -> String {
        if let s = dict[key] as? String, !s.isEmpty { return s }
        if let n = dict[key] as? NSNumber { return n.stringValue }
        return ""
    }
    func int(_ key: String) -> Int {
        if let n = dict[key] as? NSNumber { return n.intValue }
        return 0
    }
}

struct ListResult {
    let total: Int
    let rows: [Row]
}

enum Labels {
    static let kamiType: [Int: String] = [4: "日卡", 5: "周卡", 1: "月卡", 2: "季卡", 3: "年卡"]
    static let categoryType: [Int: String] = [1: "应用", 2: "游戏", 3: "影音", 4: "工具", 5: "插件"]
    static let controlOptions: [(value: Int, label: String)] = [
        (0, "关闭公告"),
        (1, "打开公告"),
        (2, "打开公告+闪退"),
        (3, "打开公告+跳转官网"),
        (4, "打开公告+跳转官网+闪退")
    ]
    static func kamiLabel(_ t: Int) -> String { kamiType[t] ?? "类型\(t)" }
    static func categoryLabel(_ t: Int) -> String { categoryType[t] ?? "类型\(t)" }
    static func controlLabel(_ v: Int) -> String {
        controlOptions.first(where: { $0.value == v })?.label ?? "选项\(v)"
    }
}
