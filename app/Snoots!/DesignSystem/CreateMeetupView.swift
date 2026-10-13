import PhotosUI
import SwiftUI
import UIKit

struct CreateMeetupView: View {
    let store: SnootsStore
    let language: SnootsLanguage

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedTypeID = ""
    @State private var location = ""
    @State private var navigationLink = ""
    @State private var startDate = Date.now.addingTimeInterval(60 * 60)
    @State private var attendeeLimitText = ""
    @State private var requiresApproval = true
    @State private var selectedSafetyTags: Set<String> = ["Leash on", "Slow introductions"]
    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var coverPhotoData: Data?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?

    private var selectedType: MeetupActivityType? {
        store.meetupActivityTypes.first { $0.id == selectedTypeID }
    }

    private var attendeeLimit: Int? {
        guard let value = Int(attendeeLimitText), value > 0 else { return nil }
        return value
    }

    private var isNavigationLinkValid: Bool {
        let link = navigationLink.trimmingCharacters(in: .whitespacesAndNewlines)
        if link.isEmpty { return true }
        guard let url = URL(string: link) else { return false }
        return ["https", "http"].contains(url.scheme?.lowercased() ?? "") && url.host != nil
    }

    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedType != nil && attendeeLimit != nil
            && isNavigationLinkValid && !isLoadingPhoto
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                coverPhotoPicker
                MeetupEditorTextField("狗聚名稱", text: $title)

                HStack(spacing: 12) {
                    MeetupEditorDateField("日期", date: $startDate, isDate: true, locale: language.locale)
                    MeetupEditorDateField("時間", date: $startDate, isDate: false, locale: language.locale)
                }

                locationFields
                MeetupEditorTextField("聚會主旨", text: $notes, isMultiline: true)
                typeField
                participationSettings
                safetySettings

                Button(action: publish) {
                    Text("發佈狗聚")
                        .font(.snootsButton(17))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 20))
                .controlSize(.large)
                .tint(SnootsPalette.navigationActive)
                .foregroundStyle(.white)
                .disabled(!canPublish)
                .padding(.top, 6)
            }
            .padding(18)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SnootsPalette.canvas)
        .navigationTitle("發起狗聚")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(SnootsPalette.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("發佈", action: publish)
                    .disabled(!canPublish)
            }
        }
        .tint(SnootsPalette.navigationActive)
        .onAppear {
            if selectedTypeID.isEmpty { selectedTypeID = store.meetupActivityTypes.first?.id ?? "" }
        }
        .task(id: selectedPhoto) { await loadSelectedPhoto() }
        .alert("無法載入照片", isPresented: Binding(
            get: { photoError != nil },
            set: { if !$0 { photoError = nil } }
        )) {
            Button("好", role: .cancel) { photoError = nil }
        } message: {
            Text(photoError ?? "請重新選擇照片。")
        }
    }

    private var coverPhotoPicker: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            GeometryReader { geometry in
                ZStack {
                    Group {
                        if let coverPhotoData, let image = UIImage(data: coverPhotoData) {
                            Image(uiImage: image).resizable()
                        } else {
                            Image("MeetupHeroDogs").resizable()
                        }
                    }
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                    Color.black.opacity(0.22)
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(SnootsPalette.navigationActive)
                            if isLoadingPhoto {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 23, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 50, height: 50)
                        Text(coverPhotoData == nil ? "新增封面照片" : "更換封面照片")
                            .font(.snootsUI(15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoadingPhoto)
        .accessibilityLabel("選擇狗聚封面照片")
    }

    private var locationFields: some View {
        VStack(spacing: 0) {
            MeetupEditorTextField("地點", text: $location, isGrouped: true)
            Divider().padding(.horizontal, 16)
            MeetupEditorTextField(
                "導航連結（選填）", text: $navigationLink, isURL: true,
                errorMessage: isNavigationLinkValid ? nil : "請輸入完整的 https:// 或 http:// 連結。",
                isGrouped: true
            )
        }
        .background(Color.black.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var typeField: some View {
        Menu {
            ForEach(store.meetupActivityTypes) { type in
                Button(type.localizedTitle(language)) { selectedTypeID = type.id }
            }
        } label: {
            selectionField("活動類型", value: selectedType?.localizedTitle(language) ?? "選擇類型")
        }
    }

    private func selectionField(_ label: String, value: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.snootsUI(12))
                    .foregroundStyle(SnootsPalette.secondaryText)
                Text(value)
                    .font(.snootsBody())
                    .foregroundStyle(SnootsPalette.ink)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.snootsUI(13, weight: .semibold))
                .foregroundStyle(SnootsPalette.secondaryText)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
        .background(Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var participationSettings: some View {
        VStack(spacing: 0) {
            Toggle("審核參加申請", isOn: $requiresApproval)
                .tint(SnootsPalette.navigationActive)
                .padding(16)
            Divider().padding(.horizontal, 16)
            MeetupEditorTextField(
                "參加上限（狗狗數量）", text: $attendeeLimitText,
                errorMessage: attendeeLimitText.isEmpty || attendeeLimit != nil ? nil : "請輸入大於 0 的狗狗數量。",
                isGrouped: true, keyboardType: .numberPad
            )
        }
        .font(.snootsBody())
        .background(Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var safetySettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("共同約定")
                .font(.snootsUI(12))
                .foregroundStyle(SnootsPalette.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.meetupSafetyOptions) { option in
                        let isSelected = selectedSafetyTags.contains(option.id)
                        Button {
                            if isSelected {
                                selectedSafetyTags.remove(option.id)
                            } else {
                                selectedSafetyTags.insert(option.id)
                            }
                        } label: {
                            Text(option.localizedTitle(language))
                                .font(.snootsChip())
                                .foregroundStyle(isSelected ? .white : SnootsPalette.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? SnootsPalette.navigationActive : Color.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self),
                  UIImage(data: data) != nil else {
                if !Task.isCancelled { photoError = "這張照片無法使用，請選擇其他照片。" }
                return
            }
            guard !Task.isCancelled else { return }
            coverPhotoData = data
        } catch {
            if !Task.isCancelled { photoError = "照片載入失敗，請重新選擇。" }
        }
    }

    private func publish() {
        guard canPublish, let selectedType, let attendeeLimit else { return }
        _ = store.createMeetup(MeetupDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            activityTypeID: selectedType.id,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            navigationLink: navigationLink.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            attendeeLimit: attendeeLimit,
            requiresApproval: requiresApproval,
            safetyTagIDs: Array(selectedSafetyTags),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            hasCoverPhoto: coverPhotoData != nil
        ))
        dismiss()
    }
}
