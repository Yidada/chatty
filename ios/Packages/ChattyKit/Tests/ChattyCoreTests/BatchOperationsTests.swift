import XCTest
@testable import ChattyCore

/// The batch path is mostly policy, not transport: what a selection contains,
/// what the wire body says, and how per-chunk counts turn into an honest
/// result. Those rules are unit-tested here; the model-level flow (convergence,
/// read marks, double-submit guard) lives in ClientFlowTests.
final class BatchOperationsTests: XCTestCase {

    // MARK: Selection

    func testSelectionTogglesSelectsAllAndPrunesRowsThatLeftThePage() {
        var selection = SelectionSet()
        XCTAssertTrue(selection.isEmpty)
        selection.toggle("a"); selection.toggle("b")
        XCTAssertEqual(selection.count, 2); XCTAssertTrue(selection.contains("a"))
        selection.toggle("a")
        XCTAssertEqual(selection.ids, ["b"])
        selection.setAll(["a", "b", "c"], selected: true)
        XCTAssertEqual(selection.ordered, ["a", "b", "c"])
        XCTAssertTrue(selection.allSelected(["c", "b", "a"]))
        // A row that a refresh dropped must not stay selected: the batch could
        // otherwise write to a row the user can no longer see.
        selection.prune(keeping: ["b", "c", "d"])
        XCTAssertEqual(selection.ordered, ["b", "c"])
        XCTAssertFalse(selection.allSelected(["b", "c", "d"]))
        XCTAssertTrue(selection.allSelected(["c", "b"]))
        selection.setAll(["b", "c"], selected: true)
        XCTAssertTrue(selection.allSelected(["b", "c"]))
        selection.setAll([], selected: true)
        XCTAssertTrue(selection.isEmpty, "An empty page never counts as all-selected")
        XCTAssertFalse(selection.allSelected([]))
    }

    // MARK: Request body

    func testBatchRequestCarriesOnlyIntendedFieldsAndMarksSuppressRun() throws {
        let done = IssueBatchUpdate.completion()
        XCTAssertTrue(done.hasMutation)
        let json = done.json
        XCTAssertEqual(json["status"], .string("done"))
        XCTAssertEqual(json["suppress_run"], .bool(true))
        XCTAssertEqual(Set(json.keys), ["status", "suppress_run"], "Unset fields must not reach the wire")
        let todo = IssueBatchUpdate.returnToTodo(suppressRun: false)
        XCTAssertEqual(todo.json["status"], .string("todo"))
        XCTAssertEqual(todo.json["suppress_run"], .bool(false))
        // The server short-circuits to `{"updated": 0}` without a mutation
        // field, so a suppress-only payload must never be submitted.
        XCTAssertFalse(IssueBatchUpdate(suppressRun: true).hasMutation)
        XCTAssertFalse(IssueBatchUpdate().hasMutation)
        let complete = IssueBatchUpdate(status: "blocked", priority: "high", assigneeType: "member", assigneeID: "u2",
                                        projectID: "p1", dueDate: "2026-09-30", stage: 2)
        XCTAssertEqual(complete.json["priority"], .string("high"))
        XCTAssertEqual(complete.json["assignee_type"], .string("member"))
        XCTAssertEqual(complete.json["assignee_id"], .string("u2"))
        XCTAssertEqual(complete.json["project_id"], .string("p1"))
        XCTAssertEqual(complete.json["due_date"], .string("2026-09-30"))
        XCTAssertEqual(complete.json["stage"], .number(2))
    }

    func testBatchChunkingKeepsOrderDropsBlanksAndCapsAtTwenty() {
        let ids = (0..<45).map { "i\($0)" }
        let chunks = BatchChunking.chunks(ids)
        XCTAssertEqual(chunks.map(\.count), [20, 20, 5])
        XCTAssertEqual(chunks.flatMap { $0 }, ids, "Order must survive chunking")
        XCTAssertEqual(BatchChunking.unique(["a", "", "a", "b", "b", "c"]), ["a", "b", "c"])
        XCTAssertEqual(BatchChunking.chunks([]), [])
        XCTAssertEqual(BatchChunking.chunks(["a", "b"], size: 0), [["a", "b"]], "A non-positive size must not drop ids")
    }

    // MARK: Result accounting

    func testAccumulatorSeparatesSkipsFromFailuresAndClampsOverReports() {
        var accumulator = BatchAccumulator()
        accumulator.record(chunk: ["a", "b"], updated: 2)
        XCTAssertEqual(accumulator.updated, 2); XCTAssertEqual(accumulator.skipped, 0); XCTAssertTrue(accumulator.retryIDs.isEmpty)
        // The endpoint silently skips ids it cannot resolve or touch.
        accumulator.record(chunk: ["c", "d", "e"], updated: 1)
        XCTAssertEqual(accumulator.updated, 3); XCTAssertEqual(accumulator.skipped, 2)
        XCTAssertEqual(accumulator.retryIDs, ["c", "d", "e"], "Which id was skipped is unknown, so the whole chunk is retryable")
        // A rejected chunk is a failure, not a skip, and must not be counted
        // as applied.
        accumulator.recordFailure(chunk: ["f"], message: "服务暂时不可用")
        accumulator.recordFailure(chunk: ["f"], message: "服务暂时不可用")
        XCTAssertEqual(accumulator.failed, 2)
        XCTAssertEqual(accumulator.messages, ["服务暂时不可用"], "Repeated failures keep one message")
        // A server that over-reports must never inflate the totals.
        accumulator.record(chunk: ["g"], updated: 9)
        XCTAssertEqual(accumulator.updated, 4); XCTAssertEqual(accumulator.skipped, 2, "A one-id chunk can only ever report one apply")
        let result = accumulator.result()
        XCTAssertEqual(result.requested, 8)
        XCTAssertEqual(result.updated, 4); XCTAssertEqual(result.skipped, 2); XCTAssertEqual(result.failed, 2)
        XCTAssertEqual(result.unfinished, 4)
        XCTAssertFalse(result.isFullSuccess)
        XCTAssertTrue(result.canRetry)
        XCTAssertEqual(result.retryIDs, ["c", "d", "e", "f"])
        XCTAssertTrue(result.summary.contains("未生效 2"))
        XCTAssertTrue(result.summary.contains("失败 2"))
        XCTAssertTrue(accumulator.hasAccepted)
        XCTAssertEqual(accumulator.acceptedIssueIDs, ["a", "b", "c", "d", "e", "g"])
    }

    func testResultNeverReportsZeroAppliedAsSuccessAndHasNoRetryWhenEverythingLanded() {
        var accumulator = BatchAccumulator()
        accumulator.record(chunk: ["a"], updated: 0)
        let allSkipped = accumulator.result()
        XCTAssertFalse(allSkipped.isFullSuccess)
        XCTAssertTrue(allSkipped.summary.contains("未生效 1"))
        XCTAssertTrue(accumulator.acceptedIssueIDs.isEmpty, "Nothing changed, so nothing may be marked reviewed")
        XCTAssertFalse(accumulator.hasAccepted)

        var clean = BatchAccumulator()
        clean.record(chunk: ["a", "b"], updated: 2)
        let result = clean.result()
        XCTAssertTrue(result.isFullSuccess)
        XCTAssertFalse(result.canRetry)
        XCTAssertEqual(result.unfinished, 0)
        XCTAssertEqual(result.summary, "已提交 2 项，全部成功。")

        let empty = BatchResult(requested: 0, updated: 0, skipped: 0, failed: 0, retryIDs: [], messages: [])
        XCTAssertEqual(empty.summary, "没有可提交的事项。")
    }
}
