import AppKit
import SwiftUI

/// Bong bóng của một tin nhắn.
///
/// - Nhận (trái): nền xám than #303A3D, chữ trắng.
/// - Gửi (phải): nền xanh dương #0084FF, chữ trắng.
/// - Bo tròn 22pt, nội dung tự xuống dòng, giới hạn chiều rộng.
///
/// MỞ RỘNG: thêm loại tin nhắn mới = thêm case vào `MessageContent`
/// + một branch `case` ở switch dưới đây. Không đụng tới các case cũ.
struct MessageBubble: View {
    var message: MessageModel

    var body: some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .font(.system(size: DesignTokens.Conversation.textSize))
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.Conversation.bubbleHPadding)
                .padding(.vertical, DesignTokens.Conversation.bubbleVPadding)
                .background(message.isOwn
                    ? DesignTokens.Colors.blue
                    : DesignTokens.Colors.bubbleReceived)
                .clipShape(RoundedRectangle(
                    cornerRadius: DesignTokens.Conversation.bubbleCornerRadius,
                    style: .continuous
                ))

        case .sticker(let imageName, let fallbackEmoji):
            // Sticker không nằm trong bong bóng — render trần như Messenger.
            Group {
                if let nsImage = AssetLoader.image(named: imageName) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Text(fallbackEmoji)
                        .font(.system(size: DesignTokens.Media.stickerEmojiSize))
                }
            }
            .frame(width: DesignTokens.Media.stickerSize, height: DesignTokens.Media.stickerSize)

        case .image(let imageName):
            // Giữ đúng tỷ lệ gốc (scaledToFit), giới hạn kích thước tối đa.
            if let nsImage = AssetLoader.image(named: imageName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: DesignTokens.Media.imageMaxWidth,
                           maxHeight: DesignTokens.Media.imageMaxHeight)
                    .clipShape(RoundedRectangle(
                        cornerRadius: DesignTokens.Media.imageCornerRadius,
                        style: .continuous
                    ))
            } else {
                // Placeholder khi chưa có ảnh thật.
                LinearGradient(
                    colors: [DesignTokens.Colors.placeholderTop,
                             DesignTokens.Colors.placeholderBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: DesignTokens.Media.imagePlaceholderWidth,
                       height: DesignTokens.Media.imagePlaceholderHeight)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.7))
                )
                .clipShape(RoundedRectangle(
                    cornerRadius: DesignTokens.Media.imageCornerRadius,
                    style: .continuous
                ))
            }

        case .localImage(let url):
            // Ảnh người dùng chọn từ máy — cũng giữ tỷ lệ gốc, giới hạn kích thước.
            if let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: DesignTokens.Media.imageMaxWidth,
                           maxHeight: DesignTokens.Media.imageMaxHeight)
                    .clipShape(RoundedRectangle(
                        cornerRadius: DesignTokens.Media.imageCornerRadius,
                        style: .continuous
                    ))
            } else {
                // File gốc đã bị xóa/di chuyển sau khi gửi.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 240, height: 170)
                    .overlay(
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.6))
                    )
            }
        }
    }
}
