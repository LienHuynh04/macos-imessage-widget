import SwiftUI

/// Khu vực hội thoại: cuộn được, tự gom nhóm tin nhắn liên tiếp cùng người gửi,
/// tự cuộn xuống tin nhắn cuối khi mở và khi có tin nhắn mới.
/// Nền là ảnh cục bộ + lớp phủ teal — chữ luôn dễ đọc.
struct ChatConversation: View {
    var messages: [MessageModel]
    var theme: ChatTheme

    /// Gom tin nhắn liên tiếp cùng người gửi thành nhóm.
    private var groups: [MessageGroup] {
        var result: [MessageGroup] = []
        for message in messages {
            if let lastIndex = result.indices.last,
               result[lastIndex].isOwn == message.isOwn,
               result[lastIndex].senderName == message.senderName {
                result[lastIndex].messages.append(message)
            } else {
                result.append(MessageGroup(
                    isOwn: message.isOwn,
                    senderName: message.senderName,
                    senderAvatarName: message.senderAvatarName,
                    messages: [message]
                ))
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groups) { group in
                            MessageGroupView(group: group)
                        }
                        // Mốc để cuộn xuống cuối.
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal, DesignTokens.Conversation.horizontalPadding)
                    .padding(.top, DesignTokens.Conversation.topPadding)
                    .padding(.bottom, DesignTokens.Conversation.bottomPadding)
                }
                .onAppear { scrollToBottom(proxy: proxy, animated: false) }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
        }
    }

    /// Ảnh nền + lớp phủ teal bán trong suốt.
    /// - Ảnh crop vừa khung (`scaledToFill`), không méo tỷ lệ.
    /// - Lớp phủ #064B63 làm nền đồng nhất → chữ đọc được cả vùng sáng/tối.
    /// - Bong bóng tin nhắn vốn đã đục (#303A3D / #0084FF, chữ trắng) nên
    ///   chữ trong bubble luôn đạt tương phản bất kể ảnh nền.
    private var backgroundLayer: some View {
        ZStack {
            if let nsImage = AssetLoader.image(named: theme.backgroundImageName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // Placeholder khi chưa có ảnh nền.
                LinearGradient(
                    colors: [DesignTokens.Colors.tealMid, DesignTokens.Colors.tealDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            DesignTokens.Colors.teal.opacity(theme.overlayOpacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // nền không chặn cuộn / bấm
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        let animation: Animation? = animated ? .easeOut(duration: 0.25) : nil
        withAnimation(animation) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

// MARK: - Nhóm tin nhắn

/// Render một nhóm tin nhắn liên tiếp cùng người gửi:
/// tên người gửi 1 lần trên cùng (nhóm nhận), avatar 1 lần ở tin nhắn cuối
/// (nhóm nhận), giờ + trạng thái gửi dưới tin nhắn cuối.
private struct MessageGroupView: View {
    var group: MessageGroup

    var body: some View {
        VStack(alignment: group.isOwn ? .trailing : .leading,
               spacing: DesignTokens.Conversation.groupSpacing) {
            // Tên người gửi — chỉ nhóm nhận, 1 lần trên cùng.
            if !group.isOwn, let name = group.senderName {
                Text(name)
                    .font(.system(size: DesignTokens.Conversation.senderNameSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(DesignTokens.Conversation.senderNameOpacity)) // nền đã phủ teal tối → dùng trắng mờ
                    .padding(.leading, DesignTokens.Conversation.avatarSize + DesignTokens.Conversation.rowSpacing)
                    .padding(.bottom, DesignTokens.Conversation.senderNameBottomPadding)
            }

            ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                messageRow(message, isLast: index == group.messages.count - 1)
            }

            footer
        }
        .padding(.bottom, DesignTokens.Conversation.groupBottomPadding)
    }

    // MARK: - Một dòng tin nhắn

    private func messageRow(_ message: MessageModel, isLast: Bool) -> some View {
        HStack(alignment: .bottom, spacing: DesignTokens.Conversation.rowSpacing) {
            if message.isOwn {
                Spacer(minLength: DesignTokens.Conversation.sideSpacerMin)
            } else {
                // Avatar chỉ ở tin nhắn cuối nhóm, các tin trên chừa chỗ trống.
                if isLast {
                    MessageAvatar(imageName: group.senderAvatarName)
                } else {
                    Color.clear.frame(width: DesignTokens.Conversation.avatarSize,
                                      height: DesignTokens.Conversation.avatarSize)
                }
            }

            MessageBubble(message: message)
                .frame(maxWidth: DesignTokens.Conversation.bubbleMaxWidth,
                       alignment: message.isOwn ? .trailing : .leading)
                .overlay(alignment: message.isOwn ? .bottomTrailing : .bottomLeading) {
                    // Emoji reaction gắn dưới bong bóng.
                    if let reaction = message.reaction {
                        Text(reaction)
                            .font(.system(size: DesignTokens.Conversation.reactionSize))
                            .padding(DesignTokens.Conversation.reactionPadding)
                            .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                            .offset(y: DesignTokens.Conversation.reactionYOffset)
                    }
                }
                .padding(.bottom, message.reaction != nil
                    ? DesignTokens.Conversation.reactionExtraBottom : 0)

            if !message.isOwn {
                Spacer(minLength: DesignTokens.Conversation.sideSpacerMin)
            }
        }
    }

    // MARK: - Giờ + trạng thái

    @ViewBuilder
    private var footer: some View {
        if let last = group.messages.last {
            HStack(spacing: DesignTokens.Conversation.footerSpacing) {
                if group.isOwn {
                    Spacer(minLength: DesignTokens.Conversation.sideSpacerMin)
                    statusView(for: last)
                }
                Text(last.time)
                    .font(.system(size: DesignTokens.Conversation.timeSize))
                    .foregroundStyle(.white.opacity(DesignTokens.Conversation.timeOpacity)) // nền đã phủ teal tối → dùng trắng mờ
                if !group.isOwn {
                    Spacer(minLength: DesignTokens.Conversation.sideSpacerMin)
                }
            }
            .padding(.leading, group.isOwn ? 0
                : DesignTokens.Conversation.avatarSize + DesignTokens.Conversation.rowSpacing)
            .padding(.top, DesignTokens.Conversation.footerTopPadding)
        }
    }

    @ViewBuilder
    private func statusView(for message: MessageModel) -> some View {
        switch message.status {
        case .seen:
            Text("Đã xem")
                .font(.system(size: DesignTokens.Conversation.timeSize))
                .foregroundStyle(.white.opacity(DesignTokens.Conversation.timeOpacity))
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DesignTokens.Conversation.statusIconSize))
                .foregroundStyle(.blue)
        case .delivered:
            Image(systemName: "checkmark.circle")
                .font(.system(size: DesignTokens.Conversation.statusIconSize))
                .foregroundStyle(.white.opacity(DesignTokens.Conversation.timeOpacity))
        case .sent:
            Text("Đã gửi")
                .font(.system(size: DesignTokens.Conversation.timeSize))
                .foregroundStyle(.white.opacity(DesignTokens.Conversation.timeOpacity))
        case .sending:
            Image(systemName: "clock")
                .font(.system(size: DesignTokens.Conversation.statusIconSize))
                .foregroundStyle(.white.opacity(DesignTokens.Conversation.timeOpacity))
        }
    }
}
