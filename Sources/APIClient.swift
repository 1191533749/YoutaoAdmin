import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class APIClient {
    let config: ServerConfig

    init(config: ServerConfig) {
        self.config = config
    }

    var adminBase: String {
        let root = config.siteRoot.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let entry = config.adminEntry.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return "\(root)/\(entry)"
    }

    private static func formEncode(_ s: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    private func request(path: String, method: String, formFields: [String: String]?) async throws -> Data {
        let urlString = path.hasPrefix("http") ? path : "\(adminBase)/\(path)"
        guard let url = URL(string: urlString) else {
            throw APIError(message: "URL 无效：\(urlString)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        if let fields = formFields {
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let body = fields.map { k, v in
                "\(Self.formEncode(k))=\(Self.formEncode(v))"
            }.joined(separator: "&")
            req.httpBody = body.data(using: .utf8)
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    func getRaw(path: String) async throws -> Data {
        try await request(path: path, method: "GET", formFields: nil)
    }

    func getAbsolute(_ url: String) async throws -> Data {
        try await request(path: url, method: "GET", formFields: nil)
    }

    func postForm(path: String, fields: [String: String]) async throws -> Data {
        try await request(path: path, method: "POST", formFields: fields)
    }
}

enum ResponseParser {
    static func jsonObject(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
    }

    static func list(from data: Data) -> ListResult? {
        guard let obj = jsonObject(data),
              let rowsArr = obj["rows"] as? [[String: Any]] else { return nil }
        let total = (obj["total"] as? NSNumber)?.intValue ?? rowsArr.count
        let rows = rowsArr.map { raw in
            let id = (raw["id"] as? NSNumber)?.intValue ?? 0
            return Row(id: id, dict: raw)
        }
        return ListResult(total: total, rows: rows)
    }

    static func result(from data: Data) -> Result<String, APIError> {
        guard let obj = jsonObject(data) else {
            return .failure(APIError(message: "响应不是有效 JSON"))
        }
        if let code = obj["code"] as? NSNumber, code.intValue == 1 {
            let msg = obj["msg"] as? String ?? "操作成功"
            return .success(msg)
        }
        let msg = obj["msg"] as? String ?? "操作失败"
        return .failure(APIError(message: msg))
    }

    static func isLoggedIn(_ data: Data) -> Bool {
        guard let obj = jsonObject(data) else { return false }
        return obj["rows"] != nil || obj["total"] != nil
    }

    // 从 HTML 里解析隐藏 __token__ 字段
    static func token(from html: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: "name=\"__token__\" value=\"([^\"]+)\"") else { return nil }
        let ns = html as NSString
        let m = r.firstMatch(in: html, range: NSRange(location: 0, length: ns.length))
        if let m = m, m.numberOfRanges > 1 {
            return ns.substring(with: m.range(at: 1))
        }
        return nil
    }

    // 从登录页 HTML 解析验证码图片 URL
    static func captchaURL(from html: String) -> String? {
        guard let r = try? NSRegularExpression(pattern: "<img[^>]*src=\"([^\"]+)\"[^>]*width=\"100\"") else { return nil }
        let ns = html as NSString
        if let m = r.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 {
            return ns.substring(with: m.range(at: 1))
        }
        // 兜底：取任意 index.php?s=/captcha 链接
        guard let r2 = try? NSRegularExpression(pattern: "src=\"([^\"]*index\.php\?s=/captcha[^\"]*)\"") else { return nil }
        if let m = r2.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 {
            return ns.substring(with: m.range(at: 1))
        }
        return nil
    }

    static func decodeHTML(_ s: String) -> String {
        var out = s
        out = out.replacingOccurrences(of: "&amp;", with: "&")
        out = out.replacingOccurrences(of: "&lt;", with: "<")
        out = out.replacingOccurrences(of: "&gt;", with: ">")
        out = out.replacingOccurrences(of: "&quot;", with: "\"")
        out = out.replacingOccurrences(of: "&#039;", with: "'")
        return out
    }
}
