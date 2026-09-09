import Foundation
import Observation

@MainActor @Observable public final class ProjectsModel {
    public static let noProject = "__none__"
    public private(set) var projects: [Project] = []
    public private(set) var statuses: [IssueStatus] = []
    public private(set) var issues: [Issue] = []
    public private(set) var total = 0
    public private(set) var offset = 0
    public private(set) var loading = false
    public private(set) var loadingMore = false
    public private(set) var loadingDetail = false
    public private(set) var saving = false
    public private(set) var detail: Issue?
    public private(set) var error: String?
    public private(set) var detailError: String?
    public private(set) var catalogError: String?
    public private(set) var selectedProject: String?
    public private(set) var query = ""
    public private(set) var filter: String?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var detailGeneration = 0
    @ObservationIgnored private let context: WorkspaceContext
    init(context: WorkspaceContext) { self.context = context }

    public func statusName(_ key: String) -> String { statuses.first(where: { $0.key == key })?.name ?? DisplayText.status(key) }
    public func overview() async {
        guard context.active else { return }
        let g = generation + 1; generation = g; loading = true; error = nil
        defer { if g == generation { loading = false } }
        do {
            let page: ProjectPage = try await context.api.get("/api/projects"); try context.check()
            guard g == generation else { return }; projects = page.projects
            do {
                let catalog: StatusCatalog = try await context.api.get("/api/issue-statuses"); try context.check()
                guard g == generation else { return }
                statuses = catalog.statuses.filter { $0.archivedAt == nil }; catalogError = nil
            } catch {
                guard g == generation else { return }; statuses = []
                catalogError = await context.report(error).map { _ in "状态目录暂不可用，状态修改已暂停。" }
            }
        } catch { if g == generation { self.error = await context.report(error) } }
    }
    public func loadIssues(project: String, query: String = "", status: String? = nil) async {
        guard context.active else { return }
        generation += 1; let g = generation
        selectedProject = project; self.query = query; filter = status
        issues = []; offset = 0; total = 0; loading = true; loadingMore = false; error = nil
        defer { if g == generation { loading = false } }
        do {
            let page: IssuePage = try await context.api.get("/api/issues", query: parameters(offset: 0))
            try context.check(); guard g == generation else { return }
            issues = Self.unique(page.issues); total = page.total; offset = page.issues.isEmpty ? page.total : page.issues.count
        } catch { if g == generation { self.error = await context.report(error) } }
    }
    public func more() async {
        guard context.active, !loading, !loadingMore, offset < total, selectedProject != nil else { return }
        let g = generation; let start = offset; loadingMore = true
        defer { if g == generation { loadingMore = false } }
        do {
            let page: IssuePage = try await context.api.get("/api/issues", query: parameters(offset: start))
            try context.check(); guard g == generation else { return }
            issues = Self.unique(issues + page.issues); total = page.total; offset = page.issues.isEmpty ? page.total : start + page.issues.count
        } catch { if g == generation { self.error = await context.report(error) } }
    }
    private static func unique(_ rows: [Issue]) -> [Issue] {
        var seen = Set<String>(); return rows.filter { seen.insert($0.id).inserted }
    }
    private func parameters(offset: Int) -> [URLQueryItem] {
        var values: [URLQueryItem] = [.init(name: "limit", value: "50"), .init(name: "offset", value: String(offset))]
        if selectedProject == Self.noProject { values.append(.init(name: "include_no_project", value: "true")) }
        else { values.append(.init(name: "project_id", value: selectedProject)) }
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { values.append(.init(name: "q", value: query.trimmingCharacters(in: .whitespacesAndNewlines))) }
        if let filter { values.append(.init(name: "status", value: filter)) }
        return values
    }
    public func loadDetail(id: String) async {
        guard context.active, !saving else { return }
        detailGeneration += 1; let g = detailGeneration
        detail = nil; loadingDetail = true; detailError = nil
        defer { if g == detailGeneration { loadingDetail = false } }
        do {
            let row: Issue = try await context.api.get("/api/issues/\(APIClient.segment(id))")
            try context.check(); guard g == detailGeneration else { return }; detail = row
        } catch { if g == detailGeneration { detailError = await context.report(error) } }
    }
    public func changeStatus(_ key: String) async {
        guard context.active, !saving, !loadingDetail, detailError == nil, let row = detail,
              row.status != key, statuses.contains(where: { $0.key == key }) else { return }
        let g = detailGeneration; saving = true; detailError = nil
        defer { saving = false }
        do {
            var body: [String: JSONValue] = ["status": .string(key), "suppress_run": .bool(true)]
            if let revision = row.revision { body["expected_revision"] = .number(Double(revision)) }
            let updated: Issue = try await context.api.write("/api/issues/\(APIClient.segment(row.id))", method: "PUT", body: body)
            try context.check(); guard g == detailGeneration else { return }; detail = updated
            issues = issues.map { $0.id == updated.id ? updated : $0 }.filter { filter == nil || $0.status == filter }
            do {
                let fresh: Issue = try await context.api.get("/api/issues/\(APIClient.segment(row.id))")
                let page: ProjectPage = try await context.api.get("/api/projects"); try context.check()
                guard g == detailGeneration else { return }; detail = fresh; projects = page.projects
                if let selectedProject { await loadIssues(project: selectedProject, query: query, status: filter) }
            } catch {
                _ = await context.report(error)
                if context.active { detailError = "状态已提交，但刷新未完成。请重新读取核对，避免重复提交。" }
            }
        } catch {
            guard g == detailGeneration, context.active else { return }
            let message = await context.report(error)
            if let message { detailError = message + " 请重新读取核对，避免重复提交。" }
            if error as? APIError == .http(409) {
                do {
                    let fresh: Issue = try await context.api.get("/api/issues/\(APIClient.segment(row.id))"); try context.check()
                    if g == detailGeneration { detail = fresh; detailError = "他人已更新此 Issue，当前显示最新状态。请先重新读取，再决定修改。" }
                } catch { }
            }
        }
    }
}
