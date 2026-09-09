import Foundation
import XCTest
import ChattyCore
@testable import ChattyFixtureSupport

private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try XCTUnwrap(Self.handler)(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private final class Requests: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    func add(_ request: URLRequest) { lock.lock(); defer { lock.unlock() }; requests.append(request) }
    var values: [URLRequest] { lock.lock(); defer { lock.unlock() }; return requests }
}

@MainActor
final class FixtureClientTests: XCTestCase {
    private func client() -> FixtureClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return FixtureClient(session: URLSession(configuration: config))
    }

    func testFixtureReadsOnlyLoopbackWithSyntheticScope() async throws {
        let requests = Requests()
        StubProtocol.handler = { request in
            requests.add(request)
            return (200, Data("{\"projects\":[],\"total\":0}".utf8))
        }
        let result = try await client().projects()
        XCTAssertEqual(result.total, 0)
        let request = try XCTUnwrap(requests.values.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8765/api/projects")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Workspace-Slug"), "fixture")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-device-fixture-token")
    }

    func testServerFailureDoesNotRetryOrDecodeAsSuccess() async throws {
        let requests = Requests()
        StubProtocol.handler = { request in requests.add(request); return (503, Data("{}".utf8)) }
        do { _ = try await client().projects(); XCTFail("503 must fail") }
        catch { XCTAssertEqual(error as? FixtureError, .http(503)) }
        XCTAssertEqual(requests.values.count, 1)
    }

    func testMalformedContractIsReported() async throws {
        StubProtocol.handler = { _ in (200, Data("{\"projects\":\"wrong\"}".utf8)) }
        do { _ = try await client().projects(); XCTFail("Malformed data must fail") }
        catch { XCTAssertTrue(error is DecodingError) }
    }

    func testTransportCancellationIsPreserved() async throws {
        StubProtocol.handler = { _ in throw URLError(.cancelled) }
        do { _ = try await client().projects(); XCTFail("Cancellation must propagate") }
        catch { XCTAssertEqual((error as? URLError)?.code, .cancelled) }
    }
}
