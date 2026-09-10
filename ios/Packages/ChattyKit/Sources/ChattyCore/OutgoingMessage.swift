import Foundation

public enum OutgoingStatus: String, Codable, Sendable {
    case queued, submitting, held, failed, uncertain
    public var label: String {
        switch self {
        case .queued: "等待发送"
        case .submitting: "发送中"
        case .held: "等待继续"
        case .failed: "发送失败"
        case .uncertain: "待核对"
        }
    }
}

public struct OutgoingMessage: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let content: String
    public let attachments: [Attachment]
    public let projectId: String?
    public let createdAt: Date
    public var status: OutgoingStatus
    public var failure: String?

    public init(content: String, attachments: [Attachment], projectId: String?) {
        id = UUID(); self.content = content; self.attachments = attachments
        self.projectId = projectId; createdAt = Date(); status = .queued
    }
}
