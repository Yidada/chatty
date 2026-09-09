import Foundation
import Observation

@MainActor @Observable public final class SessionModel {
    public private(set) var restoring = true
    public private(set) var busy = false
    public private(set) var codeSent = false
    public private(set) var authenticated = false
    public private(set) var workspaces: [Workspace] = []
    public private(set) var user: User?
    public private(set) var current: WorkspaceModel?
    public private(set) var error: String?
    public private(set) var recoveryScope: DraftRecoveryScope?
    public private(set) var recoveryDraft = DraftRecord()
    public var email = ""
    public var code = ""
    public let baseURL: URL
    @ObservationIgnored private let vault: any CredentialVault
    @ObservationIgnored private let files: ProtectedStorage
    @ObservationIgnored private let factory: @Sendable (URL, String?, String?) -> APIClient
    @ObservationIgnored private var api: APIClient
    @ObservationIgnored private var generation = 0

    public init(baseURL: URL, vault: any CredentialVault, files: ProtectedStorage,
                factory: @escaping @Sendable (URL, String?, String?) -> APIClient = { APIClient(baseURL: $0, token: $1, workspace: $2) }) {
        self.baseURL = baseURL; self.vault = vault; self.files = files; self.factory = factory
        self.api = factory(baseURL, nil, nil)
    }
    public func restore() async {
        guard restoring else { return }
        defer { restoring = false }
        do {
            if let token = try vault.read(), !token.isEmpty {
                api.invalidate(); api = factory(baseURL, token, nil); authenticated = true
                await loadAccount()
            }
        } catch { self.error = error.localizedDescription }
    }
    public func changeEmail() {
        generation += 1; api.invalidate(); api = factory(baseURL, nil, nil)
        codeSent = false; code = ""; busy = false; error = nil
    }
    public func sendCode() async {
        guard !busy else { return }
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.contains("@"), address.count <= 254 else { error = "请输入有效邮箱。"; return }
        let g = generation; busy = true; error = nil
        defer { if g == generation { busy = false } }
        do {
            _ = try await api.data("/auth/send-code", method: "POST", body: ["email": .string(address)])
            guard g == generation else { return }
            email = address; codeSent = true
        } catch { if g == generation { self.error = DisplayText.error(error) } }
    }
    public func verify() async {
        guard !busy else { return }
        guard code.count == 6, code.allSatisfy({ $0.isASCII && $0.isNumber }) else { error = "请输入六位验证码。"; return }
        let g = generation; busy = true; error = nil
        defer { if g == generation { busy = false } }
        do {
            struct Login: Decodable, Sendable { let token: String }
            let login: Login = try await api.write("/auth/verify-code", body: ["email": .string(email), "code": .string(code)])
            guard g == generation else { return }
            guard !login.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.invalidCredential }
            try vault.save(login.token)
            code = ""; api.invalidate(); api = factory(baseURL, login.token, nil); authenticated = true
            await loadAccount()
        } catch { if g == generation { self.error = DisplayText.error(error) } }
    }
    public func loadAccount() async {
        let g = generation; let client = api
        busy = true; error = nil
        defer { if g == generation { busy = false } }
        do {
            async let personRequest: User = client.get("/api/me")
            async let listRequest: [Workspace] = client.get("/api/workspaces")
            let (person, list) = try await (personRequest, listRequest)
            guard g == generation else { return }
            recoveryScope = nil; recoveryDraft = DraftRecord()
            user = person; workspaces = list
            if current == nil, let id = try files.lastWorkspace(account: person.id), let workspace = list.first(where: { $0.id == id }) {
                select(workspace)
            }
        } catch {
            await handle(error, generation: g)
            guard g == generation, authenticated, current == nil, let token = api.token else { return }
            let status = (error as? APIError)
            let transient: Bool
            if case .http(let code) = status { transient = code >= 500 } else { transient = error is URLError }
            if transient {
                do {
                    recoveryScope = try files.recovery(token: token)
                    if let scope = recoveryScope { recoveryDraft = try files.draft(account: scope.accountId, workspace: scope.workspace.id, agent: scope.agentId) }
                } catch { self.error = "暂时无法读取本机草稿，请解锁设备后重试。" }
            }
        }
    }
    public func rememberDraftScope(_ workspace: WorkspaceModel) {
        guard current?.id == workspace.id, let agent = workspace.chat.agent, let token = api.token else { return }
        do { try files.rememberRecovery(token: token, account: workspace.context.user.id, workspace: workspace.context.workspace, agent: agent.id) }
        catch { self.error = "本机离线恢复信息未能保存，请解锁设备后重试。" }
    }
    public func setRecoveryDraft(_ text: String) {
        guard let scope = recoveryScope, current == nil else { return }
        recoveryDraft.text = String(text.prefix(100_000))
        do { try files.saveDraft(recoveryDraft, account: scope.accountId, workspace: scope.workspace.id, agent: scope.agentId) }
        catch { self.error = "草稿暂时无法保存，请保持应用打开后重试。" }
    }
    public func select(_ workspace: Workspace) {
        guard let user, let token = api.token, workspaces.contains(where: { $0.id == workspace.id }) else { return }
        current?.invalidate(); current = nil; generation += 1; busy = false; error = nil; recoveryScope = nil
        do {
            try files.clearPreviews(); try files.saveWorkspace(workspace.id, account: user.id)
            let client = factory(baseURL, token, workspace.slug)
            let g = generation
            current = WorkspaceModel(workspace: workspace, user: user, api: client, files: files) { [weak self] error in
                await self?.handle(error, generation: g)
            }
        } catch { self.error = error.localizedDescription }
    }
    public func switchWorkspace() {
        current?.invalidate(); current = nil; generation += 1
        do { try files.clearPreviews() } catch { self.error = error.localizedDescription }
    }
    public func signOut() {
        generation += 1; current?.invalidate(); current = nil; api.invalidate()
        recoveryScope = nil; recoveryDraft = DraftRecord()
        authenticated = false; user = nil; workspaces = []; busy = false; codeSent = false; code = ""; email = ""
        api = factory(baseURL, nil, nil)
        var cleared = true
        do { try vault.save(nil) } catch { cleared = false }
        do { try files.clearAll() } catch { cleared = false }
        error = cleared ? nil : "已停止当前会话，但本机安全数据未完全清理，请解锁设备后再次退出。"
    }
    private func handle(_ error: Error, generation g: Int) async {
        guard g == generation else { return }
        if error as? APIError == .http(401) { signOut(); self.error = DisplayText.error(error) }
        else if !(error is CancellationError), (error as? URLError)?.code != .cancelled { self.error = DisplayText.error(error) }
    }
}
