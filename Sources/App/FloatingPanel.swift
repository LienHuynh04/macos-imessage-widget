import AppKit
import SwiftUI

/// NSPanel nổi chính của ứng dụng — cửa sổ borderless, tự vẽ toàn bộ chrome.
///
/// Hành vi đã triển khai:
/// - Borderless + nền trong suốt: không title bar hệ thống, header do SwiftUI tự xây.
/// - Góc bo 20pt + bóng đổ (qua layer của contentView + hasShadow của window).
/// - `.nonactivatingPanel`: hiện lên không cướp focus/active app khác.
/// - `level = .floating`: nằm trên cửa sổ ứng dụng thông thường.
/// - `collectionBehavior`: bám theo mọi Space, hiện được trên Space fullscreen
///   (chỉ là "được phép hiện", không chiếm fullscreen).
/// - `canBecomeKey = true` (nhận bàn phím khi cần), `canBecomeMain = false`.
///
/// GIỚI HẠN của macOS với cửa sổ luôn nổi — không có API nào đảm bảo "trên hết mãi mãi":
/// - `.floating` vẫn nằm DƯỚI `.statusBar`, menu bar, Control Center, pop-up/menu
///   hệ thống và `.screenSaver`. Không thể phủ lên các thành phần hệ thống này,
///   cũng không phủ được hộp thoại xin quyền của hệ thống.
/// - App khác hoàn toàn có thể chọn level cao hơn (ví dụ `.statusBar`) — đây là
///   cuộc đua không có người thắng chắc chắn, macOS không cho "khóa" vị trí.
/// - Không có `.fullScreenAuxiliary` thì panel biến mất khi chuyển sang Space
///   đang fullscreen; không có `.canJoinAllSpaces` thì panel kẹt ở một Space.
/// - Panel non-activating không tự thành key window; muốn nhận phím phải
///   override `canBecomeKey = true` như dưới đây.

final class FloatingPanel: NSPanel {

    /// Kho tin nhắn trong bộ nhớ — nguồn sự thật duy nhất của hội thoại.
    let conversationStore = ConversationStore()
    /// Bong bóng tròn khi thu nhỏ — nil khi đang hiện cửa sổ chat đầy đủ.
    /// Chỉ tồn tại tối đa 1 instance tại một thời điểm (không trùng lặp).
    private var bubble: BubbleWindow?
    /// Frame cửa sổ chat trước khi thu về bubble — để mở lại đúng vị trí.
    private var savedChatFrame: NSRect?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: DesignTokens.Window.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        // Nền trong suốt bên ngoài vùng giao diện.
        isOpaque = false
        backgroundColor = .clear

        // Bóng đổ nhẹ. Với window non-opaque, macOS vẽ bóng theo vùng nội dung
        // nhìn thấy được (đã bo góc ở contentView bên dưới).
        hasShadow = true

        // Luôn nổi trên cửa sổ ứng dụng thông thường.
        isFloatingPanel = true
        level = .floating

        // Bám theo mọi Space + được hiện trên Space fullscreen.
        // Không bao giờ tự fullscreen hay chiếm Desktop.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Panel phụ trợ: không ẩn khi app khác active; không Dock icon
        // (kết hợp LSUIElement trong Info.plist + .accessory trong AppDelegate).
        // Không dùng API Accessibility nào.
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = true

        minSize = DesignTokens.Window.minSize

        // SwiftUI content.
        // - Nút × gọi close() → vì đây là cửa sổ duy nhất,
        //   AppDelegate.applicationShouldTerminateAfterLastWindowClosed cho app thoát.
        //   Đó là hành vi chuẩn của single-panel utility.
        // - Nút thu nhỏ gọi minimizeToBubble(): ẩn panel, hiện bong bóng tròn 68pt
        //   ở góc dưới-phải vị trí cũ. Bấm bong bóng → expandFromBubble().
        // - Nút gọi thoại/video: giao diện only, không thực hiện cuộc gọi.
        let actions = ChatHeaderActions(
            onClose: { [weak self] in self?.close() },
            onMinimize: { [weak self] in self?.minimizeToBubble() },
            onVoiceCall: {},
            onVideoCall: {}
        )
        // Container bo góc: KHÔNG chạm trực tiếp vào layer của NSHostingView,
        // vì can thiệp layer của hosting view có thể khiến SwiftUI không render.
        let container = NSView(frame: NSRect(origin: .zero, size: DesignTokens.Window.defaultSize))
        container.wantsLayer = true
        container.layer?.cornerRadius = DesignTokens.Window.cornerRadius
        container.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: RootView(
            store: conversationStore,
            config: MockData.headerConfig,
            actions: actions
        ))
        // NSHostingView(rootView:) tạo view với frame zero — phải set frame
        // rõ ràng, nếu không nội dung SwiftUI không hiện.
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)
        contentView = container

        print("[iMessageMini][DEBUG] FloatingPanel init — frame: \(frame)")

        center()

        // Theo dõi đổi màn hình/độ phân giải để kéo cửa sổ về vùng hiển thị.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // Borderless window mặc định không key được → override để nhận bàn phím khi cần.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Hiện / ẩn / đưa ra trước an toàn

    /// Hiện panel. Đã hiện thì đưa ra trước. Không active app, không cướp focus.
    func showPanel() {
        print("[iMessageMini][DEBUG] showPanel — before: isVisible=\(isVisible), frame=\(frame)")
        ensureVisibleOnScreen()
        // orderFrontRegardless (thay vì makeKeyAndOrderFront) để giữ đúng
        // ngữ nghĩa non-activating của panel phụ trợ.
        orderFrontRegardless()
        print("[iMessageMini][DEBUG] showPanel — after: isVisible=\(isVisible), frame=\(frame)")
    }

    // MARK: - Thu nhỏ thành bong bóng / mở lại

    /// Thu nhỏ cửa sổ chat thành bong bóng tròn 68pt.
    /// Không làm gì nếu đã ở dạng bubble (chống tạo trùng lặp).
    func minimizeToBubble() {
        guard bubble == nil, isVisible else { return }
        savedChatFrame = frame

        let bubbleWindow = BubbleWindow()
        bubbleWindow.onExpand = { [weak self] in self?.expandFromBubble() }
        bubble = bubbleWindow

        // Đặt bubble ở góc dưới-phải của vị trí panel hiện tại.
        let origin = NSPoint(
            x: frame.maxX - DesignTokens.Bubble.diameter - 24,
            y: frame.minY + 24
        )

        // Fade panel ra (0.18s) rồi mới hiện bubble — ngắn, không giật.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1 // reset để lần hiện sau không bị trong suốt
            bubbleWindow.show(at: origin)
        })
    }

    /// Mở lại cửa sổ chat từ bong bóng, đúng vị trí trước khi thu nhỏ.
    func expandFromBubble() {
        guard let bubbleWindow = bubble else { return }
        bubble = nil

        if let saved = savedChatFrame {
            setFrame(saved, display: false)
        }
        ensureVisibleOnScreen()

        // Fade bubble ra, fade panel vào.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            bubbleWindow.animator().alphaValue = 0
        }, completionHandler: {
            bubbleWindow.close()
        })
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            self.animator().alphaValue = 1
        }, completionHandler: nil)
    }

    /// Đổi màn hình/độ phân giải: kéo panel và bubble về vùng hiển thị.
    @objc private func screenParametersChanged() {
        if isVisible {
            ensureVisibleOnScreen()
        }
        bubble?.repositionOnScreen()
    }

    /// Kéo cửa sổ về vùng hiển thị nếu bị văng ra ngoài
    /// (đổi màn hình, đổi độ phân giải, rút màn hình ngoài).
    private func ensureVisibleOnScreen() {
        guard let screen = self.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let minVisible: CGFloat = 80  // giữ ít nhất 80pt nhìn thấy được
        var frame = self.frame
        frame.origin.x = min(max(frame.origin.x, visible.minX - frame.width + minVisible),
                            visible.maxX - minVisible)
        frame.origin.y = min(max(frame.origin.y, visible.minY - frame.height + minVisible),
                            visible.maxY - minVisible)
        setFrame(frame, display: true)
    }
}
