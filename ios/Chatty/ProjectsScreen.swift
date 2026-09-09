import SwiftUI
import ChattyCore

struct ProjectsScreen: View {
    let model: ProjectsModel
    let context: WorkspaceContext
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("所有项目，一眼看清进度。").font(.callout).foregroundStyle(.secondary)
                if let error = model.error { ErrorNotice(text: error, identifier: "projects.error") }
                if let error = model.catalogError { ErrorNotice(text: error) }
                if model.loading && model.projects.isEmpty { ProgressView("读取项目…").frame(maxWidth: .infinity) }
                if !model.loading && model.projects.isEmpty && model.error == nil { ContentUnavailableView("还没有项目", systemImage: "folder", description: Text("可以先查看未归属项目的 Issues。")) }
                ForEach(model.projects) { project in
                    NavigationLink { IssuesScreen(model: model, context: context, projectId: project.id, title: project.title) } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack { Label(project.title, systemImage: "folder").font(.headline); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                            if let description = project.description, !description.isEmpty { Text(description).font(.callout).foregroundStyle(.secondary).lineLimit(3) }
                            ProgressView(value: project.progress)
                            HStack { Text("\(project.doneCount ?? 0) / \(project.issueCount ?? 0) 已完成"); Spacer(); Text(project.progress, format: .percent.precision(.fractionLength(0))) }.font(.callout).foregroundStyle(.secondary)
                        }.padding(20).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(.plain).accessibilityIdentifier("project.\(project.id)")
                }
                NavigationLink { IssuesScreen(model: model, context: context, projectId: ProjectsModel.noProject, title: "未归属项目") } label: {
                    Label("未归属项目的 Issues", systemImage: "tray").frame(maxWidth: .infinity, alignment: .leading).padding(20).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain).accessibilityIdentifier("projects.unassigned")
            }.padding(20)
        }
        .accessibilityIdentifier("projects.list").navigationTitle("项目").background(ChattyTheme.background)
        .refreshable { await model.overview() }.task { await model.overview() }
        .onForegroundRefresh { await model.overview() }
        .toolbar { Button("刷新", systemImage: "arrow.clockwise") { Task { await model.overview() } }.accessibilityIdentifier("projects.refresh") }
    }
}

struct IssuesScreen: View {
    let model: ProjectsModel
    let context: WorkspaceContext
    let projectId: String
    let title: String
    @State private var query = ""
    @State private var status: String?
    private var searchKey: String { "\(projectId)|\(query)|\(status ?? "")" }
    var body: some View {
        List {
            Section {
                HStack {
                    Text("已加载 \(model.issues.count) / \(model.total)").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("issues.count")
                    Spacer()
                    Menu {
                        Button("全部状态") { status = nil }
                        ForEach(model.statuses) { entry in Button(entry.name) { status = entry.key } }
                    } label: { Label(status.map(model.statusName) ?? "全部状态", systemImage: "line.3.horizontal.decrease").font(.callout).frame(minHeight: 44) }
                    .accessibilityIdentifier("issues.filter")
                }
            }
            if let error = model.error { ErrorNotice(text: error, identifier: "issues.error") }
            if model.loading { ProgressView("读取 Issues…") }
            else if model.issues.isEmpty { ContentUnavailableView("没有符合条件的 Issue", systemImage: "checklist", description: Text("可以调整搜索或状态筛选。")) }
            ForEach(model.issues) { issue in
                NavigationLink { IssueScreen(model: model, context: context, issueId: issue.id) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text(issue.identifier).font(.caption).foregroundStyle(.secondary); Spacer(); Text(model.statusName(issue.status)).font(.caption).foregroundStyle(ChattyTheme.accent) }
                        Text(issue.title).font(.body).fixedSize(horizontal: false, vertical: true)
                    }.padding(.vertical, 6)
                }.accessibilityIdentifier("issue.\(issue.id)")
            }
            if model.offset < model.total && !model.loading {
                Button { Task { await model.more() } } label: {
                    HStack { Spacer(); if model.loadingMore { ProgressView() } else { Text("加载更多") }; Spacer() }.frame(minHeight: 44)
                }.disabled(model.loadingMore).accessibilityIdentifier("issues.more")
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(ChattyTheme.background)
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "搜索 Issue").autocorrectionDisabled()
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
    @State private var selectedStatus = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if model.loadingDetail { ProgressView("读取最新详情…").frame(maxWidth: .infinity) }
                if let error = model.detailError {
                    ErrorNotice(text: error, identifier: "issue.error")
                    Button("重新读取") { Task { await model.loadDetail(id: issueId) } }.frame(minHeight: 44).accessibilityIdentifier("issue.reload")
                }
                if let issue = model.detail, issue.id == issueId || issue.identifier == issueId {
                    Text(issue.identifier).font(.caption).foregroundStyle(.secondary)
                    Text(issue.title).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("状态").font(.headline); Spacer()
                            if model.saving { ProgressView() }
                            Menu {
                                ForEach(model.statuses) { entry in
                                    Button(entry.name) { selectedStatus = entry.key }
                                }
                            } label: { Label(model.statusName(selectedStatus.isEmpty ? issue.status : selectedStatus), systemImage: "chevron.up.chevron.down").frame(minHeight: 44) }
                            .disabled(model.saving || model.loadingDetail || model.detailError != nil || model.statuses.isEmpty).accessibilityIdentifier("issue.status")
                        }
                        Text("仅更新进度，不启动 Agent。").font(.footnote).foregroundStyle(.secondary)
                        if let error = model.catalogError { Text(error).font(.footnote).foregroundStyle(.secondary) }
                        if !selectedStatus.isEmpty && selectedStatus != issue.status {
                            Button("保存状态") { Task { await model.changeStatus(selectedStatus); selectedStatus = "" } }
                                .buttonStyle(.borderedProminent).disabled(model.saving || model.detailError != nil).frame(minHeight: 44).accessibilityIdentifier("issue.save")
                        }
                    }.padding(18).background(ChattyTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                    if let priority = issue.priority, priority != "none" { LabeledContent("优先级", value: priority).font(.callout) }
                    if let date = issue.dueDate { LabeledContent("截止日期", value: date).font(.callout) }
                    if let description = issue.description, !description.isEmpty { RichContentView(source: description, context: context) }
                    else { Text("暂无描述。").foregroundStyle(.secondary) }
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ChattyTheme.background).navigationTitle("Issue 详情").navigationBarTitleDisplayMode(.inline)
        .onForegroundRefresh { selectedStatus = ""; await model.overview(); await model.loadDetail(id: issueId) }
        .task(id: issueId) {
            selectedStatus = ""
            if model.statuses.isEmpty { await model.overview() }
            await model.loadDetail(id: issueId)
        }
        .toolbar { Button("刷新", systemImage: "arrow.clockwise") { Task { selectedStatus = ""; await model.loadDetail(id: issueId) } }.disabled(model.saving).accessibilityIdentifier("issue.refresh") }
    }
}
