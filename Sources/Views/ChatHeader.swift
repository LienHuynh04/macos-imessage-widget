import SwiftUI

/// Header của cửa sổ chat — phong cách Messenger.
///
/// - Nền teal đậm #064B63, cao 94pt, đường phân cách mảnh bên dưới.
/// - Trái: avatar tròn 52pt + tên nhóm + icon trạng thái tắt thông báo.
/// - Phải: gọi thoại, gọi video, thu nhỏ (bong bóng), đóng.
/// - Toàn bộ vùng trái (trừ các nút) kéo được cửa sổ nhờ `HeaderDragArea`.
///
/// Muốn đổi tên nhóm/avatar: sửa `ChatHeaderConfig` (truyền vào từ RootView),
/// không cần đụng vào file này.
struct ChatHeader: View {

    var config: ChatHeaderConfig
    var actions: ChatHeaderActions

    var body: some View {
        HStack(spacing: 0) {
            // Vùng trái: avatar + tên — toàn bộ là vùng kéo cửa sổ.
            ZStack(alignment: .leading) {
                HeaderDragArea()
                HStack(spacing: DesignTokens.Header.avatarNameSpacing) {
                    AvatarImage(
                        imageName: config.avatarImageName,
                        size: DesignTokens.Header.avatarSize,
                        placeholderSystemName: "person.2.fill"
                    )
                    VStack(alignment: .leading, spacing: DesignTokens.Header.nameDetailSpacing) {
                        Text(config.groupName)
                            .font(.system(size: DesignTokens.Header.nameFontSize, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if config.isMuted {
                            Image(systemName: "bell.slash.fill")
                                .font(.system(size: DesignTokens.Header.muteIconSize))
                                .foregroundStyle(.white.opacity(0.75))
                                .help("Đang tắt thông báo nhóm")
                        }
                    }
                }
                .padding(.leading, DesignTokens.Header.leadingPadding)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Vùng phải: các nút — nằm ngoài vùng kéo để không bị ăn sự kiện click.
            HStack(spacing: DesignTokens.Header.buttonSpacing) {
                HeaderIconButton(systemName: "phone.fill", help: "Gọi thoại (giao diện mẫu)") {
                    actions.onVoiceCall()
                }
                HeaderIconButton(systemName: "video.fill", help: "Gọi video (giao diện mẫu)") {
                    actions.onVideoCall()
                }
                HeaderIconButton(
                    systemName: "minus",
                    help: "Thu nhỏ thành bong bóng"
                ) {
                    actions.onMinimize()
                }
                HeaderIconButton(systemName: "xmark", help: "Đóng cửa sổ") {
                    actions.onClose()
                }
            }
            .padding(.trailing, DesignTokens.Header.trailingPadding)
        }
        .frame(height: DesignTokens.Header.height)
        .background(DesignTokens.Colors.teal)
        .overlay(alignment: .bottom) {
            // Đường phân cách mảnh bên dưới header.
            Rectangle()
                .fill(.white.opacity(DesignTokens.Header.dividerOpacity))
                .frame(height: DesignTokens.Header.dividerHeight)
        }
    }
}

// MARK: - Actions

/// Các hành động của header. Gọi thoại/video hiện chỉ là giao diện, không thực hiện cuộc gọi.
struct ChatHeaderActions {
    var onClose: () -> Void = {}
    var onMinimize: () -> Void = {}
    var onVoiceCall: () -> Void = {}
    var onVideoCall: () -> Void = {}
}

// MARK: - Nút icon trên header

/// Nút tròn 40pt: vùng bấm đủ lớn, hover sáng nhẹ.
private struct HeaderIconButton: View {
    var systemName: String
    var help: String
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: DesignTokens.Header.buttonIconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: DesignTokens.Header.buttonSize, height: DesignTokens.Header.buttonSize)
                .background(.white.opacity(isHovered ? 0.16 : 0), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}
