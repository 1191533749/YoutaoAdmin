import Foundation

// 后台页面 HTML 解析工具（去转义 / 取输入框值 / 取 JS 配置里的 JSON 数组）
enum HTMLUtil {
    /// 后台对手机 UA 会返回反斜杠转义版 HTML，解析前先去反斜杠
    static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "")
    }

    /// 取 <input name="row[key]" ... value="X"> 的 X
    static func inputValue(_ html: String, key: String) -> String? {
        let marker = "name=\"row[" + key + "]\""
        guard let r = html.range(of: marker) else { return nil }
        guard let vr = html[r.upperBound...].range(of: "value=\"") else { return nil }
        let vs = vr.upperBound
        guard let ve = html[vs...].firstIndex(of: "\"") else { return nil }
        return String(html[vs..<ve])
    }

    /// 取 JS 配置里的 JSON 数组，如 "addons":[...]
    static func jsonArray(_ html: String, key: String) -> [[String: Any]]? {
        guard let r = html.range(of: "\"\(key)\":[") else { return nil }
        let lb = html.index(before: r.upperBound)   // '['
        var i = r.upperBound
        var depth = 1
        var inStr = false
        var esc = false
        var end = html.endIndex
        while i < html.endIndex {
            let c = html[i]
            if esc { esc = false }
            else if c == "\\" { esc = true }
            else if c == "\"" { inStr.toggle() }
            else if !inStr {
                if c == "[" { depth += 1 }
                else if c == "]" {
                    depth -= 1
                    if depth == 0 { end = html.index(after: i); break }
                }
            }
            i = html.index(after: i)
        }
        let json = String(html[lb..<end])
        guard let data = json.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return arr
    }
}
