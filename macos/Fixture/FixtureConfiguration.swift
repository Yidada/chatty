import Foundation

extension AppConfiguration {
    static var fixture: AppConfiguration {
        let requested = Int(ProcessInfo.processInfo.environment["CHATTY_FIXTURE_PORT"] ?? "") ?? 8767
        let port = (1024...65535).contains(requested) ? requested : 8767
        return AppConfiguration(baseURL: URL(string: "http://127.0.0.1:\(port)/")!, isFixture: true, hint: "合成测试验证码：123456")
    }
}
