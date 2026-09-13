import Testing
import Foundation
@testable import ChattyNextCore

@Test func automaticApprovalRequiresExactServerReceipt() throws {
    try AutomaticApproval.validate(j(#"{"result":{"kind":"success","text":"chatty-next:approve-for-me-v1"}}"#))
    for value in [#"null"#, #"{"result":{"kind":"error","text":"chatty-next:approve-for-me-v1"}}"#, #"{"result":{"kind":"success","text":"full-access"}}"#] {
        #expect(throws: NextError.self) { try AutomaticApproval.validate(j(value)) }
    }
    var reducer = SessionReducer(); try reducer.apply(snapshot())
    for (index, type) in ["chatty/approval-mode", "chatty/approval-review"].enumerated() {
        try reducer.apply(.object(["type": .str("event"), "event": .object(["seq": .number(Double(index + 1)), "type": .str(type), "data": .object([:])])]))
    }
    #expect(reducer.messages.isEmpty)
    #expect(reducer.cursor == 2)
}

private func j(_ text: String) throws -> Wire { try Wire.decode(Data(text.utf8)) }
private func snapshot() throws -> Wire { try j(#"{"type":"snapshot","header":{"id":"s","version":3,"cwd":"/tmp/chatty"},"cursor":0,"records":[],"hasMore":false,"projections":{"values":{}},"assistantStream":{"revision":0}}"#) }
private func start() throws -> Wire { try j(#"{"type":"assistant-stream","frame":{"type":"start","attemptId":"a","revision":1,"startedAfterSeq":0,"turn":1,"step":0}}"#) }
private func chunk() throws -> Wire { try j(#"{"type":"assistant-stream","frame":{"type":"chunk","attemptId":"a","revision":2,"index":0,"chunk":{"type":"text-delta","index":0,"text":"你好"}}}"#) }
private func end() throws -> Wire { try j(#"{"type":"assistant-stream","frame":{"type":"end","attemptId":"a","revision":3,"index":1,"outcome":{"kind":"committed","eventType":"assistant/message","seq":1}}}"#) }
private func final() throws -> Wire { try j(#"{"type":"event","event":{"type":"assistant/message","seq":1,"time":1,"surfaceOp":"append","data":{"turn":1,"step":0,"message":{"content":[{"type":"text","text":"你好，完成。"}]}}}}"#) }

@Test func exactOriginIncludesPortAndRejectsUnsafeInputs() throws {
    let origin = try DSHOrigin("https://example.ts.net:8443/?token=secret")
    #expect(origin.key == "https://example.ts.net:8443/")
    #expect(!origin.matches(URL(string: "https://example.ts.net/")!))
    #expect(!origin.matches(URL(string: "https://other.ts.net:8443/")!))
    for value in ["http://example.com/", "https://a:pw@example.com/", "https://example.com/api", "https://example.com/#x", "https://example.com/?other=x"] {
        #expect(throws: NextError.self) { try DSHOrigin(value) }
    }
    #expect(throws: NextError.self) { try DSHOrigin("http://127.0.0.1:8876") }
    #expect(try DSHOrigin("http://127.0.0.1:8876", allowLoopbackHTTP: true).url.scheme == "http")
}
@Test func durableBeforeEndReplacesOneAnswer() throws {
    var r = SessionReducer(); try r.apply(snapshot()); try r.apply(start()); try r.apply(chunk()); try r.apply(chunk())
    #expect(r.messages.count == 1); #expect(r.messages[0].text == "你好")
    try r.apply(final()); #expect(r.messages.count == 1)
    try r.apply(end()); #expect(r.messages.count == 1); #expect(r.messages[0].text == "你好，完成。"); #expect(!r.live)
}
@Test func endBeforeDurablePreservesVisiblePrefix() throws {
    var r = SessionReducer(); try r.apply(snapshot()); try r.apply(start()); try r.apply(chunk()); try r.apply(end())
    #expect(r.messages.first?.text == "你好"); try r.apply(final()); #expect(r.messages.count == 1); #expect(r.messages.first?.pending == false)
}
@Test func missingFramesRequireRecovery() throws {
    var r = SessionReducer(); try r.apply(snapshot()); try r.apply(start())
    #expect(throws: NextError.self) { try r.apply(end()) }
    #expect(throws: NextError.self) { try r.apply(j(#"{"type":"event","event":{"seq":5,"type":"user/message","data":{}}}"#)) }
}
@Test func compactBlockCloseWinsOverLateDelta() throws {
    var blocks = StreamBlocks()
    try blocks.loadCompact(j(#"[{"type":"text-chunks","index":0,"time0":0,"dt":[0,1],"texts":["你","好"]},{"type":"chunk","time":2,"chunk":{"type":"block-end","index":0,"block":{"type":"text","text":"完成"}}},{"type":"text-chunks","index":0,"time0":3,"dt":[0],"texts":["重复"]}]"#).array)
    #expect(blocks.content.count == 1); #expect(blocks.content[0]["text"].text == "完成")
}
@Test func voiceFinalAndReleaseCanArriveInEitherOrderOnlyOnce() {
    for finalFirst in [true, false] {
        var gate = VoiceGate(); let id = gate.begin(scope: "one", revision: 3)
        gate.revise(id, start: 0, end: 2, text: "错误", stable: false)
        gate.revise(id, start: 0, end: 2, text: "正确", stable: true)
        if finalFirst { gate.finish(id); #expect(gate.consume(scope: "one", revision: 3) == nil); gate.release(id) }
        else { gate.release(id); #expect(gate.consume(scope: "one", revision: 3) == nil); gate.finish(id) }
        #expect(gate.consume(scope: "one", revision: 3) == "正确"); #expect(gate.consume(scope: "one", revision: 3) == nil)
    }
}
@Test func cancelledVoiceCannotSendLateFinalIntoNewConversation() {
    var gate = VoiceGate(); let old = gate.begin(scope: "one", revision: 1)
    gate.armCancel(); gate.release(old); let new = gate.begin(scope: "two", revision: 2)
    gate.revise(old, start: 0, end: 1, text: "迟到", stable: true); gate.finish(old); gate.release(old)
    #expect(gate.consume(scope: "two", revision: 2) == nil); #expect(gate.identity == new)
    gate.revise(new, start: 0, end: 1, text: "新文字", stable: true); gate.release(new); gate.finish(new)
    #expect(gate.consume(scope: "one", revision: 2) == nil)
    #expect(gate.consume(scope: "two", revision: 2) == "新文字")
}
@Test @MainActor func draftOutboxTransactionSurvivesReloadAndIsOriginScoped() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let disk = try NextStorage(identifier: "test", root: root)
    let origin = try DSHOrigin("https://host.ts.net:8443"), other = try DSHOrigin("https://host.ts.net:8444")
    var state = NextLocalState(), draft = NextDraft(); draft.text = "原文"; draft.workspace = .str("w")
    let pending = state.stage(source: "new", sessionID: "s", draft: draft); try disk.save(state, origin: origin)
    state.drafts["s"]?.text = "下一条"; try disk.save(state, origin: origin)
    let restored = try disk.load(origin: origin)
    #expect(restored.pending.first?.id == pending.id); #expect(restored.pending.first?.draft.text == "原文")
    #expect(restored.drafts["s"]?.text == "下一条"); #expect(try disk.load(origin: other).pending.isEmpty)
}

@Test func recordedDSHFramesProduceOneDurableReplyAndReconcileSend() throws {
    let url = Bundle.module.url(forResource: "dsh-0.1.5-frames", withExtension: "json", subdirectory: "Fixtures")!
    let frames = try Wire.decode(Data(contentsOf: url)).array
    var reducer = SessionReducer()
    for frame in frames { try reducer.apply(frame) }
    #expect(reducer.messages.filter { $0.role == "assistant" }.count == 1)
    #expect(reducer.messages.filter { $0.role == "user" }.count == 1)
    #expect(reducer.messages.last?.text == "Chatty Next connected.")
    #expect(reducer.knownRequestIDs.contains("recorded-request"))
    #expect(!reducer.live)
}

@Test func unknownRequiredEventsAndNewFormatBlockReconstruction() throws {
    var reducer = SessionReducer(); try reducer.apply(snapshot())
    #expect(throws: NextError.self) { try reducer.apply(j(#"{"type":"event","event":{"seq":1,"type":"future/required","data":{}}}"#)) }
    try reducer.apply(j(#"{"type":"event","event":{"seq":1,"type":"future/log","data":{},"ignorable":true}}"#))
    #expect(reducer.cursor == 1)
    #expect(throws: NextError.self) { try reducer.apply(j(#"{"type":"snapshot","header":{"id":"s","version":4},"cursor":0}"#)) }
}
