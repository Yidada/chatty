import Foundation

private final class NoRedirect: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor public final class DSHClient {
    public let credential: DSHCredential
    private let session: URLSession
    private let redirect = NoRedirect()
    private var socket: URLSessionWebSocketTask?
    private var reader: Task<Void, Never>?
    private var streams: [String: AsyncThrowingStream<Wire, Error>.Continuation] = [:]
    private var generation = 0
    public init(credential: DSHCredential, configuration: URLSessionConfiguration = .ephemeral) {
        self.credential = credential
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCache = nil; configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration, delegate: redirect, delegateQueue: nil)
    }
    public static func pair(address: String, token: String, allowLoopbackHTTP: Bool = false, configuration: URLSessionConfiguration = .ephemeral) async throws -> DSHCredential {
        let origin = try DSHOrigin(address, allowLoopbackHTTP: allowLoopbackHTTP)
        let supplied = token.isEmpty ? URLComponents(string: address)?.queryItems?.first(where: { $0.name == "token" })?.value ?? "" : token
        guard !supplied.isEmpty else { throw NextError.authentication }
        var c = URLComponents(url: origin.url, resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "token", value: supplied)]
        let config = configuration
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false; config.urlCache = nil; config.timeoutIntervalForRequest = 20
        let client = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { client.invalidateAndCancel() }
        let (_, response) = try await client.data(from: c.url!)
        guard let r = response as? HTTPURLResponse else { throw NextError.protocolMismatch("配对响应") }
        guard [200, 302, 303].contains(r.statusCode) else { throw r.statusCode == 401 ? NextError.authentication : NextError.transport(r.statusCode) }
        if let location = r.value(forHTTPHeaderField: "Location") {
            guard let next = URL(string: location, relativeTo: origin.url)?.absoluteURL, origin.matches(next), next.path == "/", next.query == nil, next.fragment == nil else { throw NextError.invalidOrigin }
        }
        var headers: [String: String] = [:]
        for (k, v) in r.allHeaderFields { if let k = k as? String, let v = v as? String { headers[k] = v } }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: origin.url).filter { cookie in
            cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")) == origin.url.host && cookie.path == "/" && cookie.name.hasPrefix("dsh-auth-")
        }
        guard !cookies.isEmpty else { throw NextError.authentication }
        return DSHCredential(origin: origin, cookie: HTTPCookie.requestHeaderFields(with: cookies)["Cookie"] ?? "", expires: cookies.compactMap(\.expiresDate).min())
    }
    public func rpc(_ endpoint: String, args: Wire = .object([:])) async throws -> Wire {
        let id = UUID().uuidString
        let body: Wire = .object(["type": .str("client-request"), "rpcId": .str(id), "method": .str(endpoint), "payload": .object(["args": args])])
        var request = try request(credential.origin.endpoint(endpoint)); request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try body.data()
        let (data, response) = try await session.data(for: request)
        try check(response)
        let reply = try Wire.decode(data)
        guard reply["type"].text == "server-response", reply["rpcId"].text == id else { throw NextError.protocolMismatch("RPC 回执身份") }
        let result = reply["result"]
        guard result["ok"].bool else { throw remoteError(result["error"]) }
        return result["value"]
    }
    public func command(_ endpoint: String, _ value: Wire) async throws -> Wire { try await rpc(endpoint, args: .object(["request": value])) }
    public func upload(_ data: Data, name: String, sessionID: String) async throws -> Wire {
        var c = URLComponents(url: credential.origin.endpoint("session/uploadFileBinary"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "sessionId", value: sessionID), .init(name: "name", value: name)]
        var request = try request(c.url!); request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.upload(for: request, from: data); try check(response)
        let result = try Wire.decode(data); guard result["ok"].bool else { throw remoteError(result["error"]) }; return result["value"]
    }
    public func stream(_ endpoint: String, args: Wire = .object([:])) async throws -> AsyncThrowingStream<Wire, Error> {
        if socket == nil { try connectSocket() }
        let id = UUID().uuidString, g = generation
        let (stream, continuation) = AsyncThrowingStream<Wire, Error>.makeStream()
        streams[id] = continuation
        continuation.onTermination = { [weak self] _ in Task { @MainActor in await self?.closeStream(id, generation: g) } }
        do { try await send(.object(["type": .str("open"), "streamId": .str(id), "endpoint": .str(endpoint), "payload": .object(["args": args])])) }
        catch { streams.removeValue(forKey: id)?.finish(throwing: error); throw error }
        return stream
    }
    public func disconnect() { generation += 1; reader?.cancel(); reader = nil; socket?.cancel(with: .goingAway, reason: nil); socket = nil; let old = streams; streams.removeAll(); for c in old.values { c.finish(throwing: NextError.disconnected) } }
    public func shutdown() { disconnect(); session.invalidateAndCancel() }
    private func request(_ url: URL) throws -> URLRequest {
        guard credential.origin.matches(url) else { throw NextError.invalidOrigin }
        guard credential.expires.map({ $0 > Date() }) ?? true else { throw NextError.authentication }
        var r = URLRequest(url: url); r.httpShouldHandleCookies = false
        r.setValue(credential.cookie, forHTTPHeaderField: "Cookie"); r.setValue(credential.origin.url.absoluteString.dropLast().description, forHTTPHeaderField: "Origin")
        return r
    }
    private func connectSocket() throws {
        var req = try request(credential.origin.endpoint("remote.mux"))
        var c = URLComponents(url: req.url!, resolvingAgainstBaseURL: false)!; c.scheme = c.scheme == "https" ? "wss" : "ws"; req.url = c.url
        let ws = session.webSocketTask(with: req); ws.maximumMessageSize = 16 * 1024 * 1024; socket = ws; ws.resume()
        generation += 1; let g = generation
        reader = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    let message = try await ws.receive()
                    guard let self, self.generation == g else { return }
                    let data: Data
                    switch message { case .data(let value): data = value; case .string(let value): data = Data(value.utf8); @unknown default: throw NextError.protocolMismatch("WebSocket 帧") }
                    let frame = try Wire.decode(data); let id = frame["streamId"].text
                    switch frame["type"].text {
                    case "item": self.streams[id]?.yield(frame["value"])
                    case "error": self.streams.removeValue(forKey: id)?.finish(throwing: self.remoteError(frame["error"]))
                    case "end": self.streams.removeValue(forKey: id)?.finish()
                    default: throw NextError.protocolMismatch("流类型")
                    }
                }
            } catch {
                guard let self, self.generation == g else { return }
                self.socket = nil; let old = self.streams; self.streams.removeAll(); for c in old.values { c.finish(throwing: error) }
            }
        }
    }
    private func send(_ frame: Wire) async throws { guard let socket else { throw NextError.disconnected }; try await socket.send(.string(String(decoding: try frame.data(), as: UTF8.self))) }
    private func closeStream(_ id: String, generation g: Int) async { guard g == generation, streams.removeValue(forKey: id) != nil else { return }; try? await send(.object(["type": .str("cancel"), "streamId": .str(id)])) }
    private func check(_ response: URLResponse) throws {
        guard let r = response as? HTTPURLResponse else { throw NextError.protocolMismatch("HTTP 响应") }
        guard r.statusCode == 200 else { throw r.statusCode == 401 ? NextError.authentication : NextError.transport(r.statusCode) }
    }
    private func remoteError(_ wire: Wire) -> NextError { .server(wire["code"].string ?? "unknown", wire["message"].string ?? "请求未完成") }
}
