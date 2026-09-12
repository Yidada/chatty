import Foundation

/// The activity feed has two lists. A row's leading / trailing operations are
/// declared once, here, and consumed by the swipe gesture, the VoiceOver custom
/// actions and the pointer context menu, so no entry point can drift from
/// another or grow a second source of truth.
public enum ActivityFeedList: String, Sendable, CaseIterable {
    case recent, pending
}

/// One operation available from a feed row.
///
/// The status-changing kinds reuse the exact semantics CLE-85 established for
/// multi-select: the same `POST /api/issues/batch-update` body, the same
/// no-optimistic-update convergence and the same honest partial accounting. The
/// read pair changes only the local fingerprint and sends nothing.
public struct ActivityRowAction: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable {
        case complete, returnToTodo, markRead, markUnread
    }

    /// Accent for the primary action, orange for the reversible "put it back"
    /// one. Both status changes can be undone, so nothing here is destructive
    /// and nothing is red.
    public enum Emphasis: Sendable, Equatable { case primary, secondary }

    public let kind: Kind

    public init(_ kind: Kind) { self.kind = kind }

    public var id: String { kind.rawValue }

    public var title: String {
        switch kind {
        case .complete: "验收完成"
        case .returnToTodo: "退回待办"
        case .markRead: "标记已读"
        case .markUnread: "标为未读"
        }
    }

    public var systemImage: String {
        switch kind {
        case .complete: "checkmark.circle"
        case .returnToTodo: "arrow.uturn.backward.circle"
        case .markRead: "envelope.open"
        case .markUnread: "envelope.badge"
        }
    }

    public var emphasis: Emphasis { kind == .complete || kind == .markRead ? .primary : .secondary }

    /// Only the local read write may run on a full swipe. A business-status
    /// change must be revealed and tapped, so a stray full swipe cannot move an
    /// issue to done or back to todo.
    public var allowsFullSwipe: Bool { kind == .markRead }

    /// The body the multi-select path submits, or nil when the action stays on
    /// this device. Built from the same factories the batch bar uses, so a
    /// stored `done` / `todo` write cannot describe itself differently here.
    public var batchUpdate: IssueBatchUpdate? {
        switch kind {
        case .complete: .completion()
        case .returnToTodo: .returnToTodo()
        case .markRead, .markUnread: nil
        }
    }

    public var isLocalOnly: Bool { batchUpdate == nil }
}

/// The leading / trailing pair for one list.
public struct ActivityRowActions: Equatable, Sendable {
    public let list: ActivityFeedList
    /// Right swipe.
    public let leading: ActivityRowAction
    /// Left swipe.
    public let trailing: ActivityRowAction

    public init(list: ActivityFeedList, leading: ActivityRowAction, trailing: ActivityRowAction) {
        self.list = list
        self.leading = leading
        self.trailing = trailing
    }

    /// VoiceOver custom-action order: the primary (left-swipe) action first.
    public var ordered: [ActivityRowAction] { [trailing, leading] }

    /// Both directions are always defined, so a list can never end up with one
    /// edge empty or one direction shadowing the other.
    public var isAmbiguous: Bool { leading.kind == trailing.kind }

    public static func forList(_ list: ActivityFeedList) -> ActivityRowActions {
        switch list {
        case .recent:
            .init(list: .recent, leading: ActivityRowAction(.markUnread), trailing: ActivityRowAction(.markRead))
        case .pending:
            .init(list: .pending, leading: ActivityRowAction(.returnToTodo), trailing: ActivityRowAction(.complete))
        }
    }
}
