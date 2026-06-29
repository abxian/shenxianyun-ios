import Foundation

// 神仙云后端配置与提取码相关工具。
public enum ShenxianyunConfig {
    public static let baseURL = "https://sub.jc116.com"

    public static func singboxURL(_ code: String) -> String {
        let c = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
        return "\(baseURL)/singbox/\(c)"
    }

    public static func payNewURL() -> URL {
        URL(string: "\(baseURL)/pay?action=new")!
    }

    public static func payRenewURL(_ code: String) -> URL {
        let c = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        return URL(string: "\(baseURL)/pay?action=renew&code=\(c)") ?? payNewURL()
    }

    private static let codeKey = "shenxianyun_code"
    public static var savedCode: String {
        get { UserDefaults.standard.string(forKey: codeKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: codeKey) }
    }

    // 调后端 /api/verify/<code> 校验提取码是否有效且未过期。
    public static func verify(_ code: String) async -> (ok: Bool, message: String) {
        guard let url = URL(string: "\(baseURL)/api/verify/\(code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code)") else {
            return (false, "提取码格式不正确")
        }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 10
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                return (false, "服务器无响应，请稍后重试")
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let ok = (json["ok"] as? Bool) ?? false
            return ok ? (true, "") : (false, "提取码无效或已过期")
        } catch {
            return (false, "网络错误：\(error.localizedDescription)")
        }
    }
}
