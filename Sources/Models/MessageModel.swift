import Foundation

// MARK: - MessageModel
//
// DỮ LIỆU GIẢ LẬP 100%, lưu cục bộ. Không đăng nhập, không gọi mạng.

// Trạng thái gửi — chỉ dùng cho tin nhắn do mình gửi.
enum MessageStatus: Hashable {
    case sending
    case sent
    case delivered
    case seen
}

/// Loại nội dung tin nhắn.
///
/// MỞ RỘNG: muốn thêm loại mới (file, reply, location, poll...) thì
///  1. thêm case vào enum này,
///  2. thêm một branch render trong MessageBubble.
/// Không cần sửa ChatConversation hay MessageGroup.
enum MessageContent: Hashable {
    case text(String)
    case sticker(imageName: String?, fallbackEmoji: String)
    case image(imageName: String?)
    /// Ảnh người dùng chọn từ máy qua NSOpenPanel (đã copy vào Application Support).
    case localImage(URL)
}

/// Một tin nhắn đơn lẻ.
struct MessageModel: Identifiable, Hashable {
    let id: UUID
    let content: MessageContent
    let isOwn: Bool
    /// Tên người gửi — hiện trên nhóm chat nhận (nil với tin nhắn của mình).
    let senderName: String?
    let senderAvatarName: String?
    /// Giờ hiển thị, vd "19:02".
    let time: String
    /// Trạng thái gửi — chỉ có ý nghĩa khi isOwn == true.
    let status: MessageStatus
    /// Emoji reaction gắn dưới bong bóng, vd "❤️". nil = không có.
    let reaction: String?

    init(
        id: UUID = UUID(),
        content: MessageContent,
        isOwn: Bool,
        senderName: String? = nil,
        senderAvatarName: String? = nil,
        time: String,
        status: MessageStatus = .sent,
        reaction: String? = nil
    ) {
        self.id = id
        self.content = content
        self.isOwn = isOwn
        self.senderName = senderName
        self.senderAvatarName = senderAvatarName
        self.time = time
        self.status = status
        self.reaction = reaction
    }
}

/// Nhóm tin nhắn liên tiếp cùng người gửi — để render tên/avatar 1 lần
/// theo phong cách Messenger, thay vì lặp lại ở mỗi bong bóng.
struct MessageGroup: Identifiable {
    let id: UUID
    let isOwn: Bool
    let senderName: String?
    let senderAvatarName: String?
    var messages: [MessageModel]

    init(isOwn: Bool, senderName: String?, senderAvatarName: String?, messages: [MessageModel]) {
        self.id = UUID()
        self.isOwn = isOwn
        self.senderName = senderName
        self.senderAvatarName = senderAvatarName
        self.messages = messages
    }
}
