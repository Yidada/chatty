import Foundation
import Observation
import ChattyFixtureSupport

@MainActor @Observable
final class FixtureModel {
    private(set) var snapshot: FixtureSnapshot?
    private(set) var isLoading = false
    private(set) var error: String?
    @ObservationIgnored private let client: FixtureClient
    @ObservationIgnored private var generation = 0

    init(client: FixtureClient = FixtureClient()) { self.client = client }

    func loadIfNeeded() async {
        guard snapshot == nil, !isLoading, error == nil else { return }
        await reload()
    }

    func reload() async {
        guard !isLoading else { return }
        generation += 1
        let current = generation
        isLoading = true
        error = nil
        defer { if current == generation { isLoading = false } }
        do {
            let value = try await client.snapshot()
            try Task.checkCancellation()
            guard current == generation else { return }
            snapshot = value
        } catch is CancellationError {
            return
        } catch let failure as URLError where failure.code == .cancelled {
            return
        } catch {
            guard current == generation else { return }
            self.error = (error as? FixtureError)?.errorDescription ?? "无法连接本机测试服务，请启动服务后重试。"
        }
    }
}
