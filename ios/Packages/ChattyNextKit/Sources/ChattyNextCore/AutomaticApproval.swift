import Foundation

/// The Mac owns review and persists it per session. Clients never synthesize an allow result.
public enum AutomaticApproval {
    public static let command = "/chatty-review"
    public static let receipt = "chatty-next:approve-for-me-v1"
    public static func validate(_ response: Wire) throws {
        guard response["result"]["kind"].text == "success", response["result"]["text"].text == receipt else {
            throw NextError.protocolMismatch("Mac 端自动审核组件未就绪，请更新 Chatty 服务组件后重试。")
        }
    }
}
