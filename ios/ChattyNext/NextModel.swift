import Foundation
import SwiftUI
import ChattyNextCore

@MainActor final class NextModel: ObservableObject {
    @Published var client: DSHClient?
    @Published var sessions: [Wire] = []
    @Published var workspaces: [Wire] = []
    @Published var catalog: Wire = .null
    @Published var local = NextLocalState()
    @Published var reducer = SessionReducer()
    @Published var current = "draft-" + UUID().uuidString
    @Published var error: String?
    @Published var status = "未连接"
    @Published var ready = false
    @Published var busy = false
    @Published var stopping = false
    @Published var running: Set<String> = []
    @Published var queues: [String: [Wire]] = [:]
    @Published var prompts: [Wire] = []
    @Published var searchResults: [Wire]?
    @Published var searchHasMore = false
    let storage: NextStorage?
    let vault: NextVault
    private var tasks: [String: Task<Void, Never>] = [:]
    private var retry: Task<Void, Never>?
    private var generation = 0
    private var loaded: Set<String> = []
    private var eventClientID: String?
    private var searchGeneration = 0
    private var creating = Set<String>()
    private var liveStatuses: [String: Bool] = [:]
    var identifier: String { Bundle.main.bundleIdentifier ?? "ai.chatty.ios.next" }
    var isDraft: Bool { current.hasPrefix("draft-") }
    var draft: NextDraft { local.drafts[current] ?? NextDraft() }
    var isRunning: Bool { running.contains(current) || reducer.live }
    var modelLocked: Bool { busy || !ready || isRunning || !(queues[current] ?? []).isEmpty || local.pending.contains { $0.sessionID == current } }
    var models: [Wire] {
        catalog["groups"].array.flatMap { group in group["models"].array.map { model in
            .object(["provider": group["id"], "providerName": group["name"], "model": model["id"], "name": model["name"], "reasoning": model["reasoning"]])
        } }
    }
    var modelName: String { models.first { $0["provider"] == draft.model["provider"] && $0["model"] == draft.model["model"] }?["name"].text ?? draft.model["model"].string ?? "选择模型" }
    var workspaceName: String { draft.workspace["title"].string ?? (draft.workspace["path"].string.map { URL(fileURLWithPath: $0).lastPathComponent }) ?? "工作目录" }
    var title: String { reducer.projections["title"].string ?? title(for: sessions.first { $0["sessionId"].text == current } ?? .null) }
    var canRecord: Bool { ready && !busy && draft.model["model"].string != nil && (!isDraft || workspaces.contains { $0["workspaceId"] == draft.workspace["workspaceId"] }) && !local.pending.contains { $0.sessionID == current && $0.state != "accepted" } }
    var canSend: Bool { ready && !busy && (!draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.attachments.isEmpty) && draft.model["model"].string != nil && (!isDraft || workspaces.contains { $0["workspaceId"] == draft.workspace["workspaceId"] }) && !local.pending.contains { $0.sessionID == current && $0.state != "accepted" } }
    init() {
        let identifier = Bundle.main.bundleIdentifier ?? "ai.chatty.ios.next"
        vault = NextVault(service: identifier + ".connection")
        do { storage = try NextStorage(identifier: identifier) } catch { storage = nil }
    }
    func restore() async {
        guard client == nil else { return }
        do {
            #if CHATTY_NEXT_FIXTURE
            let origin = try DSHOrigin("http://127.0.0.1:8876", allowLoopbackHTTP: true)
            try await activate(DSHCredential(origin: origin, cookie: "fixture=next")); return
            #else
            #if DEBUG
            if let url = ProcessInfo.processInfo.environment["CHATTY_NEXT_PAIR_URL"] { let credential = try await DSHClient.pair(address: url, token: ""); try vault.save(credential); try await activate(credential); return }
            #endif
            if let credential = try vault.read() { try await activate(credential) }
            #endif
        } catch { report(error) }
    }
    func pair(address: String, token: String) async {
        guard !busy else { return }; busy = true; status = "正在连接…"; defer { busy = false }
        do {
            let credential = try await DSHClient.pair(address: address, token: token)
            try vault.save(credential); try await activate(credential)
        } catch { status = "连接未完成"; report(error) }
    }
    private func activate(_ credential: DSHCredential) async throws {
        suspend(); client?.shutdown(); client = DSHClient(credential: credential)
        guard let storage else { throw NextError.storage }; local = try storage.load(origin: credential.origin)
        current = local.lastSession ?? current
        for index in local.pending.indices where local.pending[index].state != "accepted" { local.pending[index].state = "uncertain" }
        try storage.save(local, origin: credential.origin)
        await resume()
    }
    func resume() async {
        guard let client else { return }; retry?.cancel(); retry = nil
        stopStreams(); generation += 1; let g = generation; loaded = []; liveStatuses = [:]; ready = false; error = nil; status = "正在恢复连接…"
        do {
            catalog = try await client.rpc("session/modelCatalog")
            guard g == generation else { return }
            try await refreshSessions(); guard g == generation else { return }
            if draft.model == .null { var d = draft; d.model = catalog["default"]; try storeDraft(d) }
            listen("workspace", endpoint: "workspace/follow", generation: g) { [weak self] frame in try self?.workspaceFrame(frame) }
            listen("control", endpoint: "session/control", generation: g) { [weak self] frame in self?.controlFrame(frame) }
            listen("events", endpoint: "$events", generation: g) { [weak self] frame in self?.eventFrame(frame) }
            follow(generation: g)
        } catch { failed(error, generation: g) }
    }
    func suspend() { retry?.cancel(); retry = nil; generation += 1; stopStreams(); ready = false; status = "连接已暂停" }
    private func stopStreams() { loaded.removeAll(); for t in tasks.values { t.cancel() }; tasks.removeAll(); client?.disconnect(); prompts = []; eventClientID = nil }
    private func listen(_ key: String, endpoint: String, args: Wire = .object([:]), generation g: Int, receive: @escaping @MainActor (Wire) throws -> Void) {
        tasks[key]?.cancel()
        tasks[key] = Task { [weak self] in
            guard let self, let client = self.client else { return }
            do {
                let stream = try await client.stream(endpoint, args: args)
                for try await value in stream {
                    guard !Task.isCancelled, g == self.generation else { return }
                    try receive(value)
                }
                if !Task.isCancelled { throw NextError.disconnected }
            } catch { if !Task.isCancelled { self.failed(error, generation: g) } }
        }
    }
    private func failed(_ failure: Error, generation g: Int) {
        guard g == generation else { return }; generation += 1; stopStreams(); ready = false; status = "连接已中断"; report(failure)
        if let next = failure as? NextError {
            switch next { case .authentication, .protocolMismatch, .server: return; default: break }
        }
        retry = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled else { return }; await self?.resume()
        }
    }
    private func checkReady() {
        let wasReady = ready
        ready = loaded.isSuperset(of: ["workspace", "control", "events"]) && (isDraft || loaded.contains("follow"))
        if ready {
            status = "已连接"
            // Subscribe before this refresh so state changes during the request cannot be missed.
            if !wasReady { tasks["refresh"] = Task { [weak self] in try? await self?.refreshSessions() } }
        } else if !isDraft { status = "正在恢复会话…" }
    }

    private func workspaceFrame(_ frame: Wire) throws {
        switch frame["type"].text {
        case "baseline": workspaces = frame["value"]["items"].array; loaded.insert("workspace")
        case "upsert": let item = frame["workspace"]; workspaces.removeAll { $0["workspaceId"] == item["workspaceId"] }; workspaces.append(item)
        case "remove": workspaces.removeAll { $0["workspaceId"] == frame["workspaceId"] }
        case "order", "archived": break
        default: throw NextError.protocolMismatch("工作目录流")
        }
        checkReady()
    }
    private func controlFrame(_ frame: Wire) {
        switch frame["type"].text {
        case "baseline":
            queues = frame["value"]["queues"].object.mapValues(\.array); loaded.insert("control")
            if let p = frame["value"]["projections"].object[current] { applySelection(p["values"]) }
        case "queue": queues[frame["sessionId"].text] = frame["items"].array
        case "projection":
            if frame["sessionId"].text == current {
                reducer.updateProjection(frame["key"].text, value: frame["value"])
                if frame["key"].text == "modelSelection" { applySelection(.object(["modelSelection": frame["value"]])) }
            }
        default: break
        }
        reconcile(); checkReady()
    }
    private func eventFrame(_ frame: Wire) {
        switch frame["type"].text {
        case "ready": eventClientID = frame["clientId"].string; loaded.insert("events"); checkReady()
        case "waterfall": if ["approval/request", "user-questions/request"].contains(frame["event"].text) { prompts.removeAll { $0["eventId"] == frame["eventId"] }; prompts.append(frame) }
            else { error = "Mac 发来尚未支持的确认，请在 Mac 处理：" + frame["event"].text }
        case "cancel": prompts.removeAll { $0["eventId"] == frame["eventId"] }
        case "emit":
            let args = frame["args"].array
            if frame["event"].text == "api-session/status", args.count >= 2 {
                let id = args[0].text; liveStatuses[id] = args[1].bool; if args[1].bool { running.insert(id) } else { running.remove(id); if id == current { stopping = false } }
            }
            if frame["event"].text == "api-session/error", args.count >= 2, args[0].text == current { error = args[1].text }
        default: break
        }
    }
    private func follow(generation g: Int) {
        tasks["follow"]?.cancel(); loaded.remove("follow"); reducer = SessionReducer(); stopping = false
        guard !isDraft else { checkReady(); return }; let id = current
        listen("follow", endpoint: "session/follow", args: .object(["request": .object(["address": address(id), "maxMessages": .number(60), "assistantStream": .bool(true)])]), generation: g) { [weak self] frame in
            guard let self, self.current == id else { return }
            var next = self.reducer; try next.apply(frame)
            guard next.sessionID == id else { throw NextError.protocolMismatch("错误会话快照") }
            self.reducer = next
            if frame["type"].text == "snapshot" {
                self.loaded.insert("follow"); self.applySelection(next.projections)
                if self.draft.workspace == .null, let w = self.workspaces.first(where: { $0["path"].text == next.cwd }) { var draft = self.draft; draft.workspace = w; try self.storeDraft(draft) }
            }
            self.reconcile(); self.checkReady()
        }
    }
    private func applySelection(_ projections: Wire) {
        let selection = projections["modelSelection"]["next"]
        if selection["model"].string != nil, selection != draft.model { var d = draft; d.model = selection; do { try storeDraft(d) } catch { report(error) } }
    }
    func refreshSessions() async throws {
        guard let client else { return }; let g = generation
        let result = try await client.rpc("session/list", args: .object(["_request": .object([:])]))
        guard g == generation else { return }
        sessions = result["items"].array.filter { $0["origin"].text != "subagent" }.sorted { ($0["updatedAt"].int ?? 0) > ($1["updatedAt"].int ?? 0) }
        running = Set(sessions.filter { liveStatuses[$0["sessionId"].text] ?? $0["running"].bool }.map { $0["sessionId"].text })
    }
    func search(_ query: String) async {
        searchGeneration += 1; let g = searchGeneration, connectionGeneration = generation
        guard !query.isEmpty else { searchResults = nil; searchHasMore = false; return }
        do { try await Task.sleep(for: .milliseconds(300)); guard g == searchGeneration else { return }
            let result = try await client?.command("session/search", .object(["query": .str(query)]))
            guard g == searchGeneration, connectionGeneration == generation else { return }; searchResults = result?["items"].array; searchHasMore = result?["hasMore"].bool ?? false
        } catch { if !Task.isCancelled { report(error) } }
    }
    func selectSession(_ id: String) { guard !busy, !id.isEmpty else { return }; current = id; local.lastSession = id; persist(); follow(generation: generation); ready = false; checkReady() }
    func newConversation(workspace: Wire? = nil, copyDraft: Bool = false) {
        guard !busy else { return }; let old = draft
        current = "draft-" + UUID().uuidString; var next = copyDraft ? old : NextDraft()
        next.workspace = workspace ?? old.workspace; next.model = old.model == .null ? catalog["default"] : old.model
        local.drafts[current] = next; local.lastSession = current; persist(); follow(generation: generation)
    }
    func chooseWorkspace(_ workspace: Wire) { if isDraft { var d = draft; d.workspace = workspace; do { try storeDraft(d) } catch { report(error) } } else { newConversation(workspace: workspace, copyDraft: true) } }
    func chooseModel(_ model: Wire) async {
        guard !modelLocked else { return }
        let selection: Wire = .object(["provider": model["provider"], "model": model["model"]])
        if isDraft { var d = draft; d.model = selection; do { try storeDraft(d) } catch { report(error) }; return }
        busy = true; defer { busy = false }
        do { let value = try await client?.command("session/selectModel", .object(selection.object.merging(["sessionId": .str(current)]) { _, b in b })); guard let selected = value?["selected"], selected["model"].string != nil else { throw NextError.protocolMismatch("模型选择回执") }; var d = draft; d.model = selected; try storeDraft(d) }
        catch { report(error) }
    }
    func saveReadPosition(_ id: String?) { guard let id, !isDraft else { return }; local.readPositions[current] = id; persist() }
    func editText(_ text: String) { var d = draft; d.text = text; d.revision += 1; local.drafts[current] = d; local.lastSession = current; persist() }
    func storeDraft(_ draft: NextDraft) throws { var next = local; next.drafts[current] = draft; next.lastSession = current; try save(next); local = next }
    private func save(_ next: NextLocalState) throws { guard let storage, let client else { throw NextError.storage }; try storage.save(next, origin: client.credential.origin) }
    private func persist() { do { try save(local) } catch { report(error) } }
    func send(voiceText: String? = nil) async {
        if let voiceText { editText(voiceText) }
        guard canSend, let client else { return }
        busy = true; defer { busy = false }; error = nil
        let g = generation, source = current, snapshot = draft, needsCreate = isDraft, id = isDraft ? UUID().uuidString : current
        var next = local; let send = next.stage(source: source, sessionID: id, draft: snapshot)
        do {
            try save(next); local = next; current = id
            if needsCreate {
                creating.insert(id); defer { creating.remove(id) }
                _ = try await client.command("session/create", .object(["sessionId": .str(id), "workspaceId": snapshot.workspace["workspaceId"]]))
            }
            guard g == generation else { throw NextError.disconnected }
            _ = try await client.command("session/selectModel", .object(snapshot.model.object.merging(["sessionId": .str(id)]) { _, b in b }))
            // Install the fixed app policy before admitting attachments or a prompt.
            // Repeating this command is idempotent; the server reviews later asks.
            let approval = try await client.rpc("commands/execute", args: .object(["agentId": .str(id), "line": .str(AutomaticApproval.command), "submittedAttachments": .array([])]))
            try AutomaticApproval.validate(approval)
            guard g == generation else { throw NextError.disconnected }
            var content: [Wire] = []
            if !snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { content.append(.object(["type": .str("text"), "text": .str(snapshot.text)])) }
            for attachment in snapshot.attachments {
                guard let storage else { throw NextError.storage }; let bytes = try storage.file(attachment)
                if let mime = attachment.mediaType, mime.hasPrefix("image/") {
                    content.append(.object(["type": .str("image"), "mediaType": .str(mime), "data": .str(bytes.base64EncodedString()), "name": .str(attachment.name)]))
                } else {
                    let receipt = try await client.upload(bytes, name: attachment.name, sessionID: id)
                    guard receipt["receiptId"].string != nil else { throw NextError.protocolMismatch("文件回执") }
                    content.append(.object(["type": .str("file"), "receiptId": receipt["receiptId"]]))
                }
            }
            guard g == generation else { throw NextError.disconnected }
            try updateSend(send.id, state: "submitting", content: content)
            follow(generation: g)
            _ = try await client.command("session/prompt", .object(["sessionId": .str(id), "requestId": .str(send.id), "mode": .str("queue"), "content": .array(content), "clientTimeZone": .str(TimeZone.current.identifier)]))
            guard g == generation else { throw NextError.disconnected }
            try updateSend(send.id, state: "accepted"); reconcile(); try await refreshSessions()
        } catch {
            try? updateSend(send.id, state: "uncertain"); report(error)
        }
    }
    private func updateSend(_ id: String, state: String, content: [Wire]? = nil) throws {
        guard let index = local.pending.firstIndex(where: { $0.id == id }) else { return }
        var next = local; next.pending[index].state = state; if let content { next.pending[index].content = content }; try save(next); local = next
    }
    private func reconcile() {
        let known = reducer.knownRequestIDs.union((queues[current] ?? []).compactMap { $0["rpcId"].string })
        guard local.pending.contains(where: { $0.sessionID == current && known.contains($0.id) }) else { return }
        var next = local; next.pending.removeAll { $0.sessionID == current && known.contains($0.id) }; do { try save(next); local = next } catch { report(error) }
    }
    func recoverPendingText(_ pending: PendingSend) { newConversation(workspace: pending.draft.workspace); var d = pending.draft; d.revision += 1; do { try storeDraft(d) } catch { report(error) } }
    func cancel() async {
        guard let client, !stopping, !isDraft else { return }; stopping = true
        do { _ = try await client.command("session/cancel", .object(["sessionId": .str(current)])) }
        catch { report(error); status = "停止结果待核对" }
    }
    func removeQueue(_ id: String) async {
        do { _ = try await client?.command("session/updateQueue", .object(["sessionId": .str(current), "itemId": .str(id), "action": .object(["kind": .str("remove")])])) } catch { report(error) }
    }
    func rename(_ id: String, to title: String) async {
        do { _ = try await client?.command("session/rename", .object(["sessionId": .str(id), "title": .str(title)])); try await refreshSessions() } catch { report(error) }
    }
    func loadOlder() async {
        guard reducer.hasMore, let before = reducer.events.compactMap({ $0["seq"].int }).min(), let client else { return }
        let id = current, cut = reducer.cursor
        do { let page = try await client.command("session/page", .object(["address": address(id), "throughSeq": .number(Double(cut)), "beforeSeq": .number(Double(before)), "maxMessages": .number(60)])); guard current == id else { return }; try reducer.prepend(page, throughSeq: cut) } catch { report(error) }
    }
    func importAttachment(data: Data, name: String, mediaType: String? = nil) {
        do { guard data.count <= 20 * 1024 * 1024 else { error = "每个附件当前支持最大 20 MB，请缩小后重试。"; return }; guard draft.attachments.count < 20 else { error = "每条消息最多添加 20 个附件。"; return }; guard let storage else { throw NextError.storage }; let file = try storage.importFile(data, name: name, mediaType: mediaType); var d = draft; d.attachments.append(file); d.revision += 1; try storeDraft(d) } catch { report(error) }
    }
    func removeAttachment(_ id: String) { var d = draft; d.attachments.removeAll { $0.id == id }; d.revision += 1; do { try storeDraft(d) } catch { report(error) } }
    func respond(_ prompt: Wire, value: Wire) async {
        guard let eventClientID, let client, prompts.contains(where: { $0["eventId"] == prompt["eventId"] }) else { return }
        let g = generation
        do { _ = try await client.rpc("$events/result", args: .object(["clientId": .str(eventClientID), "eventId": prompt["eventId"], "outcome": .object(["kind": .str("result"), "value": value])]))
            guard g == generation else { return }
            prompts.removeAll { $0["eventId"] == prompt["eventId"] }
        } catch { report(error) }
    }
    func disconnect() { do { try vault.clear(); suspend(); client?.shutdown(); client = nil; sessions = []; workspaces = []; catalog = .null; local = NextLocalState(); reducer = SessionReducer(); current = "draft-" + UUID().uuidString; error = nil; status = "未连接" } catch { report(error) } }
    func title(for session: Wire) -> String { (session["projections"] == .null ? sessions.first(where: { $0["sessionId"] == session["sessionId"] }) ?? session : session)["projections"]["values"]["title"].string ?? "新对话" }
    func report(_ error: Error) { self.error = (error as? NextError)?.localizedDescription ?? "操作未完成，请检查网络后重试。" }
    private func address(_ id: String) -> Wire { .object(["kind": .str("session"), "sessionId": .str(id)]) }
}
