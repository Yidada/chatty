import Foundation
import ChattyNextCore

// Explicit opt-in smoke against a supplied service. Credentials stay in a local ignored file.
@main struct NextProbe {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 3 else { print("Usage: NextProbe <local JSON config> <capture directory>"); return }
        let config = try Wire.decode(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
        let credential = try await DSHClient.pair(address: config["address"].text, token: config["token"].text)
        let client = DSHClient(credential: credential); defer { client.shutdown() }
        let catalog = try await client.rpc("session/modelCatalog")
        print("HTTPS authentication and model catalog OK; model groups: \(catalog["groups"].array.count)")
        let workspaceStream = try await client.stream("workspace/follow")
        for try await frame in workspaceStream { guard frame["type"].text == "baseline" else { continue }; print("WSS workspace baseline OK; count: \(frame["value"]["items"].array.count)"); break }
        let controlStream = try await client.stream("session/control")
        for try await frame in controlStream { print("Control frame: \(frame["type"].text)"); break }
        let eventsStream = try await client.stream("$events")
        for try await frame in eventsStream { print("Events frame: \(frame["type"].text)"); break }
        guard config["sendSmoke"].bool else { return }
        let directory = config["workspace"].text
        let workspace = try await client.command("workspace/create", .object(["path": .str(directory)]))
        let id = UUID().uuidString, requestID = UUID().uuidString
        _ = try await client.command("session/create", .object(["sessionId": .str(id), "workspaceId": workspace["workspace"]["workspaceId"]]))
        let selection = catalog["default"]
        _ = try await client.command("session/selectModel", .object(selection.object.merging(["sessionId": .str(id)]) { _, b in b }))
        print("Created controlled smoke session: \(id)")
        let stream = try await client.stream("session/follow", args: .object(["request": .object(["address": .object(["kind": .str("session"), "sessionId": .str(id)]), "maxMessages": .number(60), "assistantStream": .bool(true)])]))
        let capture = URL(fileURLWithPath: CommandLine.arguments[2]); try FileManager.default.createDirectory(at: capture, withIntermediateDirectories: true)
        var reducer = SessionReducer(), frames: [Wire] = [], sent = false
        for try await frame in stream {
            frames.append(frame); try Wire.array(frames).data().write(to: capture.appendingPathComponent("dsh-smoke-frames.json"), options: .atomic)
            try reducer.apply(frame)
            if frame["type"].text == "snapshot", !sent {
                sent = true
                _ = try await client.command("session/prompt", .object(["sessionId": .str(id), "requestId": .str(requestID), "mode": .str("queue"), "content": .array([.object(["type": .str("text"), "text": .str("This is a Chatty Next connection smoke test. Do not use tools or read files. Reply with exactly: Chatty Next connected.")])]), "clientTimeZone": .str(TimeZone.current.identifier)]))
                print("Prompt accepted")
            }
            if !reducer.live, reducer.messages.contains(where: { $0.role == "assistant" && !$0.pending && !$0.text.isEmpty }) {
                print("Durable assistant reply OK; frames: \(frames.count), cursor: \(reducer.cursor), user request reconciled: \(reducer.knownRequestIDs.contains(requestID))")
                break
            }
        }
    }
}
