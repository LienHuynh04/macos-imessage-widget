import AppKit
import SwiftUI

/// Cửa sổ bong bóng tròn khi thu nhỏ cửa sổ chat.
///
/// Cùng app, cùng kiến trúc với FloatingPanel (không phải app riêng):
/// - Borderless, nền trong suốt, `level = .floating`, bám mọi Space.
/// - Non-activating: hiện/kéo không cướp focus app khác.
/// - Kéo thả: SwiftUI DragGesture → `setFrameOrigin` (không cần quyền Accessibility,
///   vì chỉ di chuyển cửa sổ của chính app mình).
/// - Bấm (không kéo): gọi `onExpand` để mở lại cửa sổ chat.
final class BubbleWindow: NSPanel {

    /// Gọi khi người dùng bấm (không kéo) vào bong bóng.
    var onExpand: (() -> Void)?

    /// Gốc frame lúc bắt đầu kéo — để cộng translation tương đối.
    private var dragAnchor: NSPoint?

    init() {
        super.init(
            contentRect: NSRect(
                x: 0, y: 0,
                width: DesignTokens.Bubble.diameter, height: DesignTokens.Bubble.diameter
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: BubbleView(
            onTap: { [weak self] in self?.onExpand?() },
            onDragChanged: { [weak self] translation in self?.dragChanged(translation) },
            onDragEnded: { [weak self] in self?.dragEnded() }
        ))
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Hiện bong bóng tại vị trí cho trước (tự clamp trong vùng hiển thị).
    /// Không active app, không cướp focus.
    func show(at point: NSPoint) {
        setFrameOrigin(keepOnScreen(point))
        orderFrontRegardless()
    }

    /// Kéo lại vào vùng hiển thị khi đổi màn hình/độ phân giải.
    func repositionOnScreen() {
        setFrameOrigin(keepOnScreen(frame.origin))
    }

    // MARK: - Kéo thả

    private func dragChanged(_ translation: CGSize) {
        if dragAnchor == nil { dragAnchor = frame.origin }
        guard let anchor = dragAnchor else { return }
        // SwiftUI: y dương khi kéo xuống; AppKit origin: y dương hướng lên.
        setFrameOrigin(NSPoint(
            x: anchor.x + translation.width,
            y: anchor.y - translation.height
        ))
    }

    private func dragEnded() {
        dragAnchor = nil
        setFrameOrigin(keepOnScreen(frame.origin))
    }

    /// Giữ bong bóng trong vùng hiển thị, chừa mép 8pt.
    private func keepOnScreen(_ origin: NSPoint) -> NSPoint {
        guard let screen = self.screen ?? NSScreen.main else { return origin }
        let visible = screen.visibleFrame
        let margin: CGFloat = 8
        let x = min(max(origin.x, visible.minX + margin),
                    visible.maxX - DesignTokens.Bubble.diameter - margin)
        let y = min(max(origin.y, visible.minY + margin),
                    visible.maxY - DesignTokens.Bubble.diameter - margin)
        return NSPoint(x: x, y: y)
    }
}
