import SwiftUI

/// View gốc: ChatHeader + khu vực hội thoại + thanh soạn tin.
///
/// - Nút × trên header: chỉ đóng cửa sổ (app thoát — single-panel utility).
/// - Nút thu nhỏ: ẩn panel, hiện bong bóng tròn 68pt; bấm bong bóng mở lại đúng vị trí.
/// - Nút gọi thoại/video: giao diện only, không thực hiện cuộc gọi.
/// - ChatComposer: Enter gửi, Shift+Enter xuống dòng; tin nhắn chỉ lưu trong RAM.
struct RootView: View {
    @ObservedObject var store: ConversationStore
    var config: ChatHeaderConfig
    var actions: ChatHeaderActions

    var body: some View {
        VStack(spacing: 0) {
            ChatHeader(config: config, actions: actions)
            ChatConversation(
                messages: store.messages,
                theme: MockData.chatTheme
            )
            ChatComposer(store: store)
        }
        .frame(minWidth: DesignTokens.Window.minWidth, minHeight: DesignTokens.Window.minHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
