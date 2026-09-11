import SwiftUI
import ChattyCore

struct ActivityScreen: View {
    let model: ActivityModel
    let projects: ProjectsModel
    let context: WorkspaceContext
    let discuss: (Issue) -> Void
    @State private var pending = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 26) {
                activityTab("新进展", selected: !pending) { pending = false }
                activityTab(model.actionTotal > 0 ? "待处理 \(model.actionTotal)" : "待处理", selected: pending) { pending = true }
                Spacer()
            }.padding(.horizontal, 24).padding(.top, 8)
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let error = pending ? model.actionError ?? model.error : model.error {
                        ErrorNotice(text: error, identifier: "activity.error").padding(.vertical, 12)
                        Button("重试") { Task { await model.refresh() } }.frame(minHeight: 44)
                    }
                    if let error = model.readError { ErrorNotice(text: error, identifier: "activity.readError") }
                    if model.loading && rows.isEmpty { ProgressView("读取项目动态…").padding(30) }
                    if !model.loading && rows.isEmpty && model.error == nil && (!pending || model.actionError == nil) {
                        ContentUnavailableView(pending ? "当前没有待处理事项" : "暂时没有项目动态", systemImage: pending ? "checkmark.circle" : "tray",
                            description: Text(pending ? "项目里的工作会持续显示在新进展中。" : "所有可访问项目的事项变化都会显示在这里。"))
                    }
                    ForEach(rows) { issue in
                        NavigationLink {
                            IssueScreen(model: projects, context: context, issueId: issue.id, onViewed: model.markRead, onChanged: model.apply, discuss: discuss)
                        } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: symbol(issue)).font(.callout).foregroundStyle(ChattyTheme.accent)
                                    .frame(width: 32, height: 32).background(ChattyTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(alignment: .topTrailing) {
                                        if model.isUnread(issue) { Circle().fill(.red).frame(width: 6, height: 6).accessibilityLabel("未读").accessibilityIdentifier("activity.unread.\(issue.id)") }
                                    }
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(model.projectName(issue.projectId))
                                        if let date = parsedDate(issue.lastActivityAt ?? issue.updatedAt) { Text("·"); Text(date, style: .relative) }
                                    }.font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    Text(issue.title).font(.body.weight(.medium)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                    Text(model.summary(issue)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(.vertical, 20)
                        }.buttonStyle(.plain).accessibilityIdentifier("activity.issue.\(issue.id)")
                        Divider()
                    }
                    if model.hasMore(actions: pending) {
                        Button { Task { await model.more(actions: pending) } } label: {
                            Group { if model.loadingMore { ProgressView() } else { Text("加载更多") } }.frame(maxWidth: .infinity, minHeight: 48)
                        }.disabled(model.loadingMore || model.loading).accessibilityIdentifier("activity.more")
                    }
                }.padding(.horizontal, 24).padding(.bottom, 20)
            }.refreshable { await model.refresh() }.accessibilityIdentifier("activity.list")
        }
        .navigationTitle("动态").background(ChattyTheme.background)
    }
    private var rows: [Issue] { pending ? model.actions : model.recent }
    private func activityTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.body.weight(selected ? .medium : .regular))
                .foregroundStyle(selected ? ChattyTheme.accent : .secondary)
                .padding(.vertical, 13).overlay(alignment: .bottom) { if selected { Rectangle().fill(ChattyTheme.accent).frame(height: 2) } }
        }.accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier(title.hasPrefix("待处理") ? "activity.actions" : "activity.recent")
    }
    private func symbol(_ issue: Issue) -> String {
        switch model.category(issue) { case "in_review", "done": "checkmark"; case "blocked": "questionmark"; default: "waveform.path" }
    }
}

func parsedDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]; return formatter.date(from: value)
}
