import Foundation
import Testing
import Synchronization
@testable import ChattyNextCore

private final class ProtocolStub: URLProtocol, @unchecked Sendable {
    struct Reply: Sendable { var status = 200; var headers: [String: String] = [:]; var body: Wire = .null; var echoRPC = false }
    static let replies = Mutex<[String: Reply]>([:])
    static let requests = Mutex<[String: URLRequest]>([:])
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let key = request.url!.absoluteString
        Self.requests.withLock { $0[key] = request }
        guard let reply = Self.replies.withLock({ $0[key] }) else { client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return }
        var body = reply.body
        if reply.echoRPC {
            var data = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }; var bytes = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable { let count = stream.read(&bytes, maxLength: bytes.count); if count <= 0 { break }; data.append(contentsOf: bytes.prefix(count)) }
            }
            if let value = try? Wire.decode(data) { body = .object(["type": .str("server-response"), "rpcId": value["rpcId"], "result": .object(["ok": .bool(true), "value": value["payload"]["args"]])]) }
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: (try? body.data()) ?? Data()); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
    static func configuration() -> URLSessionConfiguration { let value = URLSessionConfiguration.ephemeral; value.protocolClasses = [ProtocolStub.self]; return value }
}

@Test @MainActor func pairingPinsTLSAuthorityEvenWhenProxyOmitsSecureCookieAttribute() async throws {
    let base = "https://pair.invalid:8443"
    ProtocolStub.replies.withLock { $0[base + "/?token=synthetic"] = .init(status: 303, headers: ["Location": "/", "Set-Cookie": "dsh-auth-test=synthetic; Path=/; HttpOnly; SameSite=Strict; Max-Age=3600"]) }
    let value = try await DSHClient.pair(address: base, token: "synthetic", configuration: ProtocolStub.configuration())
    #expect(value.origin.key == base + "/"); #expect(value.cookie.contains("dsh-auth-test=synthetic"))
    #expect(!value.origin.matches(URL(string: "http://pair.invalid:8443")!))
    #expect(!value.origin.matches(URL(string: "https://pair.invalid")!))
}
@Test @MainActor func pairingRejectsRedirectToAnotherAuthority() async throws {
    let base = "https://redirect.invalid:8443"
    ProtocolStub.replies.withLock { $0[base + "/?token=synthetic"] = .init(status: 303, headers: ["Location": "https://other.invalid/", "Set-Cookie": "dsh-auth-test=synthetic; Path=/; Secure"]) }
    await #expect(throws: NextError.invalidOrigin) { try await DSHClient.pair(address: base, token: "synthetic", configuration: ProtocolStub.configuration()) }
}
@Test @MainActor func rpcUsesCorrectEnvelopeExplicitCookieAndCleansToken() async throws {
    let origin = try DSHOrigin("https://rpc.invalid:8443/?token=synthetic"), endpoint = origin.endpoint("session/prompt").absoluteString
    ProtocolStub.replies.withLock { $0[endpoint] = .init(echoRPC: true) }
    let client = DSHClient(credential: .init(origin: origin, cookie: "dsh-auth-test=bound"), configuration: ProtocolStub.configuration()); defer { client.shutdown() }
    let value: Wire = .object(["sessionId": .str("s"), "requestId": .str("unique-intent")])
    #expect(try await client.command("session/prompt", value) == .object(["request": value]))
    let request = ProtocolStub.requests.withLock { $0[endpoint] }
    #expect(request?.value(forHTTPHeaderField: "Cookie") == "dsh-auth-test=bound")
    #expect(request?.value(forHTTPHeaderField: "Origin") == "https://rpc.invalid:8443")
    #expect(request?.url?.query == nil)
}
@Test @MainActor func expiredCredentialCannotReachNetwork() async throws {
    let origin = try DSHOrigin("https://expired.invalid")
    let client = DSHClient(credential: .init(origin: origin, cookie: "expired", expires: Date(timeIntervalSince1970: 1)), configuration: ProtocolStub.configuration()); defer { client.shutdown() }
    await #expect(throws: NextError.authentication) { try await client.rpc("session/list") }
    #expect(ProtocolStub.requests.withLock { $0[origin.endpoint("session/list").absoluteString] } == nil)
}
