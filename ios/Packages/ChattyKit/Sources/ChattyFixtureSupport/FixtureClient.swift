import Foundation
import ChattyCore

public enum FixtureError: Error, Equatable, LocalizedError {
    case http(Int), missingWorkspace, missingMika, missingSession
    public var errorDescription: String? {
        switch self {
        case .http(let status): "测试服务暂时不可用（HTTP \(status)）"
        case .missingWorkspace: "测试工作区为空"
        case .missingMika: "测试工作区中没有 Mika"
        case .missingSession: "测试工作区中没有有效的 Mika 对话"
        }
    }
}

public struct FixtureSnapshot: Sendable {
    public let workspace: Workspace
    public let mika: ChatAgent
    public let messages: MessagePage
    public let projects: ProjectPage
    public let runtimes: [RuntimeDevice]
    public let squads: [Squad]
}

/// This product is linked only by ChattyFixture, never by the normal app.
/// No login, send, upload, or Issue mutation interface exists in P0.
public actor FixtureClient {
    public static let baseURL = URL(string: "http://127.0.0.1:8765/")!
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session { self.session = session }
        else {
            let config = URLSessionConfiguration.ephemeral
            config.httpCookieStorage = nil
            config.urlCredentialStorage = nil
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.timeoutIntervalForRequest = 12
            self.session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
        }
    }

    public func snapshot() async throws -> FixtureSnapshot {
        async let workspaces: [Workspace] = get("api/workspaces")
        async let agents: [ChatAgent] = get("api/agents")
        async let sessions: [ChatSession] = get("api/chat/sessions")
        async let projects: ProjectPage = get("api/projects")
        async let runtimes: [RuntimeDevice] = get("api/runtimes")
        async let squads: [Squad] = get("api/squads")
        guard let workspace = try await workspaces.first else { throw FixtureError.missingWorkspace }
        guard let mika = try await agents.first(where: { $0.systemKey == "mika" && $0.archivedAt == nil }) else {
            throw FixtureError.missingMika
        }
        guard let current = ChatSessions.latest(for: mika.id, in: try await sessions) else {
            throw FixtureError.missingSession
        }
        let messages: MessagePage = try await get("api/chat/sessions/\(current.id)/messages/page?limit=50")
        return try await FixtureSnapshot(workspace: workspace, mika: mika, messages: messages,
                                         projects: projects, runtimes: runtimes, squads: squads)
    }

    public func projects() async throws -> ProjectPage { try await get("api/projects") }

    private func get<T: Decodable & Sendable>(_ path: String) async throws -> T {
        let url = URL(string: path, relativeTo: Self.baseURL)!.absoluteURL
        // Both origin and route are compile-time fixture constants.
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer synthetic-device-fixture-token", forHTTPHeaderField: "Authorization")
        request.setValue("fixture", forHTTPHeaderField: "X-Workspace-Slug")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FixtureError.http((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        try Task.checkCancellation()
        return try Contracts.decode(T.self, from: data)
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? { nil }
}
