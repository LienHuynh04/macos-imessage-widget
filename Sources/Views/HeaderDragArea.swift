import AppKit
import SwiftUI

/// Vùng kéo cửa sổ đặt trong header tự vẽ.
///
/// Dùng NSView thật (thay vì SwiftUI DragGesture) để gọi
/// `NSWindow.performWindowDrag(with:)` — cho cảm giác kéo native của macOS.
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

/// NSView trong suốt: click vào vùng này → bắt đầu kéo cửa sổ.
private final class WindowDragHandleView: NSView {
    override func mouseDown(with event: NSEvent) {
        // API chính thức cho custom drag region (macOS 10.11+).
        window?.performWindowDrag(with: event)
    }
}
