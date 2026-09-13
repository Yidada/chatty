import Foundation

/// A recognizer finishing is distinct from the user releasing a valid held gesture.
public struct VoiceGate: Sendable {
    public struct Identity: Equatable, Sendable {
        public let id: UUID
        public let scope: String
        public let revision: Int
    }
    public private(set) var identity: Identity?
    public private(set) var cancelArmed = false
    private var released = false
    private var finalized = false
    private var spans: [Span] = []
    private struct Span: Sendable { let start: Double; let end: Double; let text: String; let stable: Bool }
    public init() {}
    @discardableResult public mutating func begin(scope: String, revision: Int) -> Identity {
        let identity = Identity(id: UUID(), scope: scope, revision: revision)
        self.identity = identity; released = false; finalized = false; cancelArmed = false; spans = []; return identity
    }
    public mutating func armCancel() { cancelArmed = true }
    public mutating func cancel() { identity = nil; spans = []; released = false; finalized = false }
    public mutating func release(_ id: Identity) { guard identity == id else { return }; if cancelArmed { cancel() } else { released = true } }
    public mutating func revise(_ id: Identity, start: Double, end: Double, text: String, stable: Bool) {
        guard identity == id, !finalized, start.isFinite, end.isFinite, end >= start else { return }
        if !stable && spans.contains(where: { $0.stable && $0.start < end && start < $0.end }) { return }
        spans.removeAll { ($0.start < end && start < $0.end) || ($0.start == start && $0.end == end) }
        spans.append(Span(start: start, end: end, text: text, stable: stable))
    }
    public mutating func finish(_ id: Identity) { if identity == id { finalized = true } }
    public var text: String { spans.sorted { $0.start < $1.start }.map(\.text).joined() }
    public mutating func consume(scope: String, revision: Int) -> String? {
        guard let id = identity, id.scope == scope, id.revision == revision, released, finalized, !cancelArmed else { return nil }
        let result = text.trimmingCharacters(in: .whitespacesAndNewlines); cancel(); return result
    }
}
