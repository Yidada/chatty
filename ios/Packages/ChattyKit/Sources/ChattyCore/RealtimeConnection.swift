import Foundation

@MainActor final class RealtimeConnection {
    private var run: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private var transport: URLSession?
    private var generation = 0
    func start(api: APIClient, onConnection: @escaping @MainActor (Bool) -> Void, onEvent: @escaping @MainActor (SocketEvent) -> Void) {
        guard run == nil else { return }
        generation += 1
        let generation = generation
        run = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                guard let self, generation == self.generation, let token = api.token, var url = URLComponents(url: api.baseURL, resolvingAgainstBaseURL: false) else { return }
                url.scheme = url.scheme == "https" ? "wss" : "ws"; url.path = "/ws"
                url.queryItems = [.init(name: "workspace_slug", value: api.workspace), .init(name: "client_platform", value: "mobile"), .init(name: "client_os", value: "ios")]
                guard let endpoint = url.url else { return }
                // A dedicated transport lets a background transition tear down
                // the socket immediately without cancelling REST operations.
                let transport = APIClient.makeSession()
                self.transport = transport
                let socket = transport.webSocketTask(with: endpoint); self.socket = socket
                socket.resume()
                var acknowledged = false
                var timeout: Task<Void, Never>? = Task {
                    do { try await Task.sleep(for: .seconds(15)); socket.cancel(with: .policyViolation, reason: nil) } catch { }
                }
                do {
                    let auth = JSONValue.object(["type": .string("auth"), "payload": .object(["token": .string(token)])])
                    try await socket.send(.string(String(decoding: JSONEncoder().encode(auth), as: UTF8.self)))
                    while !Task.isCancelled {
                        let frame = try await socket.receive()
                        let data: Data
                        switch frame { case .data(let value): data = value; case .string(let value): data = Data(value.utf8); @unknown default: continue }
                        guard let event = try? Contracts.decode(SocketEvent.self, from: data) else { continue }
                        if event.type == "auth_error" { throw APIError.http(401) }
                        if event.type == "auth_ack" {
                            acknowledged = true; timeout?.cancel(); timeout = nil; attempt = 0
                            if generation == self.generation { onConnection(true); onEvent(event) }
                        } else if acknowledged && generation == self.generation { onEvent(event) }
                    }
                } catch { }
                timeout?.cancel(); socket.cancel(); transport.invalidateAndCancel()
                if generation == self.generation { onConnection(false) }
                if Task.isCancelled { break }
                do { try await Task.sleep(for: .milliseconds(min(30_000, 1000 << min(attempt, 5)) + Int.random(in: 0...300))) } catch { break }
                attempt += 1
            }
        }
    }
    func stop() {
        generation += 1
        run?.cancel(); run = nil
        socket?.cancel(); socket = nil
        transport?.invalidateAndCancel(); transport = nil
    }
}
