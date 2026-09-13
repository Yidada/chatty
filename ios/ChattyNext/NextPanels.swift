import SwiftUI
import ChattyNextCore

struct NextHistoryView: View {
    @ObservedObject var model: NextModel
    let close: () -> Void
    let settings: () -> Void
    @State private var query = ""
    @State private var renameID: String?
    @State private var newTitle = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("历史对话").font(.title2.bold()); Spacer(); Button(action: close) { Image(systemName: "xmark") }.accessibilityLabel("关闭历史") }.padding(.horizontal)
            TextField("搜索对话", text: $query).textFieldStyle(.roundedBorder).padding(.horizontal).onChange(of: query) { _, value in Task { await model.search(value) } }
            Button("新对话", systemImage: "plus") { model.newConversation(); close() }.padding(.horizontal)
            List {
                ForEach(model.searchResults ?? model.sessions, id: \.self) { item in
                    let id = item["sessionId"].text
                    Button { model.selectSession(id); close() } label: {
                        HStack { VStack(alignment: .leading, spacing: 6) { Text(model.title(for: item)).foregroundStyle(.primary).lineLimit(2); if let snippet = item["snippet"].string { Text(snippet).font(.caption).foregroundStyle(.secondary).lineLimit(2) } }; Spacer(); if model.running.contains(id) { ProgressView().controlSize(.small) } }
                    }.listRowBackground(id == model.current ? Color.accentColor.opacity(0.08) : .clear)
                    .contextMenu { Button("重命名") { renameID = id; newTitle = model.title(for: item) } }
                }
                if model.searchHasMore { Text("还有更多结果，请增加关键词。 ").font(.caption).foregroundStyle(.secondary) }
            }.listStyle(.plain)
            Button("连接设置", systemImage: "gearshape") { close(); settings() }.padding()
        }.padding(.top, 18).background(Color(uiColor: .systemBackground))
        .alert("重命名对话", isPresented: Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })) {
            TextField("对话名称", text: $newTitle)
            Button("取消", role: .cancel) { renameID = nil }
            Button("保存") { if let id = renameID { Task { await model.rename(id, to: newTitle) } }; renameID = nil }.disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

struct NextPromptView: View {
    @ObservedObject var model: NextModel
    let prompt: Wire
    @State private var selected: [String: Set<String>] = [:]
    @State private var custom: [String: String] = [:]
    @State private var submitting = false
    private var questions: [Wire] { prompt["request"]["questions"].array }
    private var complete: Bool { questions.allSatisfy { !(selected[$0["id"].text] ?? []).isEmpty || !(custom[$0["id"].text] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("需要你的确认", systemImage: "hand.raised").font(.headline)
            if prompt["event"].text == "approval/request" {
                Text(prompt["request"]["toolName"].text).font(.subheadline.bold())
                if let reason = prompt["request"]["reason"].string { Text(reason).font(.callout).textSelection(.enabled) }
                if let call = model.reducer.events.last(where: { $0["type"].text == "tool/call" && $0["data"]["callId"] == prompt["request"]["callId"] }), let bytes = try? call["data"]["arguments"].data(), let content = String(data: bytes, encoding: .utf8) { Text(content).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                HStack { Button("拒绝", role: .destructive) { respond(.str("rejected")) }; Spacer(); Button("仅允许这一次") { respond(.str("allowed-once")) }.buttonStyle(.borderedProminent) }
            } else {
                ForEach(questions, id: \.self) { question in
                    let id = question["id"].text
                    VStack(alignment: .leading, spacing: 10) {
                        Text(question["question"].text).font(.headline)
                        if let detail = question["detail"].string { Text(detail).font(.callout).textSelection(.enabled) }
                        ForEach(question["options"].array, id: \.self) { option in
                            let label = option["label"].text
                            Button {
                                if question["multiSelect"].bool { if selected[id, default: []].contains(label) { selected[id]?.remove(label) } else { selected[id, default: []].insert(label) } }
                                else { selected[id] = [label]; custom[id] = "" }
                            } label: { HStack(alignment: .top) { Image(systemName: selected[id, default: []].contains(label) ? "checkmark.circle.fill" : "circle"); VStack(alignment: .leading) { Text(label); if let description = option["description"].string { Text(description).font(.caption).foregroundStyle(.secondary) } } } }
                        }
                        TextField("输入你的回答", text: Binding(get: { custom[id] ?? "" }, set: { custom[id] = $0; if !question["multiSelect"].bool && !$0.isEmpty { selected[id] = [] } }), axis: .vertical).textFieldStyle(.roundedBorder)
                    }
                }
                Button("提交回答") { respond(.object(["answers": .array(questions.map { q in let id = q["id"].text; return .object(["id": .str(id), "selected": .array((selected[id] ?? []).sorted().map(Wire.str)), "custom": .str(custom[id] ?? "")]) })])) }.buttonStyle(.borderedProminent).disabled(!complete)
            }
            if submitting { ProgressView("正在提交…") }
        }.padding(16).background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.separator)).disabled(submitting || !model.ready)
    }
    private func respond(_ value: Wire) { submitting = true; Task { await model.respond(prompt, value: value); submitting = false } }
}

struct NextCamera: UIViewControllerRepresentable {
    let result: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(result) }
    func makeUIViewController(context: Context) -> UIImagePickerController { let c = UIImagePickerController(); c.sourceType = .camera; c.delegate = context.coordinator; return c }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let result: (UIImage?) -> Void
        init(_ result: @escaping (UIImage?) -> Void) { self.result = result }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { result(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { result(info[.originalImage] as? UIImage) }
    }
}

struct NextImageView: View {
    let client: DSHClient?
    let sessionID: String
    let attachment: Wire
    @State private var image: UIImage?
    @State private var failed = false
    @State private var enlarged = false
    private var scope: String { (client?.credential.origin.key ?? "") + sessionID + attachment["attachmentId"].text }
    var body: some View {
        Group {
            if let image { Button { enlarged = true } label: { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: 14)) }.buttonStyle(.plain).accessibilityLabel(attachment["name"].string ?? "查看图片") }
            else if failed { Text("图片暂不可预览").font(.caption).foregroundStyle(.secondary) }
            else { ProgressView("正在读取图片…") }
        }
        .task(id: scope) {
            image = nil; failed = false
            do {
                guard let client else { return }
                let result = try await client.command("session/attachment", .object(["sessionId": .str(sessionID), "attachmentId": attachment["attachmentId"]]))
                guard !Task.isCancelled, result["attachment"]["attachmentId"] == attachment["attachmentId"], let data = Data(base64Encoded: result["data"].text), let decoded = UIImage(data: data) else { failed = true; return }
                image = decoded
            } catch { if !Task.isCancelled { failed = true } }
        }
        .sheet(isPresented: $enlarged) { NavigationStack { if let image { Image(uiImage: image).resizable().scaledToFit().padding().navigationTitle(attachment["name"].string ?? "图片").toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { enlarged = false } } } } } }
    }
}
