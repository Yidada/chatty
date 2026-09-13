import SwiftUI
import ChattyNextCore

@main struct ChattyNextApp: App {
    @StateObject private var model = NextModel()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            NextRoot(model: model)
                .task { await model.restore() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { model.suspend() }
                    if phase == .active, model.client != nil { Task { await model.resume() } }
                }
        }
    }
}
struct NextRoot: View {
    @ObservedObject var model: NextModel
    var body: some View { Group { if model.client == nil { NextConnectionView(model: model) } else { NextChatView(model: model) } }.tint(Color(red: 77/255, green: 107/255, blue: 254/255)) }
}
struct NextConnectionView: View {
    @ObservedObject var model: NextModel
    @State private var address = ""
    @State private var token = ""
    var body: some View {
        NavigationStack {
            Form {
                Section { VStack(alignment: .leading, spacing: 14) { Image(systemName: "desktopcomputer").font(.largeTitle); Text("连接你的 Mac").font(.largeTitle.bold()); Text("对话与文件由这台 Mac 上的 dsh 处理。连接后，就可以直接开始聊。").foregroundStyle(.secondary) }.padding(.vertical, 24) }
                Section {
                    TextField("https://你的机器.ts.net:8443", text: $address).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("next.connection.address")
                    SecureField("dsh 连接凭据", text: $token).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("next.connection.token")
                } header: { Text("连接地址") } footer: { Text("也可以粘贴含 token 的完整连接地址。请确认目标机器，并保持 Tailscale 已连接。") }
                if let error = model.error { Section { Text(error).foregroundStyle(.red) } }
                Section { Button { Task { await model.pair(address: address, token: token); if model.client != nil { token = ""; address = "" } } } label: { HStack { Text(model.busy ? "正在连接…" : "连接 Mac"); if model.busy { ProgressView() } }.frame(maxWidth: .infinity) }.disabled(address.isEmpty || model.busy).accessibilityIdentifier("next.connection.connect") }
            }.navigationTitle("Chatty Next")
        }
    }
}
