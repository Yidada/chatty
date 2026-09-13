import Foundation

public enum APIError: Error, Equatable, LocalizedError {
    case http(Int), invalidURL, invalidCredential, oversizedFile, unsafeFile
    public var errorDescription: String? {
        switch self {
        case .http(401): "登录已失效，请重新登录。"
        case .http(403): "你暂时没有访问或修改权限。"
        case .http(404): "资源已不存在，请刷新。"
        case .http(409): "内容或执行状态已更新，请重新读取后核对。"
        case .http(429): "请求过于频繁，请稍后重试。"
        case .http(let status) where (400..<500).contains(status): "请求未通过，请检查输入后重试。"
        case .http(let status): "服务暂时不可用（HTTP \(status)），请稍后重试。"
        case .invalidURL: "无法安全地打开这个地址。"
        case .invalidCredential: "登录响应无效，请重新登录。"
        case .oversizedFile: "文件超过 20 MB，暂时无法处理。"
        case .unsafeFile: "无法读取这个文件，请重新选择。"
        }
    }
}

/// Each instance captures one immutable credential and workspace. Invalidating
/// it cancels all requests; caller generations discard any already-returned data.
public final class APIClient: @unchecked Sendable {
    public static let maximumFileBytes = 20 * 1024 * 1024
    public let baseURL: URL
    public let token: String?
    public let workspace: String?
    let session: URLSession

    public init(baseURL: URL, token: String? = nil, workspace: String? = nil, session: URLSession? = nil) {
        self.baseURL = baseURL; self.token = token; self.workspace = workspace
        self.session = session ?? Self.makeSession()
    }
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 25; config.timeoutIntervalForResource = 90
        return URLSession(configuration: config, delegate: RejectRedirects(), delegateQueue: nil)
    }
    public func invalidate() { session.invalidateAndCancel() }
    public static func segment(_ id: String) -> String {
        id.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-_"))) ?? ""
    }
    public func sameOrigin(_ url: URL) -> Bool {
        url.scheme?.lowercased() == baseURL.scheme?.lowercased() && url.host?.lowercased() == baseURL.host?.lowercased() && (url.port ?? (url.scheme == "https" ? 443 : 80)) == (baseURL.port ?? (baseURL.scheme == "https" ? 443 : 80))
    }
    public func requestURL(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        guard path.hasPrefix("/"), !path.hasPrefix("//"), var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        parts.percentEncodedPath = path; parts.queryItems = query.isEmpty ? nil : query
        guard let url = parts.url, sameOrigin(url) else { throw APIError.invalidURL }
        return url
    }
    public func request(for url: URL, method: String = "GET") throws -> URLRequest {
        guard url.user == nil, url.password == nil, url.fragment == nil,
              url.scheme == "https" || (sameOrigin(url) && url.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(url.host ?? "")) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        if sameOrigin(url) && url.path.hasPrefix("/api/") {
            if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            if let workspace { request.setValue(workspace, forHTTPHeaderField: "X-Workspace-Slug") }
        }
        return request
    }
    public func data(_ path: String, method: String = "GET", body: [String: JSONValue]? = nil, query: [URLQueryItem] = []) async throws -> Data {
        var request = try request(for: requestURL(path, query: query), method: method)
        if let body { request.httpBody = try JSONEncoder().encode(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: request)
        try Self.check(response); try Task.checkCancellation()
        return data
    }
    public func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try Contracts.decode(T.self, from: await data(path, query: query))
    }
    public func write<T: Decodable & Sendable>(_ path: String, method: String = "POST", body: [String: JSONValue], query: [URLQueryItem] = []) async throws -> T {
        try Contracts.decode(T.self, from: await data(path, method: method, body: body, query: query))
    }
    static func check(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw APIError.http((response as? HTTPURLResponse)?.statusCode ?? 0) }
    }
    public func upload(data: Data, filename: String, contentType: String) async throws -> Attachment {
        guard data.count <= Self.maximumFileBytes else { throw APIError.oversizedFile }
        let boundary = "Chatty-" + UUID().uuidString
        let safeName = URL(fileURLWithPath: filename).lastPathComponent.replacingOccurrences(of: "\"", with: "_").replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
        let safeType = contentType.contains("\n") || contentType.contains("\r") ? "application/octet-stream" : contentType
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(safeName)\"\r\nContent-Type: \(safeType)\r\n\r\n".utf8)
        body.append(data); body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request = try request(for: requestURL("/api/upload-file"), method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let (reply, response) = try await session.upload(for: request, from: body)
        try Self.check(response); try Task.checkCancellation()
        return try Contracts.decode(Attachment.self, from: reply)
    }
    /// Streaming read with a hard cap, including unknown Content-Length bodies.
    public func download(_ url: URL) async throws -> Data {
        let (bytes, response) = try await session.bytes(for: request(for: url))
        try Self.check(response)
        guard response.expectedContentLength <= Self.maximumFileBytes else { throw APIError.oversizedFile }
        var result = Data()
        for try await byte in bytes {
            guard result.count < Self.maximumFileBytes else { throw APIError.oversizedFile }
            result.append(byte)
        }
        try Task.checkCancellation(); return result
    }
    public func attachmentData(_ attachment: Attachment) async throws -> (Attachment, Data) {
        for attempt in 0...1 {
            let fresh: Attachment = try await get("/api/attachments/\(Self.segment(attachment.id))")
            guard (fresh.sizeBytes ?? 0) <= Self.maximumFileBytes else { throw APIError.oversizedFile }
            let fallback = try requestURL("/api/attachments/\(Self.segment(fresh.id))/download")
            let url = fresh.downloadUrl.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL } ?? fallback
            do { return (fresh, try await download(url)) }
            catch APIError.http(let status) where attempt == 0 && !sameOrigin(url) && [401,403,404,410].contains(status) { continue }
        }
        throw APIError.http(410)
    }
}

private final class RejectRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? { nil }
}
