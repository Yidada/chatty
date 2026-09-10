import XCTest
import Foundation
@testable import ChattyCore

private final class FlowProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: (@Sendable (URLRequest) throws -> (Int, Data))?
    nonisolated(unsafe) static var deliveryGate: (@Sendable (URLRequest) -> DispatchSemaphore?)?
    private let lock = NSLock()
    private var stopped = false
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try XCTUnwrap(Self.respond)(request)
            let gate = Self.deliveryGate?(request)
            DispatchQueue.global().async { [self] in
                if let gate { _ = gate.wait(timeout: .now() + 10) }
                guard !lock.withLock({ stopped }) else { return }
                client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
            }
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { lock.withLock { stopped = true } }
}

private final class FlowServer: @unchecked Sendable {
    private let lock = NSLock()
    private var state = State()
    struct State {
        var status = 200
        var sendStatus = 200
        var failReadsAfterSend = false
        var malformedReceipt = false
        var attachmentReceipt = "bound"
        var signedAttempts = 0
        var foreignCredential = false
        var denyMika = false
        var catalogStatus = 200
        var issueConflict = false
        var issueStatus = "todo"
        var revision = 1
        var sessionProject: String?
        var patchStatus = 200
        var queueSupported = false
        var activeTask = false
        var holdSend: DispatchSemaphore?
        var activityScenario = false
        var issueQueries: [[String: String]] = []
        var requests: [(String, String, String?, [String: Any])] = []
        var sent: [[String: Any]] = []
    }
    func mutate(_ block: (inout State) -> Void) { lock.withLock { block(&state) } }
    func read<T>(_ block: (State) -> T) -> T { lock.withLock { block(state) } }
    func gate(_ request: URLRequest) -> DispatchSemaphore? {
        lock.withLock {
            guard request.httpMethod == "POST", request.url?.path.hasSuffix("/messages") == true else { return nil }
            defer { state.holdSend = nil }; return state.holdSend
        }
    }
    func client(base: URL, token: String?, workspace: String?) -> APIClient {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [FlowProtocol.self]
        return APIClient(baseURL: base, token: token, workspace: workspace, session: URLSession(configuration: config))
    }
    func response(_ request: URLRequest) throws -> (Int, Data) {
        try lock.withLock {
            let path = request.url!.path
            if request.url!.host == "files.example.test" {
                state.foreignCredential = request.value(forHTTPHeaderField: "Authorization") != nil || request.value(forHTTPHeaderField: "X-Workspace-Slug") != nil
                state.signedAttempts += 1
                return (state.signedAttempts == 1 ? 403 : 200, Data("download sample".utf8))
            }
            let method = request.httpMethod ?? "GET"
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(buffer, count: count) }
            }
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
            let scope = request.value(forHTTPHeaderField: "X-Workspace-Slug")
            state.requests.append((method, path, scope, body))
            func reply(_ value: Any, _ status: Int = 200) throws -> (Int, Data) { (status, try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])) }
            if path == "/auth/send-code" { return try reply([:]) }
            if path == "/auth/verify-code" { return try reply(body["code"] as? String == "123456" ? ["token":"flow-synthetic-token"] : ["error":"invalid"], body["code"] as? String == "123456" ? 200 : 400) }
            if state.status != 200 { return try reply([:], state.status) }
            if state.failReadsAfterSend && !state.sent.isEmpty && method == "GET" { return try reply([:], 503) }
            if path == "/api/me" { return try reply(["id":"u1", "email":"flow@example.test"]) }
            if path == "/api/workspaces" { return try reply([["id":"w1","slug":"one","name":"One"], ["id":"w2","slug":"two","name":"Two"]]) }
            if path == "/api/upload-file" { return try reply(["id":"upload1","filename":"sample.txt","size_bytes":15,"content_type":"text/plain"]) }
            if path.hasPrefix("/api/attachments/") { return try reply(["id":"upload1","filename":"sample.txt","size_bytes":15,"content_type":"text/plain","download_url":"https://files.example.test/sample"]) }
            if path.hasSuffix("/members") { return try reply([["user_id":"u1","role":"member"]]) }
            if path == "/api/agents" { return try reply([["id":"mika", "name":"Renamed", "system_key":"mika", "owner_id": state.denyMika ? "other" : "u1", "permission_mode":"private", "runtime_id":"r1", "runtime_bound":true]]) }
            var session: [String: Any] = ["id":"s1", "agent_id":"mika", "status":"active", "updated_at":"2026-09-05T00:00:00Z"]
            session["project_id"] = state.sessionProject
            if path == "/api/chat/sessions/s1", method == "PATCH" {
                guard state.patchStatus == 200 else { return try reply([:], state.patchStatus) }
                state.sessionProject = body["project_id"] as? String
                session["project_id"] = state.sessionProject
                return try reply(session)
            }
            if path == "/api/chat/sessions" { return try reply(method == "POST" ? session : [session]) }
            if path.hasSuffix("/read") { return try reply([:]) }
            if path.hasSuffix("/pending-task") {
                var result: [String: Any] = ["supports_queue":state.queueSupported]
                if state.activeTask { result["task_id"] = "active"; result["status"] = "running" }
                return try reply(result)
            }
            if method == "POST", path.hasSuffix("/messages") {
                let message: [String: Any] = ["id":"sent-\(state.sent.count)", "chat_session_id":"s1", "role":"user", "content":body["content"] ?? "", "created_at":"2026-09-06T00:00:00Z", "_project_id":state.sessionProject ?? "none", "_attachments":body["attachment_ids"] ?? []]
                state.sent.append(message)
                if state.sendStatus != 200 { return try reply([:], state.sendStatus) }
                var receipt: [String: Any] = ["message_id":message["id"]!, "task_id":state.malformedReceipt ? "" : "t1", "created_at":"2026-09-06T00:00:00Z"]
                receipt["supports_queue"] = state.queueSupported
                if state.attachmentReceipt != "missing" { receipt["attachment_ids"] = state.attachmentReceipt == "unbound" ? [] : body["attachment_ids"] ?? [] }
                return try reply(receipt)
            }
            if path.hasSuffix("/messages/page") {
                var messages: [[String: Any]] = (0..<55).map { ["id":String(format:"m%03d", $0), "chat_session_id":"s1", "role":"assistant", "content":"\(scope ?? "") message \($0)", "created_at":"2026-09-05T00:00:00Z"] }
                messages += state.sent
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
                if let id = query.first(where: { $0.name == "before_id" })?.value, let index = messages.firstIndex(where: { $0["id"] as? String == id }) { messages = Array(messages.prefix(index)) }
                let page = Array(messages.suffix(50)); let more = messages.count > 50
                var result: [String:Any] = ["messages":page, "has_more":more]
                if more { result["next_cursor"] = ["id":page[0]["id"]!, "created_at":page[0]["created_at"]!] }
                return try reply(result)
            }
            if path.hasPrefix("/api/tasks/") { return try reply([]) }
            if path == "/api/projects" { return try reply(["projects":[["id":"p1","title":"Project","issue_count":55,"done_count":25], ["id":"p2","title":"Other project"]], "total":2]) }
            if path == "/api/issue-statuses" { return try reply(["statuses":[["key":"todo","name":"待开始","category":"todo"],["key":"custom","name":"自定义","category":"in_review"]]], state.catalogStatus) }
            if path == "/api/issues" {
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
                let offset = Int(query.first(where: { $0.name == "offset" })?.value ?? "0") ?? 0
                state.issueQueries.append(Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") }))
                var rows = (0..<55).map { issue($0) }
                if let keys = query.first(where: { $0.name == "statuses" })?.value?.components(separatedBy: ",") { rows = rows.filter { keys.contains($0["status"] as? String ?? "") } }
                return try reply(["issues":Array(rows.dropFirst(offset).prefix(50)),"total":rows.count])
            }
            if path.hasPrefix("/api/issues/") {
                if method == "PUT" {
                    if state.issueConflict { state.revision += 1; return try reply([:], 409) }
                    state.issueStatus = body["status"] as? String ?? "todo"; state.revision += 1
                }
                return try reply(issue(0))
            }
            return try reply([:], 404)
        }
    }
    private func issue(_ i: Int) -> [String: Any] {
        ["id":"i\(i)","identifier":"FLOW-\(i)","title":"Issue \(i)","status":state.activityScenario && i == 54 ? "custom" : state.issueStatus,"revision":state.revision,"creator_id":"another-member","creator_type":"human","project_id":"p1"]
    }
}

@MainActor private final class MemoryVault: CredentialVault {
    var token: String?
    func read() throws -> String? { token }
    func save(_ token: String?) throws { self.token = token }
}
@MainActor private final class FlowRig {
    let server = FlowServer()
    let vault = MemoryVault()
    let files: ProtectedStorage
    let model: SessionModel
    init() throws {
        let server = self.server
        FlowProtocol.respond = { try server.response($0) }
        FlowProtocol.deliveryGate = { server.gate($0) }
        files = try ProtectedStorage(identifier: "flow", root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        model = SessionModel(baseURL: URL(string:"https://flow.invalid")!, vault: vault, files: files, factory: { server.client(base: $0, token: $1, workspace: $2) })
    }
    func login() async {
        await model.restore(); model.email = "flow@example.test"; await model.sendCode(); model.code = "123456"; await model.verify()
        if let workspace = model.workspaces.first { model.select(workspace); await model.current?.chat.initialize() }
    }
    func cleanup() { model.signOut(); try? FileManager.default.removeItem(at: files.root) }
}

@MainActor final class ClientFlowTests: XCTestCase {
    private func waitFor(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Expected asynchronous state did not arrive", file: file, line: line)
    }
    func testConsecutiveSendsSnapshotProjectsAndFilesWhileFirstReceiptIsHeld() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let chat = try XCTUnwrap(rig.model.current?.chat)
        let gate = DispatchSemaphore(value: 0); defer { gate.signal() }
        rig.server.mutate { $0.queueSupported = true; $0.activeTask = true; $0.holdSend = gate }
        await chat.refresh()
        chat.selectProject("p1")
        await chat.upload(data: Data("A attachment".utf8), filename: "a.txt", contentType: "text/plain")
        chat.setDraft("A"); let first = Task { await chat.send() }
        try await waitFor { rig.server.read { $0.sent.count } == 1 }
        XCTAssertEqual(chat.draft, ""); XCTAssertTrue(chat.attachments.isEmpty); XCTAssertTrue(chat.sending)
        await chat.refresh()
        XCTAssertFalse(chat.messages.contains { $0.content == "A" }, "An early history echo must not duplicate the still-unconfirmed local row")
        chat.selectProject("p2"); chat.setDraft("B"); XCTAssertTrue(chat.canSend); await chat.send()
        chat.selectProject(nil); chat.setDraft("C"); await chat.send()
        chat.setDraft("D still being composed")
        XCTAssertEqual(chat.outbox.map(\.content), ["A", "B", "C"])
        XCTAssertEqual(chat.outbox.map(\.projectId), ["p1", "p2", nil])
        XCTAssertEqual(rig.server.read { $0.sent.count }, 1, "B and C must wait for A's HTTP receipt, not its agent run")
        gate.signal(); await first.value
        let sent = rig.server.read { $0.sent }
        XCTAssertEqual(sent.compactMap { $0["content"] as? String }, ["A", "B", "C"])
        XCTAssertEqual(sent.compactMap { $0["_project_id"] as? String }, ["p1", "p2", "none"])
        XCTAssertEqual(sent.compactMap { $0["_attachments"] as? [String] }, [["upload1"], [], []])
        XCTAssertEqual(chat.draft, "D still being composed"); XCTAssertTrue(chat.canSend); XCTAssertTrue(chat.outbox.isEmpty)
        XCTAssertEqual(rig.server.read { $0.requests.filter { $0.0 == "PATCH" }.count }, 3)
    }
    func testLegacyActiveRunQueuesLocallyUntilRunFinishes() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let chat = try XCTUnwrap(rig.model.current?.chat)
        rig.server.mutate { $0.activeTask = true; $0.queueSupported = false }; await chat.refresh()
        chat.setDraft("Wait locally"); XCTAssertTrue(chat.canSend); await chat.send()
        XCTAssertEqual(rig.server.read { $0.sent.count }, 0); XCTAssertEqual(chat.outbox.count, 1)
        chat.setDraft("Keep typing"); XCTAssertTrue(chat.canSend)
        rig.server.mutate { $0.activeTask = false }; await chat.refresh()
        XCTAssertEqual(rig.server.read { $0.sent.count }, 1); XCTAssertEqual(chat.draft, "Keep typing")
    }
    func testIdenticalTextRemainsTwoSeparateMessagesAfterReceipts() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let chat = try XCTUnwrap(rig.model.current?.chat)
        let gate = DispatchSemaphore(value: 0); defer { gate.signal() }
        rig.server.mutate { $0.queueSupported = true; $0.holdSend = gate }
        chat.setDraft("Same text"); let first = Task { await chat.send() }
        try await waitFor { rig.server.read { $0.sent.count } == 1 }
        chat.setDraft("Same text"); await chat.send(); await chat.refresh()
        XCTAssertEqual(chat.outbox.count, 2)
        gate.signal(); await first.value
        XCTAssertEqual(rig.server.read { $0.sent.count }, 2)
        XCTAssertEqual(chat.messages.filter { $0.content == "Same text" }.count, 2)
        XCTAssertTrue(chat.outbox.isEmpty)
    }
    func testProjectPermissionFailureStopsPostAndExplicitRetryPreservesSnapshot() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let chat = try XCTUnwrap(rig.model.current?.chat)
        rig.server.mutate { $0.patchStatus = 403 }
        chat.selectProject("p1"); chat.setDraft("Requires project"); await chat.send()
        XCTAssertEqual(rig.server.read { $0.sent.count }, 0); XCTAssertEqual(chat.outbox.first?.status, .failed)
        chat.selectProject("p2")
        rig.server.mutate { $0.patchStatus = 200 }
        await chat.retryOutgoing(try XCTUnwrap(chat.outbox.first?.id))
        XCTAssertEqual(rig.server.read { $0.sent.first?["_project_id"] as? String }, "p1")
        XCTAssertEqual(chat.selectedProjectId, "p2"); XCTAssertTrue(chat.outbox.isEmpty)
    }
    func testColdQueueRequiresExplicitResumeAndKeepsComposerSeparate() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let chat = try XCTUnwrap(rig.model.current?.chat)
        rig.server.mutate { $0.activeTask = true }; await chat.refresh()
        chat.selectProject("p1"); chat.setDraft("Queued before closing"); await chat.send()
        chat.setDraft("Unsent composer")
        rig.model.select(rig.model.workspaces[0]); let restored = try XCTUnwrap(rig.model.current?.chat); await restored.initialize()
        rig.server.mutate { $0.activeTask = false }; await restored.refresh()
        XCTAssertEqual(restored.outbox.first?.status, .held); XCTAssertEqual(restored.draft, "Unsent composer")
        XCTAssertEqual(rig.server.read { $0.sent.count }, 0)
        await restored.resumeOutbox()
        XCTAssertEqual(rig.server.read { $0.sent.count }, 1); XCTAssertEqual(restored.draft, "Unsent composer")
    }
    func testBackgroundHoldsFollowersWhileInFlightReceiptCompletes() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let chat = try XCTUnwrap(rig.model.current?.chat)
        let gate = DispatchSemaphore(value: 0); defer { gate.signal() }
        rig.server.mutate { $0.queueSupported = true; $0.holdSend = gate }
        chat.setDraft("In flight"); let first = Task { await chat.send() }
        try await waitFor { rig.server.read { $0.sent.count } == 1 }
        chat.setDraft("Follower"); await chat.send(); chat.stop()
        gate.signal(); await first.value
        XCTAssertEqual(chat.outbox.first?.content, "Follower"); XCTAssertEqual(chat.outbox.first?.status, .held)
        XCTAssertEqual(rig.server.read { $0.sent.count }, 1)
        let saved = try rig.files.draft(account: "u1", workspace: "w1", agent: "mika")
        XCTAssertEqual(saved.outbox?.map(\.content), ["Follower"])
    }
    func testActivityIncludesOtherCreatorsAndOlderActionsWithSeparateReadState() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        rig.server.mutate { $0.activityScenario = true }
        let activity = try XCTUnwrap(rig.model.current?.activity); await activity.refresh()
        XCTAssertEqual(activity.recent.count, 50); XCTAssertEqual(activity.actions.map(\.id), ["i54"])
        XCTAssertTrue(activity.recent.allSatisfy { $0.creatorId == "another-member" })
        let action = try XCTUnwrap(activity.actions.first); activity.markRead(action)
        XCTAssertFalse(activity.isUnread(action)); XCTAssertEqual(activity.actions.count, 1); XCTAssertTrue(activity.hasAttention)
        let query = try XCTUnwrap(rig.server.read { $0.issueQueries.first { $0["statuses"] != nil } })
        XCTAssertEqual(query["sort"], "last_activity"); XCTAssertTrue(query["statuses"]?.contains("custom") == true)
        XCTAssertNil(query["assignee_id"]); XCTAssertNil(query["creator_id"]); XCTAssertNil(query["project_id"])
        await activity.more(actions: false); XCTAssertEqual(activity.recent.count, 55)
        rig.server.mutate { $0.revision += 1 }; await activity.refresh()
        XCTAssertTrue(activity.isUnread(try XCTUnwrap(activity.actions.first)))
        rig.server.mutate { $0.catalogStatus = 503 }; await activity.refresh()
        XCTAssertEqual(activity.actions.count, 1); XCTAssertNotNil(activity.actionError)
        rig.server.mutate { $0.status = 503 }; await activity.refresh()
        XCTAssertEqual(activity.recent.count, 50); XCTAssertNotNil(activity.error)
        XCTAssertEqual(try rig.files.activityReads(account: "u1", workspace: "w1")[action.id], ActivityModel.fingerprint(action))
        XCTAssertTrue(try rig.files.activityReads(account: "u2", workspace: "w1").isEmpty)
        XCTAssertTrue(try rig.files.activityReads(account: "u1", workspace: "w2").isEmpty)
    }
    func testCredentialsNeverReachAuthOrForeignOrigin() throws {
        let client = APIClient(baseURL: URL(string:"https://api.example.test")!, token:"synthetic", workspace:"one")
        defer { client.invalidate() }
        XCTAssertEqual(try client.request(for: URL(string:"https://api.example.test/api/me")!).value(forHTTPHeaderField:"Authorization"), "Bearer synthetic")
        for url in ["https://api.example.test/auth/send-code", "https://files.example.test/api/a"] {
            let request = try client.request(for: URL(string:url)!)
            XCTAssertNil(request.value(forHTTPHeaderField:"Authorization")); XCTAssertNil(request.value(forHTTPHeaderField:"X-Workspace-Slug"))
        }
        XCTAssertThrowsError(try client.request(for: URL(string:"http://files.example.test/a")!))
        XCTAssertThrowsError(try client.request(for: URL(string:"https://user:pass@files.example.test/a")!))
    }
    func testInvalidCodeDoesNotPersistCredentialsAndValidCodeLoadsAccount() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }
        await rig.model.restore(); rig.model.email = "flow@example.test"; await rig.model.sendCode()
        rig.model.code = "999999"; await rig.model.verify()
        XCTAssertNil(rig.vault.token); XCTAssertNotNil(rig.model.error); XCTAssertTrue(rig.model.codeSent)
        rig.model.code = "123456"; await rig.model.verify()
        XCTAssertEqual(rig.model.workspaces.count,2); XCTAssertEqual(rig.model.user?.id,"u1")
        XCTAssertEqual(rig.vault.token,"flow-synthetic-token"); XCTAssertEqual(rig.model.code, "")
    }
    func testOnlyCurrent401ClearsCredentials() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let old = try XCTUnwrap(rig.model.current)
        rig.model.select(rig.model.workspaces[1])
        _ = await old.context.report(APIError.http(401))
        XCTAssertNotNil(rig.vault.token); XCTAssertEqual(rig.model.current?.context.workspace.id,"w2")
        for status in [403,503] {
            rig.server.mutate { $0.status = status }; await rig.model.loadAccount(); XCTAssertNotNil(rig.vault.token)
        }
        rig.server.mutate { $0.status = 401 }; await rig.model.loadAccount()
        XCTAssertNil(rig.vault.token); XCTAssertFalse(rig.model.authenticated); XCTAssertNil(rig.model.current)
    }
    func testWorkspaceDraftIsolationAndOldScopeCannotSend() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let first = try XCTUnwrap(rig.model.current); first.chat.setDraft("workspace one")
        rig.model.select(rig.model.workspaces[1]); let second = try XCTUnwrap(rig.model.current); await second.chat.initialize()
        XCTAssertEqual(second.chat.draft, ""); XCTAssertTrue(second.chat.messages.allSatisfy { ($0.content ?? "").hasPrefix("two") })
        second.chat.setDraft("workspace two"); await first.chat.send()
        XCTAssertEqual(rig.server.read { $0.sent.count }, 0)
        rig.model.select(rig.model.workspaces[0]); await rig.model.current?.chat.initialize()
        XCTAssertEqual(rig.model.current?.chat.draft,"workspace one")
        rig.model.signOut(); XCTAssertEqual(try rig.files.draft(account:"u1",workspace:"w1",agent:"mika").text, "")
    }
    func testDoubleSendProducesOneWriteAndReceiptClearsDraft() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let chat = try XCTUnwrap(rig.model.current?.chat); chat.setDraft("One request")
        async let first: Void = chat.send(); async let second: Void = chat.send(); _ = await (first,second)
        XCTAssertEqual(rig.server.read { $0.sent.count },1); XCTAssertEqual(chat.draft, ""); XCTAssertFalse(chat.uncertain)
        XCTAssertTrue(chat.messages.contains { $0.content == "One request" })
    }
    func testUnknownReceiptSurvivesRefreshAndColdModelWithoutResending() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        rig.server.mutate { $0.malformedReceipt = true }
        let chat = try XCTUnwrap(rig.model.current?.chat); chat.setDraft("Ambiguous")
        await chat.send(); await chat.refresh(); await chat.send()
        XCTAssertTrue(chat.uncertain); XCTAssertEqual(chat.draft,""); XCTAssertEqual(chat.outbox.first?.content,"Ambiguous")
        XCTAssertEqual(chat.outbox.first?.status,.uncertain)
        chat.setDraft("Next message"); XCTAssertTrue(chat.canSend); await chat.send()
        XCTAssertEqual(chat.outbox.count,2); XCTAssertEqual(chat.draft,"")
        XCTAssertEqual(rig.server.read { $0.sent.count },1)
        rig.model.select(rig.model.workspaces[0]); await rig.model.current?.chat.initialize()
        XCTAssertTrue(rig.model.current?.chat.uncertain == true)
        XCTAssertEqual(rig.model.current?.chat.outbox.map(\.status),[.uncertain,.held])
        await rig.model.current?.chat.refresh()
        XCTAssertEqual(rig.server.read { $0.sent.count },1)
    }
    func testV1UncertainDraftMigratesWithoutBecomingANewSend() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        rig.model.switchWorkspace()
        try rig.files.saveDraft(.init(text: "V1 uncertain send", uncertain: true), account: "u1", workspace: "w1", agent: "mika")
        rig.model.select(rig.model.workspaces[0]); await rig.model.current?.chat.initialize()
        let chat = try XCTUnwrap(rig.model.current?.chat)
        XCTAssertEqual(chat.draft, ""); XCTAssertTrue(chat.uncertain)
        XCTAssertEqual(chat.outbox.first?.content, "V1 uncertain send"); XCTAssertEqual(chat.outbox.first?.status, .uncertain)
        let migrated = try rig.files.draft(account: "u1", workspace: "w1", agent: "mika")
        XCTAssertEqual(migrated.text, ""); XCTAssertEqual(migrated.outbox?.count, 1)
        chat.setDraft("New request after upgrade"); await chat.send(); await chat.refresh()
        XCTAssertEqual(rig.server.read { $0.sent.count }, 0)
        chat.acknowledgeUncertain()
        try await waitFor { rig.server.read { $0.sent.count } == 1 }
        XCTAssertEqual(rig.server.read { $0.sent.first?["content"] as? String }, "New request after upgrade")
    }
    func testUnknownReceiptCanOnlyRetryAfterExplicitReview() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        rig.server.mutate { $0.malformedReceipt = true }
        let chat = try XCTUnwrap(rig.model.current?.chat)
        chat.selectProject("p1"); chat.setDraft("Uncertain delivery"); await chat.send()
        chat.selectProject("p2"); chat.setDraft("Next draft")
        await chat.refresh(); XCTAssertEqual(rig.server.read { $0.sent.count },1)
        rig.server.mutate { $0.malformedReceipt = false }
        await chat.retryUncertainAfterReview()
        XCTAssertEqual(rig.server.read { $0.sent.count },2)
        XCTAssertEqual(rig.server.read { $0.sent.last?["_project_id"] as? String },"p1")
        XCTAssertFalse(chat.uncertain); XCTAssertEqual(chat.draft,"Next draft")
    }
    func testAcceptedSendWithFailedRefreshIsNeverTurnedIntoRetry() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        rig.server.mutate { $0.failReadsAfterSend = true }
        let chat = try XCTUnwrap(rig.model.current?.chat); chat.setDraft("Accepted")
        await chat.send(); await chat.send()
        XCTAssertEqual(rig.server.read { $0.sent.count },1); XCTAssertFalse(chat.uncertain); XCTAssertEqual(chat.draft, "")
        XCTAssertNotNil(chat.pending?.taskId); XCTAssertNotNil(chat.error)
    }
    func testHistoryUsesBothCursorsAndKeepsEqualTimestampMessages() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let chat = try XCTUnwrap(rig.model.current?.chat)
        XCTAssertEqual(chat.messages.count,50); XCTAssertTrue(chat.hasMore)
        await chat.older(); XCTAssertEqual(chat.messages.count,55); XCTAssertFalse(chat.hasMore)
        XCTAssertEqual(Set(chat.messages.map(\.id)).count,55)
    }
    func testUnavailableMikaCannotSendEvenWhenDisplayNameMatches() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }
        rig.server.mutate { $0.denyMika = true }; await rig.login()
        let chat = try XCTUnwrap(rig.model.current?.chat); chat.setDraft("Must not send")
        XCTAssertNil(chat.agent); XCTAssertFalse(chat.canSend); await chat.send(); XCTAssertEqual(rig.server.read { $0.sent.count },0)
    }
    func testIssuePaginationAndOneRevisionProtectedSuppressedWrite() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let projects = try XCTUnwrap(rig.model.current?.projects)
        await projects.overview(); XCTAssertEqual(projects.projects.first?.doneCount,25)
        await projects.loadIssues(project:"p1"); XCTAssertEqual(projects.issues.count,50)
        await projects.more(); XCTAssertEqual(projects.issues.count,55)
        await projects.loadDetail(id:"i0"); await projects.changeStatus("custom")
        let writes = rig.server.read { $0.requests.filter { $0.0 == "PUT" } }
        XCTAssertEqual(writes.count,1); XCTAssertEqual(writes[0].3["expected_revision"] as? Int,1)
        XCTAssertEqual(writes[0].3["suppress_run"] as? Bool,true); XCTAssertEqual(projects.detail?.status,"custom")
    }
    func testIssueConflictReadsFreshRevisionWithoutRepeatingWrite() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let projects = try XCTUnwrap(rig.model.current?.projects)
        await projects.overview(); await projects.loadDetail(id:"i0"); rig.server.mutate { $0.issueConflict = true }
        await projects.changeStatus("custom"); await projects.changeStatus("custom")
        XCTAssertEqual(rig.server.read { $0.requests.filter { $0.0 == "PUT" }.count },1)
        XCTAssertEqual(projects.detail?.revision,2); XCTAssertNotNil(projects.detailError)
    }
    func testFailedStatusCatalogKeepsProjectsAndDisablesEditing() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login(); rig.server.mutate { $0.catalogStatus = 503 }
        let projects = try XCTUnwrap(rig.model.current?.projects); await projects.overview()
        XCTAssertEqual(projects.projects.count,2); XCTAssertTrue(projects.statuses.isEmpty); XCTAssertNotNil(projects.catalogError)
    }
    func testProtectedPreviewsAndAccountDraftsArePurgedOnLogout() throws {
        let rig = try FlowRig(); defer { rig.cleanup() }
        try rig.files.saveDraft(.init(text:"private"), account:"u1", workspace:"w1", agent:"mika")
        XCTAssertEqual(try rig.files.draft(account:"u2",workspace:"w1",agent:"mika").text, "")
        let preview = try rig.files.preview(Data("sample".utf8),filename:"../../unsafe.html")
        XCTAssertEqual(preview.deletingLastPathComponent(),rig.files.temporary)
        rig.model.signOut(); XCTAssertFalse(FileManager.default.fileExists(atPath:preview.path))
        XCTAssertEqual(try rig.files.draft(account:"u1",workspace:"w1",agent:"mika").text, "")
    }
    func testAttachmentReceiptControlsRemovalAndNeverGuessesBinding() async throws {
        for mode in ["bound", "unbound", "missing"] {
            let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
            rig.server.mutate { $0.attachmentReceipt = mode }
            let chat = try XCTUnwrap(rig.model.current?.chat)
            await chat.upload(data: Data("sample".utf8), filename:"sample.txt", contentType:"text/plain")
            XCTAssertEqual(chat.attachments.count,1)
            chat.setDraft("With attachment"); await chat.send()
            XCTAssertEqual(rig.server.read { $0.sent.count },1)
            XCTAssertEqual(chat.attachments.count, mode == "bound" ? 0 : 1)
            XCTAssertEqual(chat.attachmentBindingUncertain,mode == "missing")
            if mode == "missing" { chat.setDraft("next"); XCTAssertFalse(chat.canSend) }
        }
    }
    func testExpiredSignedURLRefreshesMetadataWithoutSendingCredentials() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let api = try XCTUnwrap(rig.model.current?.context.api)
        let attachment: Attachment = try await api.upload(data:Data("sample".utf8),filename:"sample.txt",contentType:"text/plain")
        let (_, data) = try await api.attachmentData(attachment)
        XCTAssertEqual(String(decoding:data,as:UTF8.self),"download sample")
        XCTAssertEqual(rig.server.read { $0.signedAttempts },2)
        XCTAssertFalse(rig.server.read { $0.foreignCredential })
        XCTAssertEqual(rig.server.read { $0.requests.filter { $0.1 == "/api/attachments/upload1" }.count },2)
    }
    func testOversizeUploadIsRejectedBeforeAnyNetworkWrite() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let api = try XCTUnwrap(rig.model.current?.context.api)
        do { _ = try await api.upload(data:Data(count:APIClient.maximumFileBytes+1),filename:"large.bin",contentType:"application/octet-stream"); XCTFail("size gate") }
        catch { XCTAssertEqual(error as? APIError,.oversizedFile) }
        XCTAssertEqual(rig.server.read { $0.requests.filter { $0.1 == "/api/upload-file" }.count },0)
    }
    func testReadReceiptOnlyWhileChatIsVisibleAndDeduplicatesRefreshes() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let chat = try XCTUnwrap(rig.model.current?.chat)
        await chat.refresh()
        XCTAssertEqual(rig.server.read { $0.requests.filter { $0.1.hasSuffix("/read") }.count },0)
        await chat.setVisible(true); await chat.refresh(); await chat.setVisible(false); await chat.refresh()
        XCTAssertEqual(rig.server.read { $0.requests.filter { $0.1.hasSuffix("/read") }.count },1)
    }
    func testColdOfflineRecoveryKeepsDraftWithoutCreatingAuthorizedWorkspace() async throws {
        let rig = try FlowRig(); defer { rig.cleanup() }; await rig.login()
        let current = try XCTUnwrap(rig.model.current)
        current.chat.setDraft("offline work")
        rig.model.rememberDraftScope(current)
        XCTAssertNil(try rig.files.recovery(token:"different-account-token"))
        rig.model.switchWorkspace(); rig.server.mutate { $0.status = 503 }
        await rig.model.loadAccount()
        XCTAssertEqual(rig.model.recoveryDraft.text,"offline work")
        XCTAssertNil(rig.model.current)
        rig.model.setRecoveryDraft("edited offline")
        rig.server.mutate { $0.status = 200 }; await rig.model.loadAccount(); await rig.model.current?.chat.initialize()
        XCTAssertNil(rig.model.recoveryScope)
        XCTAssertEqual(rig.model.current?.chat.draft,"edited offline")
    }
    func testFailureLabelsAndTraceRedactionKeepSecretsOutOfPresentation() {
        XCTAssertTrue(DisplayText.failure("agent_error.provider_network").contains("网络"))
        XCTAssertEqual(DisplayText.redactInput(.object(["API_KEY":.string("private-value")])).object?["API_KEY"]?.string,"[已隐藏凭据]")
        XCTAssertFalse(DisplayText.redactTrace("Authorization: Bearer synthetic-private-credential").contains("synthetic-private-credential"))
        XCTAssertFalse(DisplayText.redactTrace("API_KEY=private-value").contains("private-value"))
    }
    func testRichInlineStylesNestedListsAndUnsafeLinks() throws {
        let blocks = RichDocument.parse("**bold** *italic* ~~gone~~ `code` [site](https://example.com)\n\n1. first\n   - [x] nested\n\n![picture](/api/image)\n\n```mermaid\ngraph LR\nA-->B\n```")
        guard case .paragraph(let runs) = blocks[0] else { return XCTFail("paragraph") }
        XCTAssertTrue(runs.contains { $0.bold && $0.text == "bold" }); XCTAssertTrue(runs.contains { $0.italic }); XCTAssertTrue(runs.contains { $0.strike }); XCTAssertTrue(runs.contains { $0.code })
        XCTAssertTrue(blocks.contains { if case .image("picture", "/api/image") = $0 { return true }; return false })
        let api = URL(string:"https://api.multica.ai")!
        XCTAssertEqual(NativeLink.resolve("mention://issue/MUL-7",api:api,workspace:"one"),.issue("MUL-7"))
        XCTAssertEqual(NativeLink.resolve("https://app.multica.ai/one/issues/i1",api:api,workspace:"one"),.issue("i1"))
        XCTAssertEqual(NativeLink.resolve("https://app.multica.ai/two/issues/i1",api:api,workspace:"one"),.unavailable)
        XCTAssertEqual(NativeLink.resolve("javascript:alert(1)",api:api,workspace:"one"),.unavailable)
        XCTAssertEqual(NativeLink.resolve("//evil.test/issues/i1",api:api,workspace:"one"),.unavailable)
    }
}
