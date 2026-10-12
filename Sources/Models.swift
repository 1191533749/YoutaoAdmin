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
        if let s = dict[key] as? String, let v = Int(s) { return v }
        return 0
    }
    /// 把所有标量字段拍平成 [String: String]，用于编辑表单回填
    var stringDict: [String: String] {
        var out: [String: String] = [:]
        for (k, v) in dict {
            if let s = v as? String { out[k] = s }
            else if let n = v as? NSNumber { out[k] = n.stringValue }
        }
        return out
    }

    func nested(_ key: String, _ sub: String) -> String {
        guard let d = dict[key] as? [String: Any] else { return "" }
        if let s = d[sub] as? String, !s.isEmpty { return s }
        if let n = d[sub] as? NSNumber { return n.stringValue }
        return ""
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
    static func userStatusLabel(_ s: String) -> String { s == "hidden" ? "隐藏" : "正常" }
    static func adminStatusLabel(_ s: String) -> String { s == "hidden" ? "禁用" : "正常" }
    static func genderLabel(_ g: Int) -> String { g == 1 ? "男" : (g == 0 ? "女" : "未知") }
}

import Foundation

// 时间戳格式化（部分模型无 *_text 字段，需自行转）
enum DateUtil {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
    static func format(_ s: String) -> String {
        guard let ts = Double(s), ts > 0 else { return s }
        return formatter.string(from: Date(timeIntervalSince1970: ts))
    }
}
