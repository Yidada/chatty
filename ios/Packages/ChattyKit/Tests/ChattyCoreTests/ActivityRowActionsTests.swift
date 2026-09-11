import XCTest
@testable import ChattyCore

/// The row-action table is the one definition the swipe gesture, the VoiceOver
/// custom actions and the pointer menu all read. These tests pin the mapping so
/// no entry point can quietly disagree with another.
final class ActivityRowActionsTests: XCTestCase {

    func testPendingListSwipesCompleteForwardAndReturnBack() {
        let actions = ActivityRowActions.forList(.pending)
        XCTAssertEqual(actions.trailing.kind, .complete)
        XCTAssertEqual(actions.trailing.title, "验收完成")
        XCTAssertEqual(actions.leading.kind, .returnToTodo)
        XCTAssertEqual(actions.leading.title, "退回待办")
        XCTAssertFalse(actions.isAmbiguous, "One direction must not shadow the other")
        XCTAssertEqual(actions.ordered.map(\.kind), [.complete, .returnToTodo],
                       "VoiceOver hears the primary (left-swipe) action first")
    }

    func testRecentListSwipesOnlyWriteTheLocalReadState() {
        let actions = ActivityRowActions.forList(.recent)
        XCTAssertEqual(actions.trailing.kind, .markRead)
        XCTAssertEqual(actions.leading.kind, .markUnread)
        XCTAssertEqual(actions.ordered.map(\.kind), [.markRead, .markUnread])
        XCTAssertTrue(actions.ordered.allSatisfy(\.isLocalOnly), "The recent list never moves issue status")
        XCTAssertTrue(actions.ordered.allSatisfy { $0.batchUpdate == nil })
        XCTAssertFalse(actions.isAmbiguous)
    }

    func testOnlyMarkReadMayRunOnAFullSwipe() {
        let fullSwipes = ActivityFeedList.allCases
            .flatMap { ActivityRowActions.forList($0).ordered }
            .filter(\.allowsFullSwipe)
            .map(\.kind)
        XCTAssertEqual(fullSwipes, [.markRead], "A business-status change must be revealed and tapped")
    }

    func testStatusActionsCarryTheExactBatchBodyAndEmphasis() throws {
        let pending = ActivityRowActions.forList(.pending)
        XCTAssertEqual(pending.trailing.batchUpdate?.json,
                       ["status": .string("done"), "suppress_run": .bool(true)])
        XCTAssertEqual(pending.leading.batchUpdate?.json,
                       ["status": .string("todo"), "suppress_run": .bool(true)])
        // Without a mutation field the server answers {"updated": 0}, so the
        // action must always be able to produce one.
        for action in pending.ordered {
            XCTAssertEqual(try XCTUnwrap(action.batchUpdate).hasMutation, true)
        }
        // Accent on the forward action, orange on the reversible one. Nothing
        // here is destructive, so nothing is red.
        XCTAssertEqual(pending.trailing.emphasis, .primary)
        XCTAssertEqual(pending.leading.emphasis, .secondary)
        XCTAssertEqual(ActivityRowActions.forList(.recent).trailing.emphasis, .primary)
        XCTAssertEqual(ActivityRowActions.forList(.recent).leading.emphasis, .secondary)
    }

    func testEveryActionHasAStableUniqueIdentifierTitleAndIcon() {
        let all = ActivityFeedList.allCases.flatMap { ActivityRowActions.forList($0).ordered }
        let ids = all.map(\.id)
        XCTAssertEqual(Set(ids), ["complete", "returnToTodo", "markRead", "markUnread"])
        XCTAssertEqual(Set(ids).count, ids.count, "Identifiers must stay unique so rows and swipe buttons stay addressable")
        for action in all {
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertFalse(action.systemImage.isEmpty)
        }
    }

    /// VoiceOver cannot swipe a row, so each row publishes the same pair as
    /// custom actions. Both the swipe buttons and the custom actions read their
    /// names from this table, so pinning the names here is what keeps the two
    /// entry points identical.
    func testVoiceOverMirrorNamesMatchTheGesturePair() {
        XCTAssertEqual(ActivityRowActions.forList(.recent).ordered.map(\.title), ["标记已读", "标为未读"])
        XCTAssertEqual(ActivityRowActions.forList(.pending).ordered.map(\.title), ["验收完成", "退回待办"])
        for list in ActivityFeedList.allCases {
            let actions = ActivityRowActions.forList(list)
            XCTAssertEqual(actions.ordered.map(\.kind), [actions.trailing.kind, actions.leading.kind],
                           "The mirror must carry the trailing action first and the leading one second")
        }
    }
}
