import SwiftUI
import AppKit

enum ChattyTheme {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.66, green: 0.80, blue: 0.72, alpha: 1)
            : NSColor(red: 0.21, green: 0.37, blue: 0.31, alpha: 1)
    })
    static let onAccent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .black : .white
    })
}
enum AppTab: String, CaseIterable, Hashable { case activity, chat, projects }
extension Notification.Name {
    static let chattySettings = Notification.Name("chatty.settings")
    static let chattyNavigate = Notification.Name("chatty.navigate")
}
