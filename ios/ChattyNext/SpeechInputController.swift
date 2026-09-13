import SwiftUI
import ChattyNextCore
@preconcurrency import AVFoundation
import Speech
import Synchronization

@MainActor final class SpeechInputController: ObservableObject {
    @Published private(set) var phase = "idle"
    @Published private(set) var available = false
    @Published private(set) var cancelArmed = false
    @Published private(set) var level: Float = 0
    @Published var notice: String?
    var onCommit: ((String, String, Int) -> Void)?
    private var gate = VoiceGate()
    private var locale: Locale?
    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var results: Task<Void, Never>?
    private var analysis: Task<Void, Never>?
    private var startup: Task<Void, Never>?
    private var timeout: Task<Void, Never>?
    private var warmed: (SpeechTranscriber, SpeechAnalyzer, AVAudioFormat)?
    private var warming: Task<Void, Never>?
    var active: Bool { ["starting", "recording", "finalizing"].contains(phase) }

    func prepare() async {
        guard phase == "idle", !available else { return }
        phase = "preparing"; notice = "正在准备设备端语音…"
        defer { if phase == "preparing" { phase = "idle" } }
        guard await AVAudioApplication.requestRecordPermission() else { notice = "请在系统设置中允许 Chatty Next 使用麦克风。"; return }
        guard SpeechTranscriber.isAvailable, let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "zh-CN")) else { notice = "当前设备暂不支持中文设备端识别，可继续使用文字输入。"; return }
        do {
            let module = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                notice = "首次使用正在下载中文语音资源…"
                try await request.downloadAndInstall()
            }
            self.locale = locale
            await warm()
            available = true; notice = nil
        } catch { notice = "语音资源准备失败，请联网后重试。" }
    }
    func begin(scope: String, revision: Int) {
        guard available, phase == "idle", let locale else { return }
        notice = nil; cancelArmed = false; level = 0
        let id = gate.begin(scope: scope, revision: revision); phase = "starting"
        startup = Task { [weak self] in
            guard let self else { return }
            do {
                self.warming?.cancel()
                let warm = self.warmed; self.warmed = nil
                let module = warm?.0 ?? SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
                let analyzer = warm?.1 ?? SpeechAnalyzer(modules: [module], options: .init(priority: .userInitiated, modelRetention: .processLifetime))
                self.analyzer = analyzer
                let resolvedFormat: AVAudioFormat?
                if let warm { resolvedFormat = warm.2 } else { resolvedFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) }
                guard let format = resolvedFormat else { throw NextError.protocolMismatch("语音采样格式") }
                if warm == nil { try await analyzer.prepareToAnalyze(in: format) }
                guard self.gate.identity == id, !Task.isCancelled else { await analyzer.cancelAndFinishNow(); return }
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP]); try session.setActive(true)
                let engine = AVAudioEngine(); let source = engine.inputNode.outputFormat(forBus: 0)
                guard source.sampleRate > 0, source.channelCount > 0, let bridge = SpeechAudioBridge(from: source, to: format) else { throw NextError.protocolMismatch("麦克风采样格式") }
                let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .bufferingOldest(128))
                self.input = continuation; self.engine = engine
                self.results = Task { [weak self] in
                    do {
                        for try await result in module.results {
                            guard let self, self.gate.identity == id else { return }
                            self.gate.revise(id, start: result.range.start.seconds, end: CMTimeRangeGetEnd(result.range).seconds, text: String(result.text.characters), stable: result.isFinal)
                        }
                    } catch { guard let self, self.gate.identity == id else { return }; self.fail("语音识别未完成，请重新录音。") }
                }
                self.analysis = Task { [weak self] in
                    do { try await analyzer.start(inputSequence: stream) }
                    catch { guard let self, self.gate.identity == id else { return }; self.fail("音频处理失败，请重新录音。") }
                }
                engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: source, block: makeAudioTap(id: id, bridge: bridge, continuation: continuation))
                engine.prepare(); try engine.start()
                guard self.gate.identity == id else { self.stopAudio(); return }
                self.phase = "recording"; UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self.timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(120)) } catch { return }
                    self?.fail("录音达到两分钟，请分段输入。本次没有发送。")
                }
            } catch { if self.gate.identity == id { self.fail("麦克风启动失败，请检查权限和音频设备。") } }
        }
    }
    // AVAudioEngine calls this on its audio queue. An unannotated closure created
    // inside begin's MainActor task inherits isolation and traps on the device.
    func makeAudioTap(id: VoiceGate.Identity, bridge: SpeechAudioBridge, continuation: AsyncStream<AnalyzerInput>.Continuation) -> @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void {
        { @Sendable [weak self] buffer, _ in
            guard buffer.frameLength > 0 else { return }
            guard let converted = bridge.convert(buffer) else { Task { @MainActor in if self?.gate.identity == id { self?.fail("音频格式转换失败。") } }; return }
            guard converted.frameLength > 0 else { return }
            let amplitude = bridge.level(buffer)
            if case .dropped = continuation.yield(AnalyzerInput(buffer: converted)) { Task { @MainActor in if self?.gate.identity == id { self?.fail("音频处理暂时跟不上，请缩短录音重试。") } } }
            Task { @MainActor in if self?.gate.identity == id { self?.level = amplitude } }
        }
    }
    func move(upward: CGFloat, threshold: CGFloat) {
        guard active, phase != "finalizing", upward > threshold, !cancelArmed else { return }
        gate.armCancel(); cancelArmed = true; UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    func release() {
        guard let id = gate.identity else { return }
        guard phase == "recording", !cancelArmed else { cancel(); return }
        gate.release(id); phase = "finalizing"; stopAudio(); timeout?.cancel()
        guard let analyzer else { cancel(); return }
        timeout = Task { [weak self] in do { try await Task.sleep(for: .seconds(10)) } catch { return }; self?.fail("语音整理超时，本次没有发送。") }
        Task { [weak self] in
            do {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
                guard let self, self.gate.identity == id else { return }
                await self.results?.value
                guard self.gate.identity == id else { return }
                self.gate.finish(id)
                let text = self.gate.consume(scope: id.scope, revision: id.revision)
                self.timeout?.cancel(); self.cleanup(); self.phase = "idle"; self.scheduleWarm()
                if let text, !text.isEmpty { self.onCommit?(text, id.scope, id.revision) } else { self.notice = "未识别到内容" }
            } catch { guard let self, self.gate.identity == id else { return }; self.fail("语音识别未完成，本次没有发送。") }
        }
    }
    func cancel() { gate.cancel(); startup?.cancel(); timeout?.cancel(); stopAudio(); let old = analyzer; cleanup(); phase = "idle"; cancelArmed = false; Task { await old?.cancelAndFinishNow() }; scheduleWarm() }
    func interrupt() { if active { cancel(); notice = "录音已中断，本次没有发送。" } }
    private func warm() async {
        guard let locale, warmed == nil, !active else { return }
        let module = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        let analyzer = SpeechAnalyzer(modules: [module], options: .init(priority: .userInitiated, modelRetention: .processLifetime))
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else { return }
        do { try await analyzer.prepareToAnalyze(in: format) } catch { await analyzer.cancelAndFinishNow(); return }
        guard !Task.isCancelled, !active else { await analyzer.cancelAndFinishNow(); return }
        warmed = (module, analyzer, format)
    }
    private func scheduleWarm() { warming?.cancel(); warming = Task { [weak self] in await self?.warm() } }
    private func fail(_ message: String) { cancel(); notice = message }
    private func stopAudio() { if let engine { engine.stop(); engine.inputNode.removeTap(onBus: 0) }; input?.finish(); input = nil; try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    private func cleanup() { engine = nil; analyzer = nil; results?.cancel(); results = nil; analysis?.cancel(); analysis = nil; level = 0 }
}

/// Used only by the engine's serial audio tap. Each yielded buffer owns its samples.
final class SpeechAudioBridge: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let target: AVAudioFormat
    init?(from: AVAudioFormat, to: AVAudioFormat) { guard let converter = AVAudioConverter(from: from, to: to) else { return nil }; self.converter = converter; target = to }
    func convert(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let size = AVAudioFrameCount(ceil(Double(source.frameLength) * target.sampleRate / source.format.sampleRate) + 32)
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: size) else { return nil }
        let used = Mutex(false); var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in let first = used.withLock { value in let first = !value; value = true; return first }; if !first { state.pointee = .noDataNow; return nil }; state.pointee = .haveData; return source }
        return status == .error || error != nil ? nil : output
    }
    func level(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0; for i in 0..<Int(buffer.frameLength) { sum += channel[i] * channel[i] }
        return min(1, sqrt(sum / Float(buffer.frameLength)) * 8)
    }
}
