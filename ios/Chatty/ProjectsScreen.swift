import SwiftUI
import ChattyCore

struct ProjectsScreen: View {
    let model: ProjectsModel
    let context: WorkspaceContext
    var onViewed: (Issue) -> Void = { _ in }
    var onChanged: (Issue) -> Void = { _ in }
    var discuss: ((Issue) -> Void)? = nil
    var body: some View {
        List {
            if let error = model.error { ErrorNotice(text: error, identifier: "projects.error") }
            if model.loading && model.projects.isEmpty { ProgressView("读取项目…") }
            ForEach(model.projects) { project in
                NavigationLink {
                    IssuesScreen(model: model, context: context, projectId: project.id, title: project.title, onViewed: onViewed, onChanged: onChanged, discuss: discuss)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "folder").foregroundStyle(ChattyTheme.accent).frame(width: 38, height: 38)
                            .background(ChattyTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(project.title).font(.body.weight(.medium))
                            if let description = project.description, !description.isEmpty { Text(description).font(.callout).foregroundStyle(.secondary).lineLimit(2) }
                        }
                    }.padding(.vertical, 10)
                }.accessibilityIdentifier("project.\(project.id)")
            }
            if model.projects.isEmpty && !model.loading && model.error == nil { ContentUnavailableView("还没有项目", systemImage: "folder") }
            NavigationLink {
                IssuesScreen(model: model, context: context, projectId: ProjectsModel.noProject, title: "未归属项目", onViewed: onViewed, onChanged: onChanged, discuss: discuss)
            } label: { Label("未归属项目", systemImage: "tray").padding(.vertical, 10) }.accessibilityIdentifier("projects.unassigned")
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(ChattyTheme.background)
        .accessibilityIdentifier("projects.list").navigationTitle("项目")
        .refreshable { await model.overview() }.task { if model.projects.isEmpty { await model.overview() } }
        .onForegroundRefresh { await model.overview() }
    }
}

struct IssuesScreen: View {
    let model: ProjectsModel
    let context: WorkspaceContext
    let projectId: String
    let title: String
    var onViewed: (Issue) -> Void = { _ in }
    var onChanged: (Issue) -> Void = { _ in }
    var discuss: ((Issue) -> Void)? = nil
    @State private var query = ""
    @State private var status: String?
    private var searchKey: String { "\(projectId)|\(query)|\(status ?? "")" }
    var body: some View {
        List {
            Section {
                if let error = model.error { ErrorNotice(text: error, identifier: "issues.error") }
                if model.loading && model.issues.isEmpty { ProgressView("读取事项…") }
                if !model.loading && model.issues.isEmpty && model.error == nil { ContentUnavailableView("没有符合条件的事项", systemImage: "checklist") }
                ForEach(model.issues) { issue in
                    NavigationLink {
                        IssueScreen(model: model, context: context, issueId: issue.id, onViewed: onViewed, onChanged: onChanged, discuss: discuss)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text(issue.title).font(.body).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Text(model.statusName(issue.status)).font(.caption).foregroundStyle(ChattyTheme.accent)
                        }.padding(.vertical, 10)
                    }.accessibilityIdentifier("issue.\(issue.id)")
                }
                if model.offset < model.total && !model.loading {
                    Button { Task { await model.more() } } label: {
                        Group { if model.loadingMore { ProgressView() } else { Text("加载更多") } }.frame(maxWidth: .infinity, minHeight: 44)
                    }.disabled(model.loadingMore).accessibilityIdentifier("issues.more")
                }
            } header: { Text("全部事项 · 包含所有发起人").textCase(nil) }
        }
        .listStyle(.plain).scrollContentBackground(.hidden).background(ChattyTheme.background)
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "搜索事项").autocorrectionDisabled()
        .toolbar {
            Menu {
                Button("全部状态") { status = nil }
                ForEach(model.statuses) { entry in Button(entry.name) { status = entry.key } }
            } label: { Label("筛选状态", systemImage: "line.3.horizontal.decrease") }.accessibilityIdentifier("issues.filter")
        }
        .refreshable { await model.loadIssues(project: projectId, query: query, status: status) }
        .onForegroundRefresh { await model.loadIssues(project: projectId, query: query, status: status) }
        .task(id: searchKey) {
            if !query.isEmpty { do { try await Task.sleep(for: .milliseconds(250)) } catch { return } }
            await model.loadIssues(project: projectId, query: query, status: status)
        }
    }
}

struct IssueScreen: View {
    let model: ProjectsModel
    let context: WorkspaceContext
    let issueId: String
    var onViewed: (Issue) -> Void = { _ in }
    var onChanged: (Issue) -> Void = { _ in }
    var discuss: ((Issue) -> Void)? = nil
    @State private var selectedStatus = ""
    @State private var expanded = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if model.loadingDetail { ProgressView("读取最新详情…").frame(maxWidth: .infinity) }
                if let error = model.detailError {
                    ErrorNotice(text: error, identifier: "issue.error")
                    Button("重新读取") { Task { await reload() } }.frame(minHeight: 44).accessibilityIdentifier("issue.reload")
                }
                if let issue = model.detail, issue.id == issueId || issue.identifier == issueId {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(model.projects.first { $0.id == issue.projectId }?.title ?? "未归属项目").font(.caption).foregroundStyle(.secondary)
                        Text(issue.title).font(.title2.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                        Text(model.statusName(issue.status)).font(.callout).foregroundStyle(ChattyTheme.accent).accessibilityIdentifier("issue.currentStatus")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("现在的情况").font(.caption).foregroundStyle(.secondary)
                        Text(summary(issue)).font(.body)
                        if let date = parsedDate(issue.lastActivityAt ?? issue.updatedAt) { Text(date, style: .relative).font(.caption).foregroundStyle(.secondary) }
                    }.padding(.top, 6)
                    if model.category(issue) == "in_review", let done = model.doneStatus {
                        Button { Task { await updateStatus(done) } } label: { Text(model.saving ? "正在提交…" : "验收通过").frame(maxWidth: .infinity, minHeight: 44) }
                            .buttonStyle(.borderedProminent).disabled(model.saving || model.loadingDetail || model.detailError != nil).accessibilityIdentifier("issue.approve")
                    }
                    if let discuss {
                        Button { discuss(issue) } label: { Label(model.category(issue) == "in_review" ? "有修改意见，和 Mika 说" : "和 Mika 继续", systemImage: "sparkles").frame(maxWidth: .infinity, minHeight: 44) }
                            .buttonStyle(.bordered).accessibilityIdentifier("issue.discuss")
                    }
                    DisclosureGroup("目标与记录", isExpanded: $expanded) {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(issue.identifier).font(.caption).foregroundStyle(.secondary)
                            if let description = issue.description, !description.isEmpty { RichContentView(source: description, context: context) }
                            else { Text("暂无描述。").foregroundStyle(.secondary) }
                            if let creator = issue.creatorId { LabeledContent("发起人", value: creator == context.user.id ? "你" : issue.creatorType == "agent" ? "Agent" : "项目成员").font(.callout) }
                            if let priority = issue.priority, priority != "none" { LabeledContent("优先级", value: priority).font(.callout) }
                            if let error = model.catalogError { Text(error).font(.footnote).foregroundStyle(.secondary) }
                            Menu {
                                ForEach(model.statuses) { entry in Button(entry.name) { selectedStatus = entry.key } }
                            } label: { Label(selectedStatus.isEmpty ? "更改状态" : model.statusName(selectedStatus), systemImage: "chevron.up.chevron.down").frame(minHeight: 44) }
                                .disabled(model.saving || model.loadingDetail || model.detailError != nil || model.statuses.isEmpty).accessibilityIdentifier("issue.status")
                            if !selectedStatus.isEmpty && selectedStatus != issue.status {
                                Button("保存状态") { Task { await updateStatus(selectedStatus) } }.buttonStyle(.borderedProminent).disabled(model.saving || model.detailError != nil).frame(minHeight: 44).accessibilityIdentifier("issue.save")
                            }
                            if expanded {
                                timeline(issue)
                            }
                        }.padding(.top, 18)
                    }.font(.callout).accessibilityIdentifier("issue.records")
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ChattyTheme.background).navigationTitle("事项").navigationBarTitleDisplayMode(.inline)
        .refreshable { await reload() }.onForegroundRefresh { await reload() }
        .task(id: issueId) { await reload() }
    }
    private func reload() async {
        selectedStatus = ""
        if model.statuses.isEmpty { await model.overview() }
        await model.loadDetail(id: issueId)
        if model.detailError == nil, let row = model.detail, row.id == issueId || row.identifier == issueId { onViewed(row) }
    }
    private func updateStatus(_ status: String) async {
        await model.changeStatus(status); selectedStatus = ""
        if model.detailError == nil, let row = model.detail, row.status == status { onChanged(row) }
    }
    private func summary(_ issue: Issue) -> String {
        switch model.category(issue) {
        case "in_review": "事项已进入审核。确认交付符合预期后，可以完成验收。"
        case "blocked": "事项当前受阻，可以向 Mika 补充信息或确认下一步。"
        case "done": "事项已经完成。"
        case "in_progress": "事项正在推进，新的变化会显示在动态里。"
        default: "当前状态：\(model.statusName(issue.status))。"
        }
    }
    private func timeline(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.loadingTimeline { ProgressView("读取记录…") }
            if let error = model.timelineError { Text(error).font(.footnote).foregroundStyle(.secondary) }
            ForEach(model.timeline) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    if let date = parsedDate(entry.createdAt) { Text(date, style: .relative).font(.caption).foregroundStyle(.secondary) }
                    if let content = entry.content, !content.isEmpty { RichContentView(source: content, context: context) }
                    else { Text(["created":"创建事项", "status_changed":"更新状态", "updated":"更新事项", "assigned":"分配负责人"][entry.action ?? ""] ?? "事项有了新变化").font(.callout) }
                }
            }
        }.task(id: issue.id) { await model.loadTimeline(id: issue.id) }
    }
}
