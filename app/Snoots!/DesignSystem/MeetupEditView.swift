import PhotosUI
import SwiftUI
import UIKit

struct MeetupEditView: View {
    let store: SnootsStore
    let language: SnootsLanguage
    private let originalLocation: String
    private let originalNavigationLink: String

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var purpose: String
    @State private var startDate: Date
    @State private var location: String
    @State private var navigationLink: String
    @State private var safetyPrinciples: [String]
    @State private var preparationNotes: String
    @State private var coverPhotoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?

    init(meetup: UpcomingMeetup, store: SnootsStore, language: SnootsLanguage) {
        self.store = store
        self.language = language
        originalLocation = meetup.localizedLocation(language)
        originalNavigationLink = meetup.navigationLink
        _title = State(initialValue: meetup.localizedTitle(language))
        _purpose = State(initialValue: meetup.localizedHostNote(language))
        _startDate = State(initialValue: meetup.startDate)
        _location = State(initialValue: meetup.localizedLocation(language))
        _navigationLink = State(initialValue: meetup.navigationLink)
        _safetyPrinciples = State(initialValue: meetup.safetyPrinciples)
        _preparationNotes = State(initialValue: meetup.preparationNotes)
        _coverPhotoData = State(initialValue: meetup.coverPhotoData)
    }

    private var isNavigationLinkValid: Bool {
        let link = navigationLink.trimmingCharacters(in: .whitespacesAndNewlines)
        if link.isEmpty { return true }
        guard let url = URL(string: link) else { return false }
        return ["https", "http"].contains(url.scheme?.lowercased() ?? "") && url.host != nil
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                MeetupEditorTextField("聚會主旨", text: $purpose, isMultiline: true)

                fieldSection("安全守則", symbol: "checkmark.shield") {
                    ForEach(safetyPrinciples.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.snootsMetadata())
                                .foregroundStyle(SnootsPalette.navigationActive)
                                .frame(width: 24, height: 24)
                                .background(SnootsPalette.primaryTint.opacity(0.5), in: Circle())
                            MeetupEditorTextField("安全守則 \(index + 1)", text: $safetyPrinciples[index], isMultiline: true)
                        }
                        .padding(.vertical, 5)
                    }
                }

                MeetupEditorTextField("行前注意事項", text: $preparationNotes, isMultiline: true)

                checkInControl

                Button(action: save) {
                    Text("儲存變更")
                        .font(.snootsButton(17))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 20))
                .controlSize(.large)
                .tint(SnootsPalette.navigationActive)
                .foregroundStyle(.white)
                .disabled(!canSave)
                .padding(.top, 6)
            }
            .padding(18)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SnootsPalette.canvas)
        .navigationTitle("編輯狗聚")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(SnootsPalette.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("儲存", action: save)
                    .disabled(!canSave)
            }
        }
        .tint(SnootsPalette.navigationActive)
        .task(id: selectedPhoto) {
            await loadSelectedPhoto()
        }
        .onChange(of: location) { previous, current in
            if previous == originalLocation, current != originalLocation,
               navigationLink == originalNavigationLink {
                navigationLink = ""
            }
        }
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
                        Text("更換封面照片")
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
        .accessibilityLabel("更換狗聚封面照片")
    }

    private var checkInControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("現場簽到")
                .font(.snootsCardTitle())
                .foregroundStyle(SnootsPalette.ink)

            Text(store.isUpcomingMeetupCheckInOpen
                 ? "已開放簽到，現場簽到區會顯示在狗聚詳情。"
                 : "開放後，現場簽到區會顯示在狗聚詳情的活動資訊下方。")
                .font(.snootsMetadata())
                .foregroundStyle(SnootsPalette.secondaryText)

            if store.isUpcomingMeetupCheckInOpen {
                Label("已開放活動簽到", systemImage: "checkmark.circle.fill")
                    .font(.snootsButton(16))
                    .foregroundStyle(SnootsPalette.navigationActive)
                    .frame(maxWidth: .infinity, minHeight: 48)
            } else {
                Button("開放活動簽到", action: openCheckIn)
                    .font(.snootsButton(16))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .disabled(!canSave)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func fieldSection<Content: View>(_ title: String, symbol: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let symbol {
                rowLabel(title, symbol: symbol)
            } else {
                Text(title).font(.snootsCardTitle())
            }
            content()
        }
        .foregroundStyle(SnootsPalette.ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func rowLabel(_ title: String, symbol: String) -> some View {
        Label {
            Text(title).foregroundStyle(SnootsPalette.ink)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(SnootsPalette.navigationActive)
                .frame(width: 22)
        }
        .font(.snootsCardTitle())
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

    private func save() {
        guard canSave else { return }
        persistChanges()
        dismiss()
    }

    private func openCheckIn() {
        guard canSave else { return }
        persistChanges()
        store.openUpcomingMeetupCheckIn()
        dismiss()
    }

    private func persistChanges() {
        store.updateUpcomingMeetup(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            navigationLink: navigationLink.trimmingCharacters(in: .whitespacesAndNewlines),
            purpose: purpose.trimmingCharacters(in: .whitespacesAndNewlines),
            safetyPrinciples: safetyPrinciples.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            preparationNotes: preparationNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            coverPhotoData: coverPhotoData
        )
    }
}

struct MeetupEditorDateField: View {
    let label: String
    @Binding var date: Date
    let isDate: Bool
    let locale: Locale
    @State private var isShowingPicker = false

    init(_ label: String, date: Binding<Date>, isDate: Bool, locale: Locale) {
        self.label = label
        _date = date
        self.isDate = isDate
        self.locale = locale
    }

    private var value: String {
        date.formatted(Date.FormatStyle(
            date: isDate ? .numeric : .omitted,
            time: isDate ? .omitted : .shortened
        ).locale(locale))
    }

    var body: some View {
        Button {
            isShowingPicker = true
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.snootsUI(12))
                    .foregroundStyle(SnootsPalette.secondaryText)
                Text(value)
                    .font(.snootsBody())
                    .foregroundStyle(SnootsPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(Color.black.opacity(0.045))
            .overlay(alignment: .bottom) {
                if isShowingPicker {
                    Rectangle()
                        .fill(SnootsPalette.navigationActive)
                        .frame(height: 1.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityHint("開啟\(label)選擇器")
        .sheet(isPresented: $isShowingPicker) {
            NavigationStack {
                VStack {
                    if isDate {
                        DatePicker(label, selection: $date, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    } else {
                        DatePicker(label, selection: $date, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .accessibilityLabel(label)
                    }
                }
                .padding(.horizontal, 18)
                .frame(maxHeight: .infinity, alignment: .top)
                .navigationTitle("選擇\(label)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { isShowingPicker = false }
                    }
                }
            }
            .environment(\.locale, locale)
            .tint(SnootsPalette.navigationActive)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

struct MeetupEditorTextField: View {
    let label: String
    @Binding var text: String
    var isMultiline = false
    var isURL = false
    var errorMessage: String?
    var isGrouped = false
    var keyboardType: UIKeyboardType = .default
    @FocusState private var isFocused: Bool

    init(_ label: String, text: Binding<String>, isMultiline: Bool = false, isURL: Bool = false, errorMessage: String? = nil, isGrouped: Bool = false, keyboardType: UIKeyboardType = .default) {
        self.label = label
        _text = text
        self.isMultiline = isMultiline
        self.isURL = isURL
        self.errorMessage = errorMessage
        self.isGrouped = isGrouped
        self.keyboardType = keyboardType
    }

    private var showsLabel: Bool { isFocused || !text.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            VStack(alignment: .leading, spacing: 3) {
                if showsLabel {
                    Text(label)
                        .font(.snootsUI(12))
                        .foregroundStyle(errorMessage == nil ? SnootsPalette.secondaryText : .red)
                        .accessibilityHidden(true)
                }
                TextField(showsLabel ? "" : label, text: $text, axis: isMultiline ? .vertical : .horizontal)
                    .font(.snootsBody())
                    .foregroundStyle(SnootsPalette.ink)
                    .lineLimit(isMultiline ? 1...6 : 1...1)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .keyboardType(isURL ? .URL : keyboardType)
                    .textInputAutocapitalization(isURL ? .never : .sentences)
                    .autocorrectionDisabled(isURL)
                    .accessibilityLabel(label)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(Color.black.opacity(isGrouped ? 0 : 0.045))
            .overlay(alignment: .bottom) {
                if isFocused || errorMessage != nil {
                    Rectangle()
                        .fill(errorMessage == nil ? SnootsPalette.navigationActive : .red)
                        .frame(height: 1.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: isGrouped ? 0 : 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: isGrouped ? 0 : 18, style: .continuous))
            .onTapGesture { isFocused = true }

            if let errorMessage {
                Text(errorMessage)
                    .font(.snootsMetadata())
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }
        }
    }
}
