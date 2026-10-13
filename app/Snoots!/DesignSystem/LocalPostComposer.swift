import PhotosUI
import SwiftUI
import UIKit

struct LocalPostComposer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SnootsAccountSession.self) private var account
    let store: SnootsStore
    @State private var bodyText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isPreparingPhoto = false
    @State private var isPublishing = false
    @State private var error: String?

    private var canPublish: Bool {
        account.usesPreviewAccount &&
            (!bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photoData != nil)
    }

    var body: some View {
        Form {
            Section {
                Label(account.usesPreviewAccount
                      ? "本機測試發文：不會公開、上傳或通知其他人；重啟 App 後會消失。"
                      : "正式發文尚未串接；只有 Debug 模擬帳號可建立本機貼文。",
                      systemImage: "testtube.2")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("分享內容") {
                TextField("寫下今天和狗狗的故事…", text: $bodyText, axis: .vertical)
                    .lineLimit(4...10)
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(photoData == nil ? "選擇一張照片" : "更換照片", systemImage: "photo")
                }
                if isPreparingPhoto { ProgressView("正在準備照片…") }
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                    Button("移除照片", role: .destructive) {
                        self.photoData = nil
                        selectedPhoto = nil
                    }
                }
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            if isPublishing { ProgressView("正在建立本機貼文…") }
        }
        .navigationTitle("發文")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }.disabled(isPublishing)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("發布") { publish() }
                    .disabled(!canPublish || isPreparingPhoto || isPublishing)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { photoData = nil; return }
            isPreparingPhoto = true
            error = nil
            Task {
                defer { isPreparingPhoto = false }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let compressed = image.jpegData(compressionQuality: 0.72) else {
                    error = "照片讀取失敗，請重新選取。"
                    return
                }
                photoData = compressed
            }
        }
    }

    private func publish() {
        guard canPublish else { return }
        isPublishing = true
        store.publishLocalPost(text: bodyText, photoData: photoData)
        isPublishing = false
        dismiss()
    }
}
