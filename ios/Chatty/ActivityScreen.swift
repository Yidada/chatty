import SwiftUI
import ChattyCore
import UIKit

struct ActivityScreen: View {
    let model: ActivityModel
    let projects: ProjectsModel
    let context: WorkspaceContext
    let discuss: (Issue) -> Void
    @State private var pending = false
    @State private var selecting = false
    @State private var openedIssueID: String?
    /// Selection is per list: the two lists show different rows, so a single
    /// shared set would let a batch act on rows the user is not looking at.
    @State private var recentSelection = SelectionSet()
    @State private var actionSelection = SelectionSet()
    @State private var readNote: String?

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            outcomeBanner
            list
        }
        .navigationTitle("动态").background(ChattyTheme.background)
        .toolbar { selectionToolbar }
        .safeAreaInset(edge: .bottom) { if selecting { selectionBar } }
        .navigationDestination(item: $openedIssueID) { id in
            IssueScreen(model: projects, context: context, issueId: id, onViewed: model.markRead, onChanged: model.apply, discuss: discuss)
        }
        .onChange(of: model.recent.map(\.id)) { _, ids in recentSelection.prune(keeping: ids) }
        .onChange(of: model.actions.map(\.id)) { _, ids in actionSelection.prune(keeping: ids) }
    }

    // MARK: - Chrome

    private var tabBar: some View {
        HStack(spacing: 26) {
            activityTab("新进展", selected: !pending) { pending = false }
            activityTab(model.actionTotal > 0 ? "待处理 \(model.actionTotal)" : "待处理", selected: pending) { pending = true }
            Spacer()
        }.padding(.horizontal, 24).padding(.top, 8)
    }

    @ToolbarContentBuilder private var selectionToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if selecting {
                Button("完成") { exitSelection() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("activity.select.done")
            } else if !rows.isEmpty {
                Button("选择") { selecting = true }
                    .accessibilityIdentifier("activity.select")
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                listNotice
                ForEach(rows) { issue in
                    activityRow(issue)
                    Divider()
                }
                moreButton
            }.padding(.horizontal, 24).padding(.bottom, selecting ? 140 : 20)
        }.refreshable { await model.refresh() }.accessibilityIdentifier("activity.list")
    }

    @ViewBuilder private var listNotice: some View {
        if let error = pending ? model.actionError ?? model.error : model.error {
            ErrorNotice(text: error, identifier: "activity.error").padding(.vertical, 12)
            Button("重试") { Task { await model.refresh() } }.frame(minHeight: 44)
        }
        if let error = model.readError { ErrorNotice(text: error, identifier: "activity.readError") }
        if model.loading && rows.isEmpty { ProgressView("读取项目动态…").padding(30) }
        if !model.loading && rows.isEmpty && model.error == nil && (!pending || model.actionError == nil) {
            ContentUnavailableView(pending ? "当前没有待处理事项" : "暂时没有项目动态",
                systemImage: pending ? "checkmark.circle" : "tray",
                description: Text(pending ? "项目里的工作会持续显示在新进展中。" : "所有可访问项目的事项变化都会显示在这里。"))
        }
    }

    @ViewBuilder private var moreButton: some View {
        if model.hasMore(actions: pending) {
            Button { Task { await model.more(actions: pending) } } label: {
                Group { if model.loadingMore { ProgressView() } else { Text("加载更多") } }.frame(maxWidth: .infinity, minHeight: 48)
            }.disabled(model.loadingMore || model.loading).accessibilityIdentifier("activity.more")
        }
    }

    // MARK: - Rows

    private var rows: [Issue] { pending ? model.actions : model.recent }
    private var selection: SelectionSet { pending ? actionSelection : recentSelection }
    private var availableIDs: [String] { rows.map(\.id) }

    /// Pointer parity for the feed rows: the same status actions the detail
    /// screen exposes, plus a shareable link.
    @ViewBuilder private func issueMenu(_ issue: Issue) -> some View {
        if model.category(issue) == "in_review", let done = model.statuses.first(where: { $0.category == "done" })?.key {
            Button("验收通过", systemImage: "checkmark.circle") { apply(done, for: issue) }
        }
        if !model.statuses.isEmpty {
            Menu("更改状态", systemImage: "arrow.triangle.2.circlepath") {
                ForEach(model.statuses) { entry in Button(entry.name) { apply(entry.key, for: issue) } }
            }
        }
        Button("复制链接", systemImage: "link") {
            UIPasteboard.general.string = NativeLink.issueLink(workspace: context.workspace.slug, identifier: issue.identifier)
        }
    }
    private func apply(_ status: String, for issue: Issue) {
        Task { if let updated = await projects.setStatus(status, for: issue.id) { model.apply(updated) } }
    }

    @ViewBuilder private func activityRow(_ issue: Issue) -> some View {
        // One view type in both modes. Swapping between Button and NavigationLink
        // for the same row identity left a stale accessibility element behind
        // after leaving selection mode, so browse-mode navigation goes through
        // the enclosing stack's destination instead.
        let chosen = selecting && selection.contains(issue.id)
        Button { activate(issue) } label: { rowLabel(issue) }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .contextMenu { issueMenu(issue) }
            .accessibilityIdentifier("activity.issue.\(issue.id)")
            .accessibilityAddTraits(chosen ? .isSelected : [])
            .accessibilityValue(selecting ? (chosen ? "已选中" : "未选中") : "")
            .accessibilityHint(selecting ? "轻点切换选中状态" : "轻点查看事项详情")
    }

    private func activate(_ issue: Issue) {
        if selecting { toggle(issue) } else { openedIssueID = issue.id }
    }

    private func rowLabel(_ issue: Issue) -> some View {
        HStack(alignment: .top, spacing: 14) {
            leadingIcon(issue)
            rowText(issue)
        }.padding(.vertical, 20).contentShape(Rectangle())
    }

    @ViewBuilder private func leadingIcon(_ issue: Issue) -> some View {
        if selecting {
            let chosen = selection.contains(issue.id)
            Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(chosen ? ChattyTheme.accent : Color.secondary)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
        } else {
            activityIcon(issue)
        }
    }

    private func activityIcon(_ issue: Issue) -> some View {
        Image(systemName: symbol(issue))
            .font(.callout)
            .foregroundStyle(ChattyTheme.accent)
            .frame(width: 32, height: 32)
            .background(ChattyTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) { unreadDot(issue) }
    }

    @ViewBuilder private func unreadDot(_ issue: Issue) -> some View {
        if model.isUnread(issue) {
            Circle().fill(.red).frame(width: 6, height: 6)
                .accessibilityLabel("未读")
                .accessibilityIdentifier("activity.unread.\(issue.id)")
        }
    }

    private func rowText(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            metaLine(issue)
            Text(issue.title).font(.body.weight(.medium)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            Text(model.summary(issue)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metaLine(_ issue: Issue) -> some View {
        HStack {
            Text(model.projectName(issue.projectId))
            if let date = parsedDate(issue.lastActivityAt ?? issue.updatedAt) {
                Text("·")
                Text(date, style: .relative)
            }
        }.font(.caption).foregroundStyle(.secondary).lineLimit(1)
    }

    private func activityTab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.body.weight(selected ? .medium : .regular))
                .foregroundStyle(selected ? ChattyTheme.accent : Color.secondary)
                .padding(.vertical, 13).overlay(alignment: .bottom) { if selected { Rectangle().fill(ChattyTheme.accent).frame(height: 2) } }
        }.accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier(title.hasPrefix("待处理") ? "activity.actions" : "activity.recent")
    }

    private func symbol(_ issue: Issue) -> String {
        switch model.category(issue) { case "in_review", "done": "checkmark"; case "blocked": "questionmark"; default: "waveform.path" }
    }

    // MARK: - Selection actions

    private func toggle(_ issue: Issue) {
        if pending { actionSelection.toggle(issue.id) } else { recentSelection.toggle(issue.id) }
    }
    private func toggleAll() {
        let select = !selection.allSelected(availableIDs)
        if pending { actionSelection.setAll(availableIDs, selected: select) } else { recentSelection.setAll(availableIDs, selected: select) }
    }
    private func exitSelection() {
        selecting = false
        recentSelection.removeAll(); actionSelection.removeAll()
    }
    private func selectedIDs() -> [String] { rows.filter { selection.contains($0.id) }.map(\.id) }

    private var selectionBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(selection.isEmpty ? "未选择事项" : "已选 \(selection.count) 项")
                    .font(.callout.weight(.medium))
                    .accessibilityIdentifier("activity.batch.count")
                Spacer(minLength: 8)
                Button(selection.allSelected(availableIDs) ? "取消全选" : "全选") { toggleAll() }
                    .keyboardShortcut("a", modifiers: .command)
                    .disabled(availableIDs.isEmpty)
                    .accessibilityIdentifier("activity.select.all")
                Button("完成") { exitSelection() }.accessibilityIdentifier("activity.select.doneBottom")
            }
            batchActions
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder private var batchActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { readButton; if pending { approveButton; returnButton } }
            VStack(spacing: 10) {
                HStack(spacing: 10) { readButton }
                if pending { HStack(spacing: 10) { approveButton; returnButton } }
            }
        }
    }

    private var actionsDisabled: Bool { selection.isEmpty || model.batching }

    private var readButton: some View {
        Button { markSelectedRead() } label: {
            Label("标记已读", systemImage: "envelope.open").frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.bordered).disabled(actionsDisabled).accessibilityIdentifier("activity.batch.read")
    }
    /// Done / todo only exist on the pending list: the recent list carries every
    /// status, so a status action there would apply to rows it cannot describe.
    private var approveButton: some View {
        Button { submit(.completion()) } label: {
            Text("验收完成").frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.borderedProminent).disabled(actionsDisabled).accessibilityIdentifier("activity.batch.approve")
    }
    private var returnButton: some View {
        Button { submit(.returnToTodo()) } label: {
            Text("退回待办").frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.bordered).disabled(actionsDisabled).accessibilityIdentifier("activity.batch.return")
    }

    private func markSelectedRead() {
        let ids = Set(selectedIDs())
        guard !ids.isEmpty else { return }
        let marked = model.markRead(ids: ids)
        readNote = marked > 0 ? "已标记 \(marked) 项为已读。" : nil
        exitSelection()
    }
    private func submit(_ update: IssueBatchUpdate) {
        let ids = selectedIDs()
        guard !ids.isEmpty else { return }
        exitSelection()
        Task { _ = await model.batchUpdate(ids: ids, update: update) }
    }
    private func retry() {
        Task { _ = await model.retryLastBatch() }
    }

    // MARK: - Outcome feedback

    @ViewBuilder private var outcomeBanner: some View {
        if model.batching {
            banner { progressNotice }
        } else if let note = readNote {
            banner { readNotice(note) }
        } else if let result = model.batchResult {
            banner { resultNotice(result) }
        }
    }

    private var progressNotice: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(model.batchProgressTotal > 1 ? "正在提交第 \(model.batchProgress + 1)/\(model.batchProgressTotal) 批…" : "正在提交…")
        }
    }

    private func readNotice(_ note: String) -> some View {
        HStack(spacing: 12) {
            Text(note).font(.callout).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("关闭") { readNote = nil }
        }
    }

    private func resultNotice(_ result: BatchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.summary).font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("activity.batch.result")
            ForEach(result.messages, id: \.self) { message in
                Text(message).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if result.unfinished > 0 {
                Text("未生效或失败的事项没有改动；服务端不返回具体是哪几项，可重试或下拉刷新核对。")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            resultButtons(result)
        }
    }

    private func resultButtons(_ result: BatchResult) -> some View {
        HStack(spacing: 12) {
            if result.canRetry {
                Button("重试未完成 \(result.unfinished) 项") { retry() }
                    .disabled(model.batching).accessibilityIdentifier("activity.batch.retry")
            }
            Button("关闭") { model.clearBatchOutcome() }.accessibilityIdentifier("activity.batch.dismiss")
        }.frame(minHeight: 36)
    }

    private func banner<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 24).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ChattyTheme.accent.opacity(0.08))
            .overlay(alignment: .bottom) { Divider() }
    }
}

func parsedDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]; return formatter.date(from: value)
}
