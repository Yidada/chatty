import SwiftUI
import UIKit

/// The composer's return-key rule, kept as a value so it can be exercised
/// without a keyboard.
enum ComposerReturnKey {
    enum Action: Equatable {
        /// Send the draft. The return key never becomes part of the text.
        case send
        /// Keep the replacement: input-method commit, ⇧↵ line break, or plain typing.
        case insert
    }

    /// - Parameters:
    ///   - replacement: what the text system wants to insert.
    ///   - isComposing: an input method still owns marked text.
    ///   - keepsLineBreak: ⇧↵ asked for a line break on a hardware keyboard.
    static func action(replacement: String, isComposing: Bool, keepsLineBreak: Bool) -> Action {
        guard replacement == "\n", !isComposing, !keepsLineBreak else { return .insert }
        return .send
    }
}

/// DeepSeek 允许在空的文本输入框里长按直接说话，而不必先切到语音模式。
///
/// 只有空草稿才把长按让给语音：一旦框里有文字，长按仍然属于系统文本选择，
/// 这样编辑、选词和光标定位不会被抢走。快速轻点也不会触发录音，仍然是聚焦输入。
struct ComposerHoldGesture {
    var begin: () -> Void
    var move: (CGFloat, CGFloat) -> Void
    var release: () -> Void
    var cancel: () -> Void

    /// 语音长按仅在输入框启用且草稿为空时生效。
    static func eligible(text: String, enabled: Bool) -> Bool { enabled && text.isEmpty }
}

/// 长按说话的纯状态机：识别器只把事件喂进来，宿主测试可以脱离 UIKit 驱动
/// begin / move / release / cancel，覆盖「按下即开始、上滑算取消距离、重复事件不重发」。
final class ComposerHoldTracker {
    private var start: CGFloat?
    private var active: ComposerHoldGesture?
    var isTracking: Bool { start != nil }

    @discardableResult
    func began(y: CGFloat, hold: ComposerHoldGesture?) -> Bool {
        guard start == nil, let hold else { return false }
        start = y; active = hold; hold.begin(); return true
    }
    func changed(y: CGFloat, threshold: CGFloat) {
        guard let start, let active else { return }
        active.move(start - y, threshold)
    }
    func ended() {
        guard start != nil else { return }
        start = nil; active?.release(); active = nil
    }
    func cancelled() {
        guard start != nil else { return }
        start = nil; active?.cancel(); active = nil
    }
}

/// Mika 对话输入框。
///
/// 软键盘回车键就是发送，这一点无法用竖向增长的 `TextField` 表达：`axis: .vertical`
/// 会把回车变成换行，既不回调 `onSubmit` 也不接受 `.submitLabel(.send)`。因此这里用
/// 同一套系统文本栈的 `UITextView`，只把回车键语义显式定下来：
///
/// - 回车发送草稿，且换行符不会进入草稿；
/// - 输入法组词中的回车只上屏候选词：此时 `markedTextRange` 非空、替换文本是候选词而不是
///   `"\n"`，所以中文输入永远不会把「上屏」当成「发送」；
/// - 硬件键盘 `⇧↵` 保留手动换行；未按修饰键的回车与软键盘一致，都是发送；
/// - 草稿仍按 `lineLimit(1...8)` 增长到八行，再多就在框内滚动。
struct ComposerText: UIViewRepresentable {
    /// 与 `.lineLimit(1...8)` 对齐的最大行数。
    static let maximumLines: CGFloat = 8

    @Binding var text: String
    @Binding var focused: Bool
    var enabled: Bool
    var onSubmit: () -> Void
    var accessibilityLabel: String = "和 Mika 说点什么…"
    /// 空草稿时把长按交给语音；旧 Mika 输入框不传，行为不变。
    var hold: ComposerHoldGesture? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 输入框共享的初始配置：`makeUIView` 与宿主测试都用它。
    static func makeTextView() -> ComposerTextView {
        let view = ComposerTextView()
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.returnKeyType = .send
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.accessibilityIdentifier = "chat.draft"
        view.accessibilityLabel = "和 Mika 说点什么…"
        return view
    }

    /// 八行封顶后的框高；超出部分交给 `isScrollEnabled`。
    static func fittingHeight(of view: UITextView, width: CGFloat) -> CGFloat {
        let fitting = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return min(fitting.height, maximumHeight(for: view))
    }

    func makeUIView(context: Context) -> UITextView {
        let view = Self.makeTextView()
        view.delegate = context.coordinator
        view.accessibilityLabel = accessibilityLabel
        let recognizer = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.holdChanged(_:)))
        recognizer.minimumPressDuration = 0.25
        // 移动要留给自己判断上滑取消，不能被识别器的默认 10pt 容差提前判失败。
        recognizer.allowableMovement = .greatestFiniteMagnitude
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        context.coordinator.holdRecognizer = recognizer
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text {
            view.text = text
            view.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        }
        if view.isEditable != enabled { view.isEditable = enabled; view.isSelectable = enabled }
        if focused != view.isFirstResponder {
            if focused { view.becomeFirstResponder() } else { view.resignFirstResponder() }
        }
        if view.bounds.width > 1 {
            let fitting = view.sizeThatFits(CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude))
            view.isScrollEnabled = fitting.height > Self.maximumHeight(for: view)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 1, width < .greatestFiniteMagnitude else { return nil }
        return CGSize(width: width, height: Self.fittingHeight(of: uiView, width: width))
    }

    private static func maximumHeight(for view: UITextView) -> CGFloat {
        let line = (view.font ?? UIFont.preferredFont(forTextStyle: .body)).lineHeight
        return line * maximumLines + view.textContainerInset.top + view.textContainerInset.bottom
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: ComposerText
        var holdRecognizer: UILongPressGestureRecognizer?
        private let holdTracker = ComposerHoldTracker()
        init(_ parent: ComposerText) { self.parent = parent }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let action = ComposerReturnKey.action(replacement: text,
                                                 isComposing: textView.markedTextRange != nil,
                                                 keepsLineBreak: (textView as? ComposerTextView)?.keepsLineBreak ?? false)
            guard action == .send else { return true }
            parent.onSubmit()
            return false
        }

        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }

        func textViewDidBeginEditing(_ textView: UITextView) { if !parent.focused { parent.focused = true } }

        func textViewDidEndEditing(_ textView: UITextView) { if parent.focused { parent.focused = false } }

        /// 长按开始即视为按下说话：识别器已经消化了 0.25 秒阈值，之后的移动用于上滑取消。
        @objc func holdChanged(_ recognizer: UILongPressGestureRecognizer) {
            let location = recognizer.location(in: recognizer.view?.window)
            switch recognizer.state {
            case .began:
                _ = holdTracker.began(y: location.y, hold: parent.hold)
            case .changed:
                let threshold = (recognizer.view?.window?.bounds.height ?? 852) * 0.1
                holdTracker.changed(y: location.y, threshold: threshold)
            case .ended:
                holdTracker.ended()
            case .cancelled, .failed:
                holdTracker.cancelled()
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === holdRecognizer else { return true }
            guard let view = gestureRecognizer.view as? UITextView else { return false }
            return parent.hold != nil && ComposerHoldGesture.eligible(text: view.text ?? "", enabled: view.isEditable)
        }
    }
}

/// 只把 `⇧↵` 留给手动换行；不带修饰键的回车仍然是发送。
final class ComposerTextView: UITextView {
    private(set) var keepsLineBreak = false

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        keepsLineBreak = presses.contains { press in
            guard let key = press.key, key.keyCode == .keyboardReturnOrEnter else { return false }
            return key.modifierFlags.contains(.shift)
        }
        super.pressesBegan(presses, with: event)
        keepsLineBreak = false
    }
}
