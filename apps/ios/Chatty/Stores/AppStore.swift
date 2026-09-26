import Foundation
import Observation

/// 应用状态。原型阶段用脚本模拟 Agent 的一轮执行；接入 Runner 后，这里改为消费 Runner 推送的事件。
@MainActor
@Observable
final class AppStore {
    var harnesses: [HarnessInfo]
    var agents: [AgentConfig]
    var repos: [String]
    var sessions: [ChatSession]
    var runner: RunnerInfo

    /// nil 表示“新会话”空状态
    var currentSessionID: UUID?
    /// 新会话使用的 Agent
    var draftAgentID: UUID?
    var draft: String = ""
    var permissionMode: PermissionMode = .ask
    /// 每次时间线变化时递增，视图据此滚动到底部
    private(set) var timelineRevision = 0

    /// 模拟一轮执行时每一步的间隔（毫秒）。测试中设为 0。
    var stepDelayMilliseconds = 450

    @ObservationIgnored private var runningTasks: [UUID: Task<Void, Never>] = [:]

    init(
        harnesses: [HarnessInfo] = DemoData.harnesses(),
        agents: [AgentConfig] = DemoData.agents(),
        repos: [String] = DemoData.repos(),
        sessions: [ChatSession] = DemoData.sessions(),
        runner: RunnerInfo = DemoData.runner()
    ) {
        self.harnesses = harnesses
        self.agents = agents
        self.repos = repos
        self.sessions = sessions
        self.runner = runner
        self.draftAgentID = agents.first?.id
    }

    // MARK: - 查询

    var currentSession: ChatSession? {
        guard let currentSessionID else { return nil }
        return sessions.first { $0.id == currentSessionID }
    }

    var draftAgent: AgentConfig? {
        agents.first { $0.id == draftAgentID } ?? agents.first
    }

    var runningCount: Int {
        sessions.filter { $0.state != .idle }.count
    }

    func harness(_ id: String) -> HarnessInfo? {
        harnesses.first { $0.id == id }
    }

    func modelName(harnessID: String, modelID: String) -> String {
        harness(harnessID)?.model(modelID)?.name ?? modelID
    }

    /// 顶部标题与列表副标题：「Harness · Model」
    func engineLabel(harnessID: String, modelID: String) -> String {
        let harnessName = harness(harnessID)?.name ?? harnessID
        return "\(harnessName) · \(modelName(harnessID: harnessID, modelID: modelID))"
    }

    /// 抽屉中按仓库分组，组内按更新时间倒序
    func groupedSessions(matching query: String) -> [SessionGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let filtered = sessions.filter { trimmed.isEmpty || $0.title.localizedCaseInsensitiveContains(trimmed) }
        let groups = Dictionary(grouping: filtered) { $0.repo }
        return groups
            .map { repo, members in
                SessionGroup(repo: repo, sessions: members.sorted { $0.updatedAt > $1.updatedAt })
            }
            .sorted { ($0.sessions.first?.updatedAt ?? .distantPast) > ($1.sessions.first?.updatedAt ?? .distantPast) }
    }

    // MARK: - 会话管理

    func startNewSession() {
        currentSessionID = nil
        draft = ""
    }

    func select(_ sessionID: UUID) {
        currentSessionID = sessionID
        bumpTimeline()
    }

    func delete(_ sessionID: UUID) {
        runningTasks[sessionID]?.cancel()
        runningTasks[sessionID] = nil
        sessions.removeAll { $0.id == sessionID }
        if currentSessionID == sessionID {
            currentSessionID = nil
        }
    }

    // MARK: - 对话

    func send(_ rawText: String? = nil) {
        let text = (rawText ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let sessionID: UUID
        if let current = currentSession {
            guard current.state == .idle else { return }
            sessionID = current.id
        } else {
            guard let agent = draftAgent else { return }
            let session = ChatSession(
                title: String(text.prefix(20)),
                repo: agent.repo,
                harnessID: agent.harnessID,
                modelID: agent.modelID
            )
            sessions.insert(session, at: 0)
            sessionID = session.id
            currentSessionID = sessionID
        }

        draft = ""
        mutate(sessionID) {
            $0.items.append(.user(text))
            $0.state = .running
        }
        runningTasks[sessionID] = Task { [weak self] in
            await self?.runFirstHalf(sessionID: sessionID)
        }
    }

    func stop() {
        guard let session = currentSession, session.state != .idle else { return }
        runningTasks[session.id]?.cancel()
        runningTasks[session.id] = nil
        mutate(session.id) {
            for index in $0.items.indices where $0.items[index].isRunning {
                $0.items[index].isRunning = false
            }
            $0.approval = nil
            $0.state = .idle
            $0.items.append(.notice("已停止"))
        }
    }

    func respond(_ decision: ApprovalDecision) {
        guard let session = currentSession, let approval = session.approval else { return }
        let approved: Bool
        switch decision {
        case .approve, .approveForSession:
            approved = true
        case .reject, .rejectWithNote:
            approved = false
        }
        mutate(session.id) {
            $0.approval = nil
            $0.state = .running
            if decision == .approveForSession {
                $0.items.append(.notice("本次会话后续命令将自动允许"))
            }
            if !approved {
                $0.items.append(.notice("已拒绝：\(approval.command)"))
            }
        }
        if decision == .rejectWithNote {
            draft = "不要执行这个命令，原因是："
        }
        runningTasks[session.id] = Task { [weak self] in
            await self?.runSecondHalf(sessionID: session.id, approved: approved)
        }
    }

    /// 切换 Harness 或 Model。切换 Harness 时插入摘要迁移提示。
    func switchEngine(harnessID: String, modelID: String) {
        guard let session = currentSession else { return }
        let harnessChanged = session.harnessID != harnessID
        let modelChanged = session.modelID != modelID
        guard harnessChanged || modelChanged else { return }
        mutate(session.id) {
            $0.harnessID = harnessID
            $0.modelID = modelID
            if harnessChanged {
                $0.items.append(.notice("已切换引擎，上下文已通过摘要迁移"))
            } else {
                $0.items.append(.notice("已切换模型为 \(self.modelName(harnessID: harnessID, modelID: modelID))"))
            }
        }
    }

    // MARK: - Agent 管理

    func addAgent() -> AgentConfig {
        let harness = harnesses.first { $0.isAvailable }
        let agent = AgentConfig(
            id: UUID(),
            name: "新 Agent",
            harnessID: harness?.id ?? "",
            modelID: harness?.defaultModelID ?? "",
            repo: repos.first ?? ""
        )
        agents.append(agent)
        return agent
    }

    func deleteAgents(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            agents.remove(at: index)
        }
        if !agents.contains(where: { $0.id == draftAgentID }) {
            draftAgentID = agents.first?.id
        }
    }

    // MARK: - 模拟执行脚本

    private func runFirstHalf(sessionID: UUID) async {
        let toolsItem = TimelineItem.tools([], running: true)
        mutate(sessionID) { $0.items.append(toolsItem) }

        let steps = [
            ToolStep(icon: "folder", title: "读取项目结构"),
            ToolStep(icon: "magnifyingglass", title: "搜索相关代码"),
            ToolStep(icon: "doc.text", title: "读取 src/app.ts"),
            ToolStep(icon: "pencil", title: "编辑 src/app.ts"),
        ]
        for step in steps {
            guard await pause() else { return }
            mutateItem(sessionID, toolsItem.id) { $0.steps.append(step) }
        }
        mutateItem(sessionID, toolsItem.id) { $0.isRunning = false }

        guard await stream("我已经完成修改，接下来想运行测试确认没有回归。", into: sessionID) else { return }
        guard await pause() else { return }

        if permissionMode == .plan {
            mutate(sessionID) {
                $0.items.append(.notice("只规划模式：不会执行命令"))
                $0.state = .idle
            }
            runningTasks[sessionID] = nil
            return
        }
        mutate(sessionID) {
            $0.approval = ApprovalRequest(title: "请求执行命令", command: "npm test")
            $0.state = .awaitingApproval
        }
        runningTasks[sessionID] = nil
    }

    private func runSecondHalf(sessionID: UUID, approved: Bool) async {
        if approved {
            let toolsItem = TimelineItem.tools([], running: true)
            mutate(sessionID) { $0.items.append(toolsItem) }
            guard await pause() else { return }
            mutateItem(sessionID, toolsItem.id) {
                $0.steps.append(ToolStep(icon: "terminal", title: "运行 npm test：42 个通过"))
                $0.isRunning = false
            }
            guard await stream("测试全部通过。", into: sessionID) else { return }
        } else {
            guard await stream("好的，我不运行这个命令。改动已经完成，你可以稍后自己验证。", into: sessionID) else { return }
        }
        mutate(sessionID) {
            $0.items.append(.changes([
                FileChange(path: "src/app.ts", added: 12, removed: 3),
                FileChange(path: "test/app.test.ts", added: 20, removed: 0),
            ]))
            $0.state = .idle
        }
        runningTasks[sessionID] = nil
    }

    /// 逐段追加文本，模拟流式输出。被取消时返回 false。
    private func stream(_ text: String, into sessionID: UUID) async -> Bool {
        let item = TimelineItem.agent("")
        mutate(sessionID) { $0.items.append(item) }
        var remaining = Substring(text)
        while !remaining.isEmpty {
            let chunk = remaining.prefix(3)
            remaining = remaining.dropFirst(chunk.count)
            guard await pause(scale: 0.08) else { return false }
            mutateItem(sessionID, item.id) { $0.text += chunk }
        }
        return true
    }

    private func pause(scale: Double = 1) async -> Bool {
        let milliseconds = Int(Double(stepDelayMilliseconds) * scale)
        if milliseconds > 0 {
            try? await Task.sleep(for: .milliseconds(milliseconds))
        }
        return !Task.isCancelled
    }

    /// 等待某个会话当前的模拟执行结束。供测试使用。
    func waitForRunningTask(_ sessionID: UUID) async {
        await runningTasks[sessionID]?.value
    }

    // MARK: - 修改辅助

    private func mutate(_ sessionID: UUID, _ change: (inout ChatSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        change(&sessions[index])
        sessions[index].updatedAt = .now
        bumpTimeline()
    }

    private func mutateItem(_ sessionID: UUID, _ itemID: UUID, _ change: (inout TimelineItem) -> Void) {
        mutate(sessionID) { session in
            guard let index = session.items.firstIndex(where: { $0.id == itemID }) else { return }
            change(&session.items[index])
        }
    }

    private func bumpTimeline() {
        timelineRevision &+= 1
    }
}
