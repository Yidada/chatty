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
/// - 草稿仍按 `lineLimit(1...6)` 增长到六行，再多就在框内滚动。
struct ComposerText: UIViewRepresentable {
    /// 与 `.lineLimit(1...6)` 对齐的最大行数。
    static let maximumLines: CGFloat = 6

    @Binding var text: String
    @Binding var focused: Bool
    var enabled: Bool
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// 输入框共享的初始配置：`makeUIView` 与宿主测试都用它。
    static func makeTextView() -> ComposerTextView {
        let view = ComposerTextView()
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.returnKeyType = .send
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.accessibilityIdentifier = "chat.draft"
        view.accessibilityLabel = "和 Mika 说点什么…"
        return view
    }

    /// 六行封顶后的框高；超出部分交给 `isScrollEnabled`。
    static func fittingHeight(of view: UITextView, width: CGFloat) -> CGFloat {
        let fitting = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return min(fitting.height, maximumHeight(for: view))
    }

    func makeUIView(context: Context) -> UITextView {
        let view = Self.makeTextView()
        view.delegate = context.coordinator
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

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ComposerText
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
