import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Thanh soạn tin nhắn dưới cùng cửa sổ chat.
///
/// - Nút: thêm (+), ảnh, sticker, GIF | ô nhập "Aa" | emoji | gửi (khi có nội dung).
/// - Enter: gửi. Shift+Enter: xuống dòng.
/// - Tin nhắn chỉ lưu trong bộ nhớ (ConversationStore), không gửi ra ngoài,
///   không kết nối tài khoản hay dịch vụ nào.
/// - Các nút chưa tích hợp thật (GIF, sticker nâng cao, tiện ích +) được ghi rõ
///   là demo, không giả vờ kết nối dịch vụ.
struct ChatComposer: View {
    var store: ConversationStore

    @State private var text: String = ""
    @State private var showEmojiPicker = false
    @State private var showStickerPicker = false
    @State private var showGifInfo = false
    @State private var showPlusInfo = false

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: DesignTokens.Composer.buttonSpacing) {
            composerButton(systemName: "plus", help: "Tiện ích mở rộng (demo)") {
                showPlusInfo = true
            }
            .popover(isPresented: $showPlusInfo) {
                demoCard(
                    title: "Tiện ích mở rộng",
                    body: "Bản demo — tệp đính kèm, vị trí và các tiện ích khác chưa được tích hợp, không kết nối dịch vụ nào."
                )
            }

            composerButton(systemName: "photo", help: "Chọn ảnh từ máy để gửi") {
                pickPhoto()
            }

            composerButton(systemName: "face.smiling", help: "Sticker (demo, cục bộ)") {
                showStickerPicker = true
            }
            .popover(isPresented: $showStickerPicker) {
                stickerPicker
            }

            gifButton
                .popover(isPresented: $showGifInfo) {
                    demoCard(
                        title: "GIF",
                        body: "Bản demo — chưa kết nối dịch vụ GIF nào. Mọi nội dung đều ở cục bộ."
                    )
                }

            inputField

            composerButton(systemName: "face.smiling.fill", help: "Chèn emoji") {
                showEmojiPicker = true
            }
            .popover(isPresented: $showEmojiPicker) {
                emojiPicker
            }

            if hasContent {
                sendButton
            }
        }
        .animation(.easeOut(duration: DesignTokens.Composer.appearDuration), value: hasContent)
        .padding(.horizontal, DesignTokens.Composer.horizontalPadding)
        .padding(.vertical, DesignTokens.Composer.verticalPadding)
        .background(DesignTokens.Colors.teal)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(DesignTokens.Composer.dividerOpacity))
                .frame(height: DesignTokens.Composer.dividerHeight)
        }
    }

    // MARK: - Ô nhập

    /// Ô nhập cao cố định 64pt, text dài tự cuộn bên trong — không vỡ layout
    /// kể cả ở kích thước cửa sổ tối thiểu.
    private var inputField: some View {
        ZStack(alignment: .topLeading) {
            MessageTextEditor(text: $text, onSend: send)
                .frame(height: DesignTokens.Composer.inputHeight)
            if text.isEmpty {
                Text("Aa")
                    .font(.system(size: DesignTokens.Composer.inputFontSize))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.leading, 14)
                    .padding(.top, 10)
                    .allowsHitTesting(false)
            }
        }
        .background(
            .white.opacity(0.12),
            in: RoundedRectangle(cornerRadius: DesignTokens.Composer.inputCornerRadius,
                                 style: .continuous)
        )
    }

    // MARK: - Các nút

    private func composerButton(
        systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: DesignTokens.Composer.buttonIconSize))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: DesignTokens.Composer.buttonSize,
                       height: DesignTokens.Composer.buttonSize)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var gifButton: some View {
        Button(action: { showGifInfo = true }) {
            Text("GIF")
                .font(.system(size: DesignTokens.Composer.gifFontSize, weight: .heavy))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, DesignTokens.Composer.gifHPadding)
                .padding(.vertical, DesignTokens.Composer.gifVPadding)
                .background(
                    .white.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: DesignTokens.Composer.gifCornerRadius,
                                         style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help("GIF (demo)")
    }

    private var sendButton: some View {
        Button(action: send) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: DesignTokens.Composer.sendIconSize))
                .foregroundStyle(.white)
                .frame(width: DesignTokens.Composer.buttonSize,
                       height: DesignTokens.Composer.buttonSize)
                .background(DesignTokens.Colors.blue, in: Circle())
        }
        .buttonStyle(.plain)
        .help("Gửi (Enter)")
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Popovers

    /// Bảng emoji chèn vào ô nhập — hoạt động thật, cục bộ.
    private var emojiPicker: some View {
        let emojis = ["😀", "😂", "😍", "🥳", "😮", "😢", "🙏", "👏",
                      "👍", "❤️", "🔥", "🎉", "🏔️", "🥶", "👋", "✅"]
        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(36)), count: 8),
            spacing: 4
        ) {
            ForEach(emojis, id: \.self) { emoji in
                Button(emoji) { text += emoji }
                    .font(.system(size: 24))
                    .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 328)
    }

    /// Bảng sticker demo — bấm là gửi ngay sticker dạng message riêng.
    private var stickerPicker: some View {
        let stickers = ["🎉", "🥳", "❤️", "🔥", "👍", "😂"]
        return HStack(spacing: 10) {
            ForEach(stickers, id: \.self) { sticker in
                Button(action: {
                    store.sendSticker(emoji: sticker)
                    showStickerPicker = false
                }) {
                    Text(sticker)
                        .font(.system(size: 40))
                }
                .buttonStyle(.plain)
                .help("Gửi sticker \(sticker) (demo, cục bộ)")
            }
        }
        .padding(12)
    }

    /// Thẻ giải thích cho tính năng demo — nói rõ, không giả vờ có dịch vụ.
    private func demoCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 260)
    }

    // MARK: - Hành vi

    private func send() {
        store.sendText(text)
        text = ""
        // ChatConversation tự cuộn tới tin nhắn mới qua onChange(messages.count).
    }

    /// Mở NSOpenPanel cho người dùng chọn ảnh trên máy (chạy trên main thread).
    private func pickPhoto() {
        let panel = NSOpenPanel()
        panel.message = "Chọn ảnh để gửi"
        panel.prompt = "Gửi"
        panel.allowedContentTypes = [.png, .jpeg, .heic, .webP]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.sendLocalImage(at: url)
    }
}

// MARK: - Ô nhập đa dòng (AppKit)

/// NSTextView bọc trong SwiftUI để kiểm soát phím Enter chắc chắn:
/// Enter gửi, Shift+Enter xuống dòng.
/// (SwiftUI TextEditor/TextField trên macOS không cho kiểm soát hành vi này tin cậy.)
private struct MessageTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onSend: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = ComposerTextView()
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = .systemFont(ofSize: DesignTokens.Composer.inputFontSize)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: DesignTokens.Composer.inputInsetH,
                                             height: DesignTokens.Composer.inputInsetV)
        textView.focusRingType = .none
        textView.toolTip = "Enter để gửi • Shift+Enter để xuống dòng"
        textView.delegate = context.coordinator
        textView.onSend = onSend
        textView.string = text

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ComposerTextView else { return }
        textView.onSend = onSend // luôn dùng closure mới nhất
        if textView.string != text {
            // Giữ vị trí con trỏ khi đồng bộ từ SwiftUI (vd chèn emoji).
            let selected = textView.selectedRange()
            textView.string = text
            let location = min(selected.location, (text as NSString).length)
            textView.setSelectedRange(NSRange(location: location, length: 0))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}

/// NSTextView chặn Enter (không kèm phím bổ trợ) để gửi thay vì xuống dòng.
private final class ComposerTextView: NSTextView {
    var onSend: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76 // return / enter phím số
        let noModifiers = event.modifierFlags
            .intersection([.shift, .control, .option, .command])
            .isEmpty
        if isReturn && noModifiers {
            onSend?()
            return // nuốt phím Enter — không chèn xuống dòng
        }
        super.keyDown(with: event) // Shift+Enter → xuống dòng bình thường
    }
}
