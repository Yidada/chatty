import Foundation

extension AppConfiguration {
    static let fixture = AppConfiguration(baseURL: URL(string: "http://127.0.0.1:8765/")!, isFixture: true, hint: "合成测试验证码：123456")
}
