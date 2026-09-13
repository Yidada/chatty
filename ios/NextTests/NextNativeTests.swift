import XCTest
import SwiftUI
import ChattyNextCore
@preconcurrency import AVFoundation
import Speech
@testable import ChattyNextFixture

@MainActor final class NextNativeTests: XCTestCase {
    func testToolProcessGroupsWithoutHidingAnswersOrUserMessages() {
        let call: Wire = .object(["type": .str("tool-call"), "name": .str("read_file")])
        let output: Wire = .object(["type": .str("tool-result"), "content": .array([.object(["type": .str("text"), "text": .str("file contents")])])])
        let messages: [TranscriptMessage] = [
            .init(id: "user", role: "user", content: []),
            .init(id: "assistant-call", role: "assistant", content: [call]),
            .init(id: "call", role: "tool", content: []),
            .init(id: "result", role: "tool-result", content: [output]),
            .init(id: "answer", role: "assistant", content: [.object(["type": .str("text"), "text": .str("Visible answer")]), call]),
            .init(id: "next-user", role: "user", content: [])
        ]
        let items = NextTranscriptItem.grouping(messages)
        XCTAssertEqual(items.map(\.id), ["user", "assistant-call", "answer", "next-user"])
        XCTAssertEqual(items.map(\.isProcess), [false, true, false, false])
        XCTAssertEqual(items[1].callCount, 1)
        XCTAssertEqual(NextTranscriptItem.displayBlocks([output]).first?["text"].text, "file contents")
        let streaming = NextTranscriptItem.grouping([.init(id: "live", role: "assistant", content: [call], pending: true)])
        XCTAssertEqual(streaming.first?.title, "工具调用 · 1 次")
        XCTAssertEqual(NextTranscriptItem.grouping([messages[3]]).first?.title, "工具调用")
        XCTAssertEqual(NextTranscriptItem.grouping([.init(id: "waiting", role: "assistant", content: [], pending: true)]).first?.title, "正在回复")
    }
    func testAudioTapRunsOffMainActorAndOwnsConvertedSamples() async throws {
        let source = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
        let target = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1))
        let bridge = try XCTUnwrap(SpeechAudioBridge(from: source, to: target))
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let controller = SpeechInputController(); var gate = VoiceGate()
        let tap = controller.makeAudioTap(id: gate.begin(scope: "test", revision: 0), bridge: bridge, continuation: continuation)
        await Task.detached {
            let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800)!
            buffer.frameLength = 4800
            for i in 0..<4800 { buffer.floatChannelData![0][i] = 0.25 }
            tap(buffer, AVAudioTime(sampleTime: 0, atRate: 48000))
            // The engine reuses its input buffer after the tap returns.
            for i in 0..<4800 { buffer.floatChannelData![0][i] = 0 }
            continuation.finish()
        }.value
        var iterator = stream.makeAsyncIterator()
        let next = await iterator.next()
        let audio = try XCTUnwrap(next)
        XCTAssertEqual(audio.buffer.format.sampleRate, 16000)
        XCTAssertGreaterThan(audio.buffer.frameLength, 1000)
        XCTAssertEqual(audio.buffer.floatChannelData![0][500], 0.25, accuracy: 0.01)
    }
    func testIMECompositionDoesNotSendAndHardwareShiftKeepsNewline() {
        XCTAssertEqual(ComposerReturnKey.action(replacement: "\n", isComposing: true, keepsLineBreak: false), .insert)
        XCTAssertEqual(ComposerReturnKey.action(replacement: "\n", isComposing: false, keepsLineBreak: true), .insert)
        XCTAssertEqual(ComposerReturnKey.action(replacement: "\n", isComposing: false, keepsLineBreak: false), .send)
    }
    func testComposerHoldVoiceOnlyStartsFromAnEmptyEnabledDraft() {
        XCTAssertTrue(ComposerHoldGesture.eligible(text: "", enabled: true))
        XCTAssertFalse(ComposerHoldGesture.eligible(text: "已经写了字", enabled: true))
        XCTAssertFalse(ComposerHoldGesture.eligible(text: " ", enabled: false))
    }
    func testComposerHoldTrackerRoutesBeginMoveReleaseAndCancel() {
        var events: [String] = []; var move: (CGFloat, CGFloat)?
        let hold = ComposerHoldGesture(begin: { events.append("begin") }, move: { move = ($0, $1) }, release: { events.append("release") }, cancel: { events.append("cancel") })
        let tracker = ComposerHoldTracker()
        XCTAssertFalse(tracker.began(y: 100, hold: nil)); XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(tracker.began(y: 100, hold: hold)); XCTAssertEqual(events, ["begin"])
        XCTAssertFalse(tracker.began(y: 90, hold: hold)); XCTAssertEqual(events, ["begin"])
        tracker.changed(y: 80, threshold: 85)
        XCTAssertEqual(move?.0, 20); XCTAssertEqual(move?.1, 85)
        tracker.ended(); tracker.ended(); XCTAssertEqual(events, ["begin", "release"])
        XCTAssertTrue(tracker.began(y: 10, hold: hold))
        tracker.cancelled(); tracker.cancelled(); XCTAssertEqual(events, ["begin", "release", "begin", "cancel"])
        XCTAssertFalse(tracker.isTracking)
    }
    func testComposerKeepsEightLineHeightAndSendKey() {
        let view = ComposerText.makeTextView()
        XCTAssertEqual(view.returnKeyType, .send)
        view.text = Array(repeating: "这是一段很长的草稿文字。", count: 80).joined(separator: "\n")
        XCTAssertLessThanOrEqual(ComposerText.fittingHeight(of: view, width: 320), view.font!.lineHeight * 8 + 20)
    }
    func testAccessibleVoiceRequiresExplicitStartThenFinish() {
        let control = HoldControl(frame: .zero); var starts = 0, finishes = 0
        control.begin = { starts += 1 }; control.release = { finishes += 1 }
        XCTAssertEqual(starts, 0)
        XCTAssertTrue(control.accessibilityActivate()); XCTAssertEqual(starts, 1); XCTAssertEqual(finishes, 0)
        XCTAssertTrue(control.accessibilityActivate()); XCTAssertEqual(starts, 1); XCTAssertEqual(finishes, 1)
    }
    func testFirstUnsentDraftRemainsAddressableAfterRestart() throws {
        let model = NextModel(), origin = try DSHOrigin("https://draft-restart.invalid")
        model.client = DSHClient(credential: .init(origin: origin, cookie: "synthetic")); defer { model.client?.shutdown() }
        model.editText("尚未发送的第一条草稿")
        let restored = try XCTUnwrap(model.storage).load(origin: origin)
        XCTAssertEqual(restored.lastSession, model.current)
        XCTAssertEqual(restored.drafts[model.current]?.text, "尚未发送的第一条草稿")
    }
    func testWorkspaceChangeCreatesDraftAndPreservesSource() throws {
        let model = NextModel()
        let credential = DSHCredential(origin: try DSHOrigin("https://native-test.invalid"), cookie: "synthetic")
        model.client = DSHClient(credential: credential); defer { model.client?.shutdown() }
        model.current = "existing"; var draft = NextDraft(); draft.text = "未发送"; draft.model = .object(["model": .str("m")]); model.local.drafts["existing"] = draft
        let workspace: Wire = .object(["workspaceId": .str("new"), "path": .str("/tmp/new")])
        model.chooseWorkspace(workspace)
        XCTAssertTrue(model.isDraft); XCTAssertEqual(model.draft.text, "未发送")
        XCTAssertEqual(model.draft.workspace, workspace); XCTAssertEqual(model.local.drafts["existing"]?.text, "未发送")
    }
    func testNativeRichRendererLaysOutLongMarkdownInPhoneWidth() async throws {
        let view = NativeRichContent(source: "# 回答\n\n| 名称 | 说明 |\n|---|---|\n| 原生 | 支持表格 |\n\n```swift\nlet value = 42\n```\n\n**完成**，继续输入。", link: { URL(string: $0) }, image: { _, _ in AnyView(EmptyView()) })
        let host = UIHostingController(rootView: view)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene); window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(300))
        let size = host.sizeThatFits(in: CGSize(width: 353, height: 10000))
        XCTAssertGreaterThan(size.height, 100); XCTAssertLessThanOrEqual(size.width, 353)
    }
}
