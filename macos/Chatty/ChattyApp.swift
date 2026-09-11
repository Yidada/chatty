import SwiftUI

@main
struct ChattyApp: App {
    var body: some Scene {
        Window("Chatty", id: "main") {
            #if CHATTY_FIXTURE
            AppBootstrap(configuration: .fixture).frame(minWidth: 900, minHeight: 620)
            #else
            AppBootstrap(configuration: .production).frame(minWidth: 900, minHeight: 620)
            #endif
        }
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("设置…") { NotificationCenter.default.post(name: .chattySettings, object: nil) }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("导航") {
                Button("动态") { navigate(.activity) }.keyboardShortcut("1", modifiers: .command)
                Button("Mika") { navigate(.chat) }.keyboardShortcut("2", modifiers: .command)
                Button("项目") { navigate(.projects) }.keyboardShortcut("3", modifiers: .command)
            }
        }
    }
    private func navigate(_ tab: AppTab) { NotificationCenter.default.post(name: .chattyNavigate, object: tab.rawValue) }
}
