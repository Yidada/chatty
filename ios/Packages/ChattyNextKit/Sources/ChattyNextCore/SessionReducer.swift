import Foundation

public struct TranscriptMessage: Identifiable, Equatable, Sendable {
    public var id: String
    public var seq: Int?
    public var role: String
    public var content: [Wire]
    public var pending: Bool = false
    public var interrupted: Bool = false
    public var requestID: String?
    public var text: String { content.filter { $0["type"].text == "text" }.map { $0["text"].text }.joined(separator: "\n") }
    public init(id: String, seq: Int? = nil, role: String, content: [Wire], pending: Bool = false, interrupted: Bool = false, requestID: String? = nil) {
        self.id = id; self.seq = seq; self.role = role; self.content = content; self.pending = pending; self.interrupted = interrupted; self.requestID = requestID
    }
}

/// Mirrors dsh's block-index assembler: closing a block replaces its deltas exactly once.
public struct StreamBlocks: Sendable {
    private var order: [Int] = []
    private var blocks: [Int: Wire] = [:]
    private var closed: Set<Int> = []
    public init() {}
    public var content: [Wire] { order.compactMap { blocks[$0] } }
    public mutating func push(_ chunk: Wire) throws {
        let type = chunk["type"].text
        if ["usage", "finish"].contains(type) { return }
        guard let index = chunk["index"].int, index >= 0 else { throw NextError.protocolMismatch("内容区块索引") }
        if closed.contains(index) { return }
        if blocks[index] == nil { order.append(index) }
        var block = blocks[index]?.object ?? [:]
        switch type {
        case "block-start":
            if blocks[index] != nil { return }
            block = ["type": chunk["blockType"], "text": .str("")]
        case "text-delta", "reasoning-delta":
            guard let delta = chunk["text"].string else { throw NextError.protocolMismatch("增量文字") }
            block["type"] = .str(type == "text-delta" ? "text" : "reasoning")
            block["text"] = .str((block["text"]?.text ?? "") + delta)
        case "tool-call-delta":
            block["type"] = .str("tool-call"); block["id"] = chunk["id"]
            if chunk["name"].string != nil { block["name"] = chunk["name"] }
            block["arguments"] = .str((block["arguments"]?.text ?? "") + chunk["argumentsDelta"].text)
        case "block-end":
            guard chunk["block"]["type"].string != nil else { throw NextError.protocolMismatch("完整内容区块") }
            block = chunk["block"].object; closed.insert(index)
        default: throw NextError.protocolMismatch("未识别的增量 \(type)")
        }
        blocks[index] = .object(block)
    }
    public mutating func loadCompact(_ records: [Wire]) throws {
        for record in records {
            let type = record["type"].text
            if type == "chunk" { try push(record["chunk"]); continue }
            guard ["text-chunks", "reasoning-chunks", "tool-call-chunks"].contains(type), let index = record["index"].int else { throw NextError.protocolMismatch("压缩增量") }
            let values = record[type == "tool-call-chunks" ? "args" : "texts"].array
            guard values.count == record["dt"].array.count, values.allSatisfy({ $0.string != nil }) else { throw NextError.protocolMismatch("压缩增量成员") }
            if type == "tool-call-chunks" {
                try push(.object(["type": .str("tool-call-delta"), "index": .number(Double(index)), "id": record["id"], "name": record["name"], "argumentsDelta": .str(values.map(\.text).joined())]))
            } else {
                try push(.object(["type": .str(type == "text-chunks" ? "text-delta" : "reasoning-delta"), "index": .number(Double(index)), "text": .str(values.map(\.text).joined())]))
            }
        }
    }
}

public struct SessionReducer: Sendable {
    public private(set) var sessionID = ""
    public private(set) var cwd = ""
    public private(set) var cursor = -1
    public private(set) var hasMore = false
    public private(set) var projections: Wire = .null
    public private(set) var events: [Wire] = []
    public private(set) var streamRevision = 0
    private var attempt: Attempt?
    private struct Attempt: Sendable { var id: String; var turn: Int; var step: Int; var nextIndex: Int; var blocks: StreamBlocks; var committedSeq: Int? }
    public init() {}
    public var live: Bool { attempt != nil }
    public var messages: [TranscriptMessage] {
        var result: [TranscriptMessage] = []
        for event in events {
            let seq = event["seq"].int, data = event["data"], type = event["type"].text
            if type == "user/message" {
                // Only human-authored prompts belong in the conversation surface.
                guard data["source"]["kind"].text == "user" else { continue }
                result.append(.init(id: "event-\(seq ?? -1)", seq: seq, role: "user", content: data["content"].array, requestID: data["source"]["rpcId"].string))
            } else if type == "assistant/message" || type == "assistant/attempt" {
                if let a = attempt, a.turn == data["turn"].int, a.step == data["step"].int, a.committedSeq == nil { continue }
                var content = data["message"]["content"].array
                if content.isEmpty { var b = StreamBlocks(); if (try? b.loadCompact(data["stream"].array)) != nil { content = b.content } }
                if !content.isEmpty { result.append(.init(id: "event-\(seq ?? -1)", seq: seq, role: "assistant", content: content, interrupted: data["interrupted"].bool || type == "assistant/attempt")) }
            } else if type == "tool/call" {
                result.append(.init(id: "event-\(seq ?? -1)", seq: seq, role: "tool", content: [.object(["type": .str("text"), "text": .str(data["name"].text)])]))
            } else if type == "tool/result" {
                result.append(.init(id: "event-\(seq ?? -1)", seq: seq, role: "tool-result", content: data["message"]["content"].array))
            }
        }
        if let a = attempt, a.committedSeq == nil || !events.contains(where: { $0["seq"].int == a.committedSeq }) {
            result.append(.init(id: "attempt-" + a.id, role: "assistant", content: a.blocks.content, pending: true))
        }
        return result
    }
    public mutating func updateProjection(_ key: String, value: Wire) { var values = projections.object; values[key] = value; projections = .object(values) }
    public var knownRequestIDs: Set<String> { Set(events.compactMap { $0["type"].text == "user/message" ? $0["data"]["source"]["rpcId"].string : nil }) }
    public mutating func apply(_ frame: Wire) throws {
        switch frame["type"].text {
        case "snapshot":
            guard let id = frame["header"]["id"].string, let cursor = frame["cursor"].int, frame["header"]["version"].int == DSHProtocol.sessionFormat else { throw NextError.protocolMismatch("会话快照") }
            sessionID = id; cwd = frame["header"]["cwd"].text; self.cursor = cursor; events = []; attempt = nil
            hasMore = frame["hasMore"].bool; projections = frame["projections"]["values"]
            for r in frame["records"].array { try insert(r["event"]) }
            streamRevision = frame["assistantStream"]["revision"].int ?? 0
            let active = frame["assistantStream"]["activeAttempt"]
            if let id = active["attemptId"].string {
                var blocks = StreamBlocks(); try blocks.loadCompact(active["stream"].array)
                guard let turn = active["turn"].int, let step = active["step"].int, let next = active["nextIndex"].int else { throw NextError.protocolMismatch("活跃回答") }
                attempt = Attempt(id: id, turn: turn, step: step, nextIndex: next, blocks: blocks)
            }
        case "event":
            let e = frame["event"]
            guard let seq = e["seq"].int else { throw NextError.protocolMismatch("事件序号") }
            if seq <= cursor { return }
            guard seq == cursor + 1 else { throw NextError.protocolMismatch("事件缺口，需要重新获取快照") }
            try insert(e); cursor = seq
            if e["type"].text == "session/title", e["data"]["title"].string != nil { updateProjection("title", value: e["data"]["title"]) }
            if attempt?.committedSeq == seq { attempt = nil }
        case "assistant-stream": try applyStream(frame["frame"])
        default: throw NextError.protocolMismatch("会话流帧")
        }
    }
    public mutating func prepend(_ page: Wire, throughSeq: Int) throws {
        guard throughSeq <= cursor else { throw NextError.protocolMismatch("历史快照范围") }
        let previous = events; events = []
        for record in page["records"].array { try insert(record["event"]) }
        for event in previous { try insert(event) }
        hasMore = page["hasMore"].bool
    }
    private mutating func insert(_ event: Wire) throws {
        guard let seq = event["seq"].int, event["type"].string != nil else { throw NextError.protocolMismatch("持久事件") }
        guard DSHProtocol.events.contains(event["type"].text) || event["ignorable"].bool else { throw NextError.protocolMismatch("必需事件 " + event["type"].text) }
        if events.contains(where: { $0["seq"].int == seq }) { return }
        let op = event["surfaceOp"]
        if op["op"].text == "replace" {
            guard let start = op["startSeq"].int, let end = op["endSeq"].int, start <= end, end < seq else { throw NextError.protocolMismatch("历史替换范围") }
            let at = events.firstIndex(where: { $0["seq"].int == start })
            events.removeAll { guard let n = $0["seq"].int else { return false }; return n >= start && n <= end && $0["surfaceOp"] != .null }
            events.insert(event, at: min(at ?? events.count, events.count)); return
        }
        events.append(event)
    }
    private mutating func applyStream(_ frame: Wire) throws {
        guard let revision = frame["revision"].int else { throw NextError.protocolMismatch("增量修订号") }
        if revision <= streamRevision { return }
        guard revision == streamRevision + 1 else { throw NextError.protocolMismatch("增量缺帧，需要恢复") }
        switch frame["type"].text {
        case "start":
            guard let id = frame["attemptId"].string, let turn = frame["turn"].int, let step = frame["step"].int else { throw NextError.protocolMismatch("回答身份") }
            guard attempt == nil else { throw NextError.protocolMismatch("前一回答尚未结算") }
            attempt = Attempt(id: id, turn: turn, step: step, nextIndex: 0, blocks: StreamBlocks())
        case "chunk", "end":
            guard var a = attempt, a.id == frame["attemptId"].text, frame["index"].int == a.nextIndex else { throw NextError.protocolMismatch("回答身份或片段序号") }
            if frame["type"].text == "chunk" { try a.blocks.push(frame["chunk"]); a.nextIndex += 1; attempt = a }
            else if frame["outcome"]["kind"].text == "abandoned" { attempt = nil }
            else {
                guard let seq = frame["outcome"]["seq"].int else { throw NextError.protocolMismatch("回答结算") }
                a.committedSeq = seq; attempt = events.contains(where: { $0["seq"].int == seq }) ? nil : a
            }
        default: throw NextError.protocolMismatch("回答增量类型")
        }
        streamRevision = revision
    }
}
