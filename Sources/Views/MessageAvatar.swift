import SwiftUI

/// Avatar nhỏ (28pt) đặt cạnh nhóm tin nhắn nhận — hiện ở tin nhắn cuối
/// của mỗi nhóm liên tiếp cùng người gửi, theo phong cách Messenger.
struct MessageAvatar: View {
    var imageName: String?

    var body: some View {
        AvatarImage(imageName: imageName, size: 28)
    }
}
