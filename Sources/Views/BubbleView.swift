import SwiftUI

/// Hình bong bóng tròn khi thu nhỏ cửa sổ chat.
///
/// - Tròn 68pt, xanh dương #0084FF, icon tin nhắn trắng (SF Symbols).
/// - Bấm: mở lại cửa sổ chat.
/// - Kéo (di chuyển > 4pt): di chuyển bong bóng trên Desktop.
/// - Hiệu ứng pop nhẹ khi xuất hiện (0.18s, không giật).
struct BubbleView: View {
    var onTap: () -> Void
    var onDragChanged: (CGSize) -> Void
    var onDragEnded: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignTokens.Colors.blue)
            Image(systemName: "message.fill")
                .font(.system(size: DesignTokens.Bubble.iconSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: DesignTokens.Bubble.diameter, height: DesignTokens.Bubble.diameter)
        .scaleEffect(appeared ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: DesignTokens.Bubble.popDuration)) { appeared = true }
        }
        .onTapGesture(perform: onTap)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in onDragChanged(value.translation) }
                .onEnded { _ in onDragEnded() }
        )
    }
}
