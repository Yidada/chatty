import SwiftUI
import UIKit

struct HoldToTalk: UIViewRepresentable {
    var enabled: Bool
    var begin: () -> Void
    var move: (CGFloat, CGFloat) -> Void
    var release: () -> Void
    var cancel: () -> Void
    func makeUIView(context: Context) -> HoldControl { let view = HoldControl(); updateUIView(view, context: context); return view }
    func updateUIView(_ view: HoldControl, context: Context) { view.isEnabled = enabled; view.begin = begin; view.move = move; view.release = release; view.cancel = cancel }
}
final class HoldControl: UIControl {
    var begin: (() -> Void)?, move: ((CGFloat, CGFloat) -> Void)?, release: (() -> Void)?, cancel: (() -> Void)?
    private var start: CGFloat?
    private var accessibilityRecording = false
    override init(frame: CGRect) {
        super.init(frame: frame); isMultipleTouchEnabled = false
        isAccessibilityElement = true; accessibilityLabel = "按住说话"; accessibilityIdentifier = "next.voice.hold"; accessibilityTraits = .button
        accessibilityHint = "按住录音，松开发送，上滑取消。使用旁白时，激活开始，再次激活发送。"
        accessibilityCustomActions = [UIAccessibilityCustomAction(name: "取消录音", target: self, selector: #selector(cancelAccessibility))]
        let label = UILabel(); label.text = "按住说话"; label.font = .preferredFont(forTextStyle: .body); label.textAlignment = .center; label.translatesAutoresizingMaskIntoConstraints = false; label.isUserInteractionEnabled = false; addSubview(label)
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: leadingAnchor), label.trailingAnchor.constraint(equalTo: trailingAnchor), label.topAnchor.constraint(equalTo: topAnchor), label.bottomAnchor.constraint(equalTo: bottomAnchor)])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { guard isEnabled, start == nil, let touch = touches.first else { return }; start = touch.location(in: window).y; begin?() }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { guard let start, let touch = touches.first else { return }; move?(start - touch.location(in: window).y, (window?.bounds.height ?? 852) * 0.1) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { guard start != nil else { return }; touchesMoved(touches, with: event); start = nil; release?() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { start = nil; cancel?() }
    override func didMoveToWindow() { super.didMoveToWindow(); if window == nil, start != nil { start = nil; cancel?() } }
    override func accessibilityActivate() -> Bool { guard isEnabled else { return false }; accessibilityRecording.toggle(); if accessibilityRecording { begin?() } else { release?() }; return true }
    @objc private func cancelAccessibility() -> Bool { accessibilityRecording = false; cancel?(); return true }
}
