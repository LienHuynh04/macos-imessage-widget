import AppKit
import SwiftUI

/// Vùng kéo cửa sổ đặt trong header tự vẽ.
///
/// Dùng NSView thật (thay vì SwiftUI DragGesture) để kéo cửa sổ theo chuột.
/// Không cần quyền Accessibility: đây là kéo cửa sổ của chính app mình,
/// không phải điều khiển cửa sổ của app khác.
///
/// LƯU Ý layout: chỉ đặt view này ở vùng KHÔNG chồng lấn control tương tác
/// (nút ×, ô nhập...), vì NSView sẽ nhận sự kiện click trước SwiftUI.
/// Text/title tĩnh (không tương tác) thì an toàn khi nằm trên nó.
struct HeaderDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowDragHandleView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// NSView trong suốt: kéo chuột trong vùng này → di chuyển cửa sổ.
///
/// Tự cài đặt kéo tay (mouseDown/mouseDragged + setFrameOrigin) thay vì
/// `NSWindow.performWindowDrag(with:)`: chỉ dùng API ổn định từ lâu đời
/// nên build được trên mọi toolchain/SDK, hành vi kéo-thả giữ nguyên.
private final class WindowDragHandleView: NSView {

    /// Vị trí "túm" con trỏ trong hệ tọa độ window lúc bắt đầu kéo.
    private var grabPoint: NSPoint?

    override func mouseDown(with event: NSEvent) {
        grabPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window, let grabPoint = grabPoint else { return }
        // Cả hệ tọa độ window và screen đều y-up, nên chỉ cần cộng trực tiếp
        // độ dịch của con trỏ vào origin: điểm túm giữ nguyên dưới con trỏ
        // trong suốt quá trình kéo.
        let current = event.locationInWindow
        var origin = window.frame.origin
        origin.x += current.x - grabPoint.x
        origin.y += current.y - grabPoint.y
        window.setFrameOrigin(origin)
    }

    override func mouseUp(with event: NSEvent) {
        grabPoint = nil
    }
}
