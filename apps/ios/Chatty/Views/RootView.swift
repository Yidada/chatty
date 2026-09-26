import SwiftUI

/// 主界面 = 会话页 + 可滑出的侧边抽屉（参考 ChatGPT / DeepSeek）。
struct RootView: View {
    @State private var isDrawerOpen = false

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                ConversationView(openDrawer: { setDrawer(true) })
            }

            if isDrawerOpen {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { setDrawer(false) }
                    .transition(.opacity)

                DrawerView(close: { setDrawer(false) })
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.84 }
                    .transition(.move(edge: .leading))
                    .gesture(
                        DragGesture().onEnded { value in
                            if value.translation.width < -60 { setDrawer(false) }
                        }
                    )
            }
        }
    }

    private func setDrawer(_ open: Bool) {
        withAnimation(.snappy(duration: 0.28)) {
            isDrawerOpen = open
        }
    }
}
