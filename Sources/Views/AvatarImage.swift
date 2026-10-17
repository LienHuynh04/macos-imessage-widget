import AppKit
import SwiftUI

/// Avatar tròn dùng chung cho toàn app.
///
/// - `imageName`: tên file ảnh trong Resources của bundle (có/không extension).
///   nil hoặc không tìm thấy → placeholder gradient + icon.
/// - Dùng cho header (52pt), cạnh nhóm tin nhắn (28pt), và sau này cho nơi khác.
struct AvatarImage: View {
    var imageName: String?
    var size: CGFloat
    var placeholderSystemName: String = "person.fill"

    @State private var loadedImage: NSImage?

    var body: some View {
        Group {
            if let loadedImage {
                Image(nsImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [DesignTokens.Colors.tealLight, DesignTokens.Colors.teal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    Image(systemName: placeholderSystemName)
                        .font(.system(size: size * DesignTokens.Avatar.placeholderIconScale))
                        .foregroundStyle(.white.opacity(DesignTokens.Avatar.placeholderIconOpacity))
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            if loadedImage == nil {
                loadedImage = AssetLoader.image(named: imageName)
            }
        }
    }
}

/// Đọc tài nguyên ảnh từ thư mục Resources của app bundle.
/// Dùng chung cho avatar, ảnh nền, sticker, ảnh tin nhắn.
/// Cách dùng: thả file vào `Resources/Assets/` (vd `avatar-an.png`),
/// rồi truyền `imageName = "avatar-an"` (không cần extension).
enum AssetLoader {
    static func image(named name: String?) -> NSImage? {
        guard let name, !name.isEmpty else { return nil }
        // Thử đúng tên file trước (đã gồm extension), rồi thử thêm extension phổ biến.
        if let url = Bundle.main.url(forResource: name, withExtension: nil),
           let image = NSImage(contentsOf: url) {
            return image
        }
        for ext in ["png", "jpg", "jpeg", "heic", "webp"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }
}
