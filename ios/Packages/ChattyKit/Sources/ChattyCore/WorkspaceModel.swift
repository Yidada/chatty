import Foundation
import Observation

@MainActor public final class WorkspaceContext {
    public let workspace: Workspace
    public let user: User
    public let api: APIClient
    public let files: ProtectedStorage
    public private(set) var active = true
    private let onFailure: @MainActor (Error) async -> Void
    init(workspace: Workspace, user: User, api: APIClient, files: ProtectedStorage, onFailure: @escaping @MainActor (Error) async -> Void) {
        self.workspace = workspace; self.user = user; self.api = api; self.files = files; self.onFailure = onFailure
    }
    public func check() throws { try Task.checkCancellation(); if !active { throw CancellationError() } }
    public func report(_ error: Error) async -> String? {
        guard active, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return nil }
        if error as? APIError == .http(401) { await onFailure(error); return nil }
        return DisplayText.error(error)
    }
    func invalidate() { active = false; api.invalidate() }
}

@MainActor @Observable public final class WorkspaceModel: Identifiable {
    public let id = UUID()
    public let context: WorkspaceContext
    public let chat: ChatModel
    public let projects: ProjectsModel
    public let resources: ResourcesModel
    init(workspace: Workspace, user: User, api: APIClient, files: ProtectedStorage, onFailure: @escaping @MainActor (Error) async -> Void) {
        context = WorkspaceContext(workspace: workspace, user: user, api: api, files: files, onFailure: onFailure)
        chat = ChatModel(context: context); projects = ProjectsModel(context: context); resources = ResourcesModel(context: context)
    }
    public func start() { chat.start() }
    public func pause() { chat.stop() }
    public func invalidate() { chat.stop(); context.invalidate() }
}

@MainActor @Observable public final class ResourcesModel {
    public private(set) var runtimes: [RuntimeDevice] = []
    public private(set) var agents: [ChatAgent] = []
    public private(set) var squads: [Squad] = []
    public private(set) var loading = false
    public private(set) var error: String?
    @ObservationIgnored private let context: WorkspaceContext
    init(context: WorkspaceContext) { self.context = context }
    public func refresh() async {
        guard !loading, context.active else { return }
        loading = true; error = nil; defer { loading = false }
        do {
            async let runtimes: [RuntimeDevice] = context.api.get("/api/runtimes")
            async let agents: [ChatAgent] = context.api.get("/api/agents")
            async let squads: [Squad] = context.api.get("/api/squads")
            let values = try await (runtimes, agents, squads); try context.check()
            self.runtimes = values.0; self.agents = values.1.filter { $0.archivedAt == nil }; self.squads = values.2.filter { $0.archivedAt == nil }
        } catch { self.error = await context.report(error) }
    }
}
