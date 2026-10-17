import SwiftUI

/// Bảng giá trị thiết kế tập trung của iMessage Mini.
///
/// Mọi số đo (points) và màu sắc (hex) của UI đều khai báo ở đây.
/// Muốn tinh chỉnh giao diện theo screenshot tham chiếu: đổi số trong file này
/// rồi build lại — không cần sửa từng view.
///
/// QUY ƯỚC:
/// - Không đổi tên token khi chỉ tinh chỉnh giá trị.
/// - Token mới đặt theo khu vực (Window / Bubble / Header / Conversation / ...).
/// - Giá trị ở đây là giá trị đang dùng — sửa số là giao diện đổi theo.
enum DesignTokens {

    // MARK: - Màu dùng chung

    enum Colors {
        /// Xanh teal đậm — header, composer, lớp phủ nền hội thoại.
        static let teal = Color(hex: "#064B63")
        /// Xanh dương — bong bóng gửi, nút gửi, bong bóng thu nhỏ.
        static let blue = Color(hex: "#0084FF")
        /// Xám than — bong bóng nhận.
        static let bubbleReceived = Color(hex: "#303A3D")
        /// Teal sáng — đầu gradient (avatar placeholder).
        static let tealLight = Color(hex: "#0E7C9E")
        /// Teal giữa — placeholder ảnh nền.
        static let tealMid = Color(hex: "#0B5C70")
        /// Teal tối — cuối gradient (avatar placeholder, ảnh nền).
        static let tealDark = Color(hex: "#04303F")
        /// Gradient placeholder ảnh tin nhắn.
        static let placeholderTop = Color(hex: "#3A4A4E")
        static let placeholderBottom = Color(hex: "#232B2E")
    }

    // MARK: - Cửa sổ chat (FloatingPanel)

    enum Window {
        static let defaultWidth: CGFloat = 660
        static let defaultHeight: CGFloat = 870
        static var defaultSize: CGSize {
            CGSize(width: defaultWidth, height: defaultHeight)
        }
        static let minWidth: CGFloat = 480
        static let minHeight: CGFloat = 600
        static var minSize: CGSize {
            CGSize(width: minWidth, height: minHeight)
        }
        static let cornerRadius: CGFloat = 20
    }

    // MARK: - Bong bóng thu nhỏ (BubbleWindow / BubbleView)

    enum Bubble {
        static let diameter: CGFloat = 68
        static let iconSize: CGFloat = 28
        static let popDuration: Double = 0.18
    }

    // MARK: - Header chat

    enum Header {
        static let height: CGFloat = 94
        static let avatarSize: CGFloat = 52
        static let avatarNameSpacing: CGFloat = 14
        static let leadingPadding: CGFloat = 16
        static let trailingPadding: CGFloat = 10
        static let nameFontSize: CGFloat = 25
        static let nameDetailSpacing: CGFloat = 6
        static let muteIconSize: CGFloat = 13
        static let buttonSize: CGFloat = 40 // vùng bấm
        static let buttonIconSize: CGFloat = 17
        static let buttonSpacing: CGFloat = 2
        static let dividerOpacity: Double = 0.14
        static let dividerHeight: CGFloat = 0.5
    }

    // MARK: - Khu vực hội thoại

    enum Conversation {
        static let horizontalPadding: CGFloat = 12
        static let topPadding: CGFloat = 10
        static let bottomPadding: CGFloat = 4
        static let groupBottomPadding: CGFloat = 10
        static let groupSpacing: CGFloat = 2 // giữa các bong bóng cùng nhóm
        static let rowSpacing: CGFloat = 8 // avatar ↔ bong bóng
        static let bubbleMaxWidth: CGFloat = 440
        static let bubbleCornerRadius: CGFloat = 22
        static let bubbleHPadding: CGFloat = 14
        static let bubbleVPadding: CGFloat = 9
        static let textSize: CGFloat = 15
        static let avatarSize: CGFloat = 28
        static let sideSpacerMin: CGFloat = 60
        static let senderNameSize: CGFloat = 12
        static let senderNameOpacity: Double = 0.75
        static let senderNameBottomPadding: CGFloat = 2
        static let timeSize: CGFloat = 11
        static let timeOpacity: Double = 0.6
        static let statusIconSize: CGFloat = 11
        static let reactionSize: CGFloat = 13
        static let reactionPadding: CGFloat = 5
        static let reactionYOffset: CGFloat = 12
        static let reactionExtraBottom: CGFloat = 10
        static let footerTopPadding: CGFloat = 2
        static let footerSpacing: CGFloat = 4
    }

    // MARK: - Sticker & ảnh trong tin nhắn

    enum Media {
        static let stickerSize: CGFloat = 120
        static let stickerEmojiSize: CGFloat = 64
        static let imageMaxWidth: CGFloat = 260
        static let imageMaxHeight: CGFloat = 300
        static let imageCornerRadius: CGFloat = 16
        static let imagePlaceholderWidth: CGFloat = 240
        static let imagePlaceholderHeight: CGFloat = 170
    }

    // MARK: - Thanh soạn tin

    enum Composer {
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 10
        static let buttonSpacing: CGFloat = 4
        static let buttonSize: CGFloat = 36 // vùng bấm
        static let buttonIconSize: CGFloat = 18
        static let gifFontSize: CGFloat = 12
        static let gifHPadding: CGFloat = 8
        static let gifVPadding: CGFloat = 6
        static let gifCornerRadius: CGFloat = 8
        static let inputHeight: CGFloat = 64
        static let inputCornerRadius: CGFloat = 20
        static let inputFontSize: CGFloat = 15
        static let inputInsetH: CGFloat = 12
        static let inputInsetV: CGFloat = 10
        static let sendIconSize: CGFloat = 16
        static let appearDuration: Double = 0.15
        static let dividerOpacity: Double = 0.14
        static let dividerHeight: CGFloat = 0.5
    }

    // MARK: - Avatar dùng chung

    enum Avatar {
        static let placeholderIconScale: CGFloat = 0.42
        static let placeholderIconOpacity: Double = 0.9
    }
}
