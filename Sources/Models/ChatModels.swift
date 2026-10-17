import Foundation

// MARK: - Models
//
// DỮ LIỆU GIẢ LẬP 100%, lưu cục bộ. Không đăng nhập, không gọi mạng,
// không đọc iMessage/Messenger.
// Mọi dữ liệu thật sau này sẽ thay thế đúng chỗ MockData, không đổi interface.

// MARK: - Cấu hình header

/// Cấu hình header chat — muốn đổi tên nhóm/avatar chỉ cần sửa ở đây
/// (hoặc truyền config khác vào RootView), không cần đụng vào UI.
struct ChatHeaderConfig {
    /// Tên nhóm hiển thị trên header.
    var groupName: String
    /// Tên file ảnh trong Resources của bundle (có hoặc không cần extension).
    /// nil → dùng avatar placeholder vẽ bằng gradient.
    var avatarImageName: String?
    /// true → hiện icon "đang tắt thông báo" bên dưới tên nhóm.
    var isMuted: Bool
}

// MARK: - Giao diện hội thoại

/// Giao diện khu vực hội thoại: ảnh nền + lớp phủ đảm bảo đọc chữ.
struct ChatTheme {
    /// Tên file ảnh nền trong Resources/Assets (không cần extension).
    /// nil → dùng gradient placeholder vẽ bằng code.
    var backgroundImageName: String?
    /// Độ đậm của lớp phủ teal #064B63 (0...1). Ảnh nền càng sáng/bận
    /// thì tăng giá trị này để chữ vẫn dễ đọc.
    var overlayOpacity: Double
}

// MARK: - Mock data

enum MockData {
    static let headerConfig = ChatHeaderConfig(
        groupName: "Hội bạn thân 🧑🏻‍🎨",
        avatarImageName: nil, // thả ảnh vào Resources/ rồi đặt tên ở đây để dùng ảnh thật
        isMuted: true
    )

    static let chatTheme = ChatTheme(
        backgroundImageName: "chat-background", // file Resources/Assets/chat-background.png
        overlayOpacity: 0.55
    )

    /// Đoạn hội thoại mẫu — nhóm bạn lên kế hoạch đi Đà Lạt.
    static let sampleConversation: [MessageModel] = [
        MessageModel(
            content: .text("Mọi người ơi, cuối tuần này đi Đà Lạt không? 🏔️"),
            isOwn: false, senderName: "An", time: "19:02"
        ),
        MessageModel(
            content: .text("Tui tìm được homestay view đồi thông xinh lắm nè"),
            isOwn: false, senderName: "An", time: "19:02"
        ),
        MessageModel(
            content: .text("Đi chứ! Lâu lắm rồi cả nhóm chưa đi chung"),
            isOwn: false, senderName: "Bình", time: "19:05"
        ),
        MessageModel(
            content: .sticker(imageName: nil, fallbackEmoji: "🎉"),
            isOwn: false, senderName: "Bình", time: "19:05"
        ),
        MessageModel(
            content: .text("Tui ok nha! Mấy giờ mình xuất phát?"),
            isOwn: true, time: "19:07", status: .seen
        ),
        MessageModel(
            content: .text("Sáng thứ 7 đi, 6h tập trung ở bến xe miền Đông nha"),
            isOwn: false, senderName: "Chi", time: "19:08"
        ),
        MessageModel(
            content: .text("Nhớ mang áo ấm đó, tối Đà Lạt lạnh lắm 🥶"),
            isOwn: false, senderName: "Chi", time: "19:08", reaction: "❤️"
        ),
        MessageModel(
            content: .text("Chốt! Để tui book xe trước 👍"),
            isOwn: true, time: "19:09", status: .seen
        ),
        MessageModel(
            content: .image(imageName: nil),
            isOwn: false, senderName: "An", time: "19:10"
        ),
        MessageModel(
            content: .text("Cái này nè, view đẹp không mọi người?"),
            isOwn: false, senderName: "An", time: "19:10"
        ),
    ]
}
