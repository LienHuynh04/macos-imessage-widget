import Foundation

/// Kho tin nhắn trong bộ nhớ — nguồn sự thật duy nhất của hội thoại.
///
/// Không mạng, không tài khoản: tin nhắn chỉ sống trong RAM của app,
/// không gửi ra ngoài dưới bất kỳ hình thức nào.
final class ConversationStore: ObservableObject {
    @Published private(set) var messages: [MessageModel]

    init(messages: [MessageModel] = MockData.sampleConversation) {
        self.messages = messages
    }

    /// Gửi tin nhắn text. Bỏ qua nếu nội dung trống.
    func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        append(MessageModel(
            content: .text(trimmed),
            isOwn: true,
            time: Self.currentTime(),
            status: .sent
        ))
    }

    /// Gửi sticker (demo cục bộ — không kết nối dịch vụ sticker nào).
    func sendSticker(emoji: String) {
        append(MessageModel(
            content: .sticker(imageName: nil, fallbackEmoji: emoji),
            isOwn: true,
            time: Self.currentTime(),
            status: .sent
        ))
    }

    /// Gửi ảnh người dùng chọn từ máy. File được copy vào Application Support
    /// để tin nhắn không phụ thuộc vào file gốc (người dùng có thể xóa/di chuyển).
    func sendLocalImage(at url: URL) {
        guard let savedURL = Self.copyToSentFolder(url) else { return }
        append(MessageModel(
            content: .localImage(savedURL),
            isOwn: true,
            time: Self.currentTime(),
            status: .sent
        ))
    }

    // MARK: - Private

    private func append(_ message: MessageModel) {
        messages.append(message)
    }

    private static func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private static func copyToSentFolder(_ url: URL) -> URL? {
        let fm = FileManager.default
        guard let base = fm.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("imessage-mini/sent", isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
            let dest = dir
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            // Copy (không move) — giữ file gốc của người dùng nguyên vẹn.
            try fm.copyItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }
}
