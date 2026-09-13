import Foundation

/// JSON is retained at the extension boundary; recognized fields are validated by their consumer.
public enum Wire: Codable, Hashable, Sendable {
    case object([String: Wire]), array([Wire]), string(String), number(Double), bool(Bool), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([Wire].self) { self = .array(v) }
        else { self = .object(try c.decode([String: Wire].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    public subscript(_ key: String) -> Wire { if case .object(let o) = self { return o[key] ?? .null }; return .null }
    public var string: String? { if case .string(let s) = self { return s }; return nil }
    public var text: String { string ?? "" }
    public var int: Int? { if case .number(let n) = self, n.isFinite, n.rounded() == n, n >= Double(Int.min), n < Double(Int.max) { return Int(n) }; return nil }
    public var bool: Bool { if case .bool(let v) = self { return v }; return false }
    public var array: [Wire] { if case .array(let a) = self { return a }; return [] }
    public var object: [String: Wire] { if case .object(let o) = self { return o }; return [:] }
    public func data() throws -> Data { try JSONEncoder().encode(self) }
    public static func decode(_ data: Data) throws -> Wire { try JSONDecoder().decode(Wire.self, from: data) }
    public static func str(_ s: String) -> Wire { .string(s) }
}

public enum NextError: Error, LocalizedError, Equatable, Sendable {
    case invalidOrigin, authentication, transport(Int), protocolMismatch(String), server(String, String), storage, disconnected
    public var errorDescription: String? {
        switch self {
        case .invalidOrigin: "请输入 Mac 的完整 HTTPS 连接地址，不要包含额外路径。"
        case .authentication: "连接凭据已失效，请重新连接这台 Mac。"
        case .transport(let code): "连接失败（HTTP \(code)）。请检查 Mac 和 Tailscale。"
        case .protocolMismatch(let item): "当前服务数据暂不兼容：\(item)"
        case .server(let code, let message): "\(message)（\(code)）"
        case .storage: "草稿保存失败，内容仍保留在输入框中。请解锁设备后重试。"
        case .disconnected: "连接已中断，正在恢复。"
        }
    }
}

public struct DSHOrigin: Codable, Hashable, Sendable {
    public let url: URL
    public var key: String { url.absoluteString }
    public init(_ source: String, allowLoopbackHTTP: Bool = false) throws {
        guard var c = URLComponents(string: source.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = c.host?.lowercased(), !host.isEmpty, c.user == nil, c.password == nil,
              c.fragment == nil, c.path.isEmpty || c.path == "/",
              c.queryItems?.allSatisfy({ $0.name == "token" }) ?? true,
              c.queryItems?.count ?? 0 <= 1,
              c.scheme == "https" || (allowLoopbackHTTP && c.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)) else { throw NextError.invalidOrigin }
        c.host = host; c.path = "/"; c.query = nil
        guard let url = c.url else { throw NextError.invalidOrigin }; self.url = url
    }
    public func matches(_ other: URL) -> Bool {
        other.scheme == url.scheme && other.host?.lowercased() == url.host?.lowercased() && (other.port ?? (other.scheme == "https" ? 443 : 80)) == (url.port ?? (url.scheme == "https" ? 443 : 80)) && other.user == nil && other.password == nil
    }
    public func endpoint(_ name: String) -> URL { url.appendingPathComponent("api/" + name) }
}

public struct DSHCredential: Codable, Sendable {
    public let origin: DSHOrigin
    public let cookie: String
    public let expires: Date?
    public init(origin: DSHOrigin, cookie: String, expires: Date? = nil) { self.origin = origin; self.cookie = cookie; self.expires = expires }
}
