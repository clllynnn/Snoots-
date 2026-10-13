import SwiftUI
import UIKit

struct FeedPostCard: View {
    let post: SocialPost
    let language: SnootsLanguage
    let isLiked: Bool
    let onToggleLike: () -> Void
    let onSendComment: (String) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var commentDraft = ""
    @State private var showsAllComments = false
    @State private var showsDeleteConfirmation = false
    @FocusState private var isWritingComment: Bool

    private var shareText: String {
        "\(post.title)\n\(post.owner)・\(post.location)\n\n\(post.localizedBody(language))\n\n分享自 Snoots!"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if post.localPhotoData != nil || !post.galleryPhotoNames.isEmpty {
                    photoCollage
                }
                author
                Text(post.localizedBody(language))
                    .font(.snootsUI(14))
                    .foregroundStyle(SnootsPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                actions
                comments
                commentComposer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
        .confirmationDialog("刪除這篇本機測試貼文？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("刪除貼文", role: .destructive) { onDelete?() }
            Button("保留", role: .cancel) {}
        } message: {
            Text("這篇貼文及其本機留言會從畫面移除，無法復原。")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Text("\(post.month)月")
                    .font(.snootsUI(12, weight: .medium))
                    .foregroundStyle(SnootsPalette.secondaryText)
                Text(String(format: "%02d", post.day))
                    .font(.snootsUI(28, weight: .medium))
                    .foregroundStyle(SnootsPalette.ink)
            }
            .frame(width: 36)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(post.month)月\(post.day)日")

            Text(post.title)
                .font(.snootsUI(20, weight: .semibold))
                .foregroundStyle(SnootsPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if onDelete != nil {
                Menu {
                    Button("刪除貼文", role: .destructive) { showsDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("貼文選單")
            }
        }
    }

    private var photoCollage: some View {
        Group {
            if let data = post.localPhotoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 216)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityLabel("\(post.title)的照片")
            } else {
                staticPhotoCollage
            }
        }
    }

    private var staticPhotoCollage: some View {
        GeometryReader { geometry in
            let gap: CGFloat = 4
            let mainWidth = (geometry.size.width - gap) * 0.67
            let sideWidth = geometry.size.width - mainWidth - gap
            HStack(spacing: gap) {
                photo(at: 0)
                    .frame(width: mainWidth, height: geometry.size.height)
                    .clipped()
                VStack(spacing: gap) {
                    photo(at: 1)
                        .frame(width: sideWidth, height: (geometry.size.height - gap) / 2)
                        .clipped()
                    photo(at: 2)
                        .frame(width: sideWidth, height: (geometry.size.height - gap) / 2)
                        .clipped()
                }
            }
        }
        .frame(height: 216)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(post.title)，三張照片拼貼")
    }

    private func photo(at index: Int) -> some View {
        let name = post.galleryPhotoNames.indices.contains(index) ? post.galleryPhotoNames[index] : (post.photoName ?? "Tofu")
        return Image(name).resizable().scaledToFill()
    }

    private var author: some View {
        HStack(spacing: 7) {
            Image(post.photoName ?? "Tofu")
                .resizable()
                .scaledToFill()
                .frame(width: 25, height: 25)
                .clipShape(Circle())
            Text(post.owner)
                .font(.snootsUI(13, weight: .semibold))
                .foregroundStyle(SnootsPalette.ink)
            if post.isLocallyCreated {
                Text("本機模擬")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.navigationActive)
            }
            Text("・\(post.location)")
                .font(.snootsUI(12))
                .foregroundStyle(SnootsPalette.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        HStack(spacing: 20) {
            Button(action: onToggleLike) {
                Label("\(post.likes + (isLiked ? 1 : 0))", systemImage: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? SnootsPalette.navigationActive : SnootsPalette.ink)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(isLiked ? "取消喜歡" : "喜歡")
            .accessibilityValue("\(post.likes + (isLiked ? 1 : 0)) 個喜歡")

            Button { isWritingComment = true } label: {
                Label("\(post.comments)", systemImage: "bubble.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("留言")
            .accessibilityValue("\(post.comments) 則留言")

            Spacer(minLength: 0)
            ShareLink(item: shareText) {
                Label("分享", systemImage: "square.and.arrow.up")
                    .frame(minHeight: 44)
            }
            .accessibilityLabel("分享貼文")
        }
        .font(.snootsUI(14, weight: .medium))
        .foregroundStyle(SnootsPalette.ink)
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isLiked)
    }

    private var comments: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(showsAllComments ? post.replies : Array(post.replies.suffix(2))) { reply in
                Text("\(Text(reply.author).fontWeight(.semibold))  \(reply.text)")
                    .font(.snootsUI(13))
                    .foregroundStyle(SnootsPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if post.replies.count > 2 {
                Button(showsAllComments ? "收起留言" : "查看全部 \(post.comments) 則留言") {
                    showsAllComments.toggle()
                }
                .font(.snootsUI(12, weight: .medium))
                .foregroundStyle(SnootsPalette.navigationActive)
                .frame(minHeight: 44)
            }
        }
    }

    private var commentComposer: some View {
        HStack(spacing: 4) {
            TextField("留下一句友善的話…", text: $commentDraft, axis: .vertical)
                .font(.snootsUI(14))
                .lineLimit(1...4)
                .focused($isWritingComment)
                .accessibilityLabel("留言內容")
                .padding(.leading, 14)
                .padding(.vertical, 10)
            Button(action: sendComment) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 25))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(SnootsPalette.navigationActive)
            .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
            .accessibilityLabel("送出留言")
        }
        .background(SnootsPalette.canvas, in: RoundedRectangle(cornerRadius: 18))
        .padding(.top, 5)
    }

    private func sendComment() {
        let message = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        onSendComment(message)
        commentDraft = ""
        isWritingComment = false
    }
}
