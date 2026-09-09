import SwiftUI

enum ChattyTheme {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.078, green: 0.094, blue: 0.082, alpha: 1)
            : UIColor(red: 0.965, green: 0.969, blue: 0.957, alpha: 1)
    })
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.663, green: 0.804, blue: 0.722, alpha: 1)
            : UIColor(red: 0.212, green: 0.369, blue: 0.314, alpha: 1)
    })
    static let onAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    })
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
}

enum AppTab: String, CaseIterable, Hashable {
    case chat, projects, settings
}
