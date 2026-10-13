import PhotosUI
import SwiftUI
import UIKit

struct OnboardingFlow: View {
    let store: SnootsStore
    let language: SnootsLanguage
    let account: SnootsAccountSession?
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 48

    @State private var stage: RegistrationStage = .entry
    @State private var ownerName: String
    @State private var petName: String
    @State private var petBreed: String
    @State private var otherBreed = ""
    @State private var petSize: PetSize?
    @State private var petSex: PetSex?
    @State private var neuterStatus: NeuterStatus?
    @State private var selectedSocialStyle: SocialStyle?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var pendingPhoto: UIImage?
    @State private var isCroppingPhoto = false
    @State private var basicSubmission: BasicInformationSubmissionState = .editing
    @State private var submission: RegistrationSubmissionState = .editing
    @State private var validatedFields: Set<RegistrationField> = []
    @State private var attemptedEntryNext = false
    @State private var attemptedNext = false
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    private var pausesSubmissionForPreview = false
    private var pausesBasicCheckingForPreview = false

    init(store: SnootsStore, language: SnootsLanguage, account: SnootsAccountSession? = nil) {
        self.store = store
        self.language = .traditionalChinese
        self.account = account
        _ownerName = State(initialValue: "")
        _petName = State(initialValue: "")
        _petBreed = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if stage == .entry {
                    entryPage
                } else if stage == .basicInformation {
                    basicInformationCanvas
                } else if submission == .editing {
                    progressHeader
                    socialBehaviorPage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    bottomActions
                } else {
                    Text("2 / 2")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    submissionPage
                }
            }
            .background((stage == .entry ? SnootsPalette.lime : SnootsPalette.canvas).ignoresSafeArea())
            .foregroundStyle(SnootsPalette.ink)
            .toolbar(.hidden, for: .navigationBar)
            .tint(SnootsPalette.navigationActive)
            .animation(.snappy, value: stage)
            .animation(.snappy, value: submission)
            .animation(.snappy, value: basicSubmission)
        }
        .environment(\.locale, Locale(identifier: "zh-Hant"))
        .fullScreenCover(isPresented: $isCroppingPhoto) {
            if let pendingPhoto {
                RegistrationPhotoCropView(image: pendingPhoto) {
                    cancelPhotoCrop()
                } onConfirm: { croppedData in
                    photoData = croppedData
                    cancelPhotoCrop()
                }
                .environment(\.locale, Locale(identifier: "zh-Hant"))
            }
        }
        .task(id: selectedPhotoItem) {
            await loadPhoto(from: selectedPhotoItem)
        }
        .task(id: submission) {
            if submission == .submitting && !pausesSubmissionForPreview {
                await submitRegistration()
            }
        }
        .task(id: basicSubmission) {
            if basicSubmission == .checking && !pausesBasicCheckingForPreview {
                await checkBasicInformation()
            }
        }
        .onChange(of: selectedSocialStyle) { _, selection in
            if let selection {
                UIAccessibility.post(notification: .announcement, argument: "已選擇：\(selection.title(language))")
            } else {
                UIAccessibility.post(notification: .announcement, argument: "已取消選取")
            }
        }
        .onChange(of: submission) { _, state in
            if case .failed(let failure) = state {
                UIAccessibility.post(notification: .announcement, argument: "\(failure.title)。\(failure.message)")
            }
        }
    }

    private var entryPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 20)
            Text("開始使用 Snoots!")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 20) {
                OnboardingTextField(
                    title: "飼主暱稱",
                    prompt: "飼主暱稱",
                    text: $ownerName,
                    contentType: .nickname,
                    showsRequiredMark: attemptedEntryNext && validationError(.ownerName) != nil,
                    showsLabel: attemptedEntryNext && validationError(.ownerName) != nil,
                    icon: "person",
                    error: fieldError(.ownerName),
                    onEditingFinished: { validatedFields.insert(.ownerName) }
                )
                Label("透過 Apple 登入", systemImage: "apple.logo")
                    .font(.snootsBody())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            .padding(.top, 32)
            .frame(maxWidth: .infinity)

            Button("下一步") {
                attemptedEntryNext = true
                validatedFields.insert(.ownerName)
                guard entryInformationIsValid else {
                    UIAccessibility.post(notification: .announcement, argument: "請修正飼主資料後再繼續。")
                    return
                }
                stage = .basicInformation
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(fill: SnootsPalette.primary, cornerRadius: 28))
            .padding(.top, 32)
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .light)
    }

    private var entryInformationIsValid: Bool {
        validationError(.ownerName) == nil
    }

    private var basicInformationCanvas: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("基本資料")
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("1/2")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
                Text("建立狗狗的基本檔案")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 12)

            GeometryReader { proxy in
                Capsule()
                    .fill(SnootsPalette.divider)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(SnootsPalette.lime)
                            .frame(width: proxy.size.width * 0.5)
                    }
            }
            .frame(height: 6)
            .padding(.horizontal, 32)
            .padding(.bottom, 36)
            .accessibilityLabel("註冊進度")
            .accessibilityValue("第 1 階段，共 2 階段")

            photoUploadControl
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)

            if basicSubmission == .editing {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if let photoError { inlineError(photoError) }
                        dogInformationFields(spacing: 18, showsPhoto: false)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)

                Button("下一步", action: advance)
                    .buttonStyle(OnboardingPrimaryButtonStyle(fill: SnootsPalette.primary, cornerRadius: 28))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
            } else {
                basicInformationStatusPage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .light)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("遇到陌生狗的反應")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("2/2")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }

            Text("了解\(petName.isEmpty ? "狗狗" : petName)遇到陌生狗時的常見反應")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(SnootsPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { proxy in
                Capsule()
                    .fill(SnootsPalette.divider)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(SnootsPalette.lime)
                            .frame(width: proxy.size.width)
                    }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var basicInformationPage: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = geometry.size.height >= 620 ? 18 : (geometry.size.height >= 590 ? 14 : 12)
            ScrollView(showsIndicators: false) {
                registrationForm(spacing: spacing)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func registrationForm(spacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing >= 18 ? 32 : 24) {
            dogInformationFields(spacing: spacing)
            ownerSummary
        }
        .frame(maxWidth: .infinity)
    }

    private var ownerSummary: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("飼主資料")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(SnootsPalette.secondaryText)
                Text(ownerName)
                    .font(.snootsBody())
                Text("透過 Apple 登入")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(SnootsPalette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button("修改") { stage = .entry }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityLabel("修改飼主暱稱")
        }
        .padding(14)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SnootsPalette.divider, lineWidth: 1)
        }
    }

    private func dogInformationFields(spacing: CGFloat, showsPhoto: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            if showsPhoto {
                HStack {
                    Spacer()
                    photoUploadControl
                    Spacer()
                }
                if let photoError { inlineError(photoError) }
            }

            OnboardingTextField(
                title: "狗勾的名字",
                prompt: "狗勾的名字",
                text: $petName,
                compactPrompt: true,
                showsRequiredMark: attemptedNext && validationError(.petName) != nil,
                error: fieldError(.petName),
                onEditingFinished: { validatedFields.insert(.petName) }
            )

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("品種", field: .breed)
                NavigationLink {
                    BreedPickerView(selection: $petBreed, language: language)
                } label: {
                    HStack(spacing: 12) {
                        Text(petBreed.isEmpty ? "請選擇品種" : petBreed)
                            .font(petBreed.isEmpty ? .system(.subheadline, design: .rounded) : .snootsBody())
                            .foregroundStyle(petBreed.isEmpty ? SnootsPalette.secondaryText : SnootsPalette.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }
                    .foregroundStyle(SnootsPalette.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: fieldHeight)
                    .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(fieldError(.breed) == nil ? SnootsPalette.divider : Color(.systemRed), lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(petBreed.isEmpty ? "品種，尚未選擇" : "品種，\(petBreed)")
                if let error = fieldError(.breed) { inlineError(error) }
                if petBreed == "其他" {
                    OnboardingTextField(
                        title: "補充犬種名稱",
                        prompt: "請輸入犬種名稱",
                        text: $otherBreed,
                        error: attemptedNext && otherBreed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "請補充犬種名稱。" : nil
                    )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("體型", field: .size)
                OnboardingSegmentedControl(
                    title: "體型",
                    options: PetSize.allCases,
                    selection: $petSize,
                    label: { $0.title(language) }
                )
                .frame(height: fieldHeight)
                .frame(maxWidth: .infinity)
                if let error = fieldError(.size) { inlineError(error) }
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("性別", field: .sex)
                    OnboardingSegmentedControl(
                        title: "性別",
                        options: PetSex.allCases,
                        selection: $petSex,
                        label: { $0.title(language) }
                    )
                    .frame(height: fieldHeight)
                    .frame(maxWidth: .infinity)
                    if let error = fieldError(.sex) { inlineError(error) }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("絕育狀況", field: .neuter)
                    OnboardingSegmentedControl(
                        title: "絕育狀況",
                        options: NeuterStatus.allCases,
                        selection: $neuterStatus,
                        label: { $0.title(language) }
                    )
                    .frame(height: fieldHeight)
                    .frame(maxWidth: .infinity)
                    if let error = fieldError(.neuter) { inlineError(error) }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func fieldLabel(_ title: String, field: RegistrationField) -> some View {
        OnboardingFieldLabel(title: title, showsRequiredMark: attemptedNext && validationError(field) != nil)
    }

    private var photoUploadControl: some View {
        photoPicker
            .contextMenu {
                if photoData != nil {
                    Button(role: .destructive) {
                        photoData = nil
                        selectedPhotoItem = nil
                    } label: {
                        Label("移除照片", systemImage: "trash")
                    }
                }
            }
            .accessibilityAction(named: "移除照片") {
                guard photoData != nil else { return }
                photoData = nil
                selectedPhotoItem = nil
            }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            photoAvatar
                .overlay {
                    if isLoadingPhoto {
                        ProgressView()
                            .tint(SnootsPalette.navigationActive)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(isLoadingPhoto)
        .accessibilityLabel(photoData == nil ? "選擇狗狗大頭貼" : "更換狗狗大頭貼")
        .accessibilityHint(photoData == nil ? "點擊中央圓形區域選擇照片" : "點擊中央圓形區域更換照片")
    }

    private var photoAvatar: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                DogHeadSilhouette()
                    .fill(.black, style: FillStyle(eoFill: true))
                    .frame(width: 64, height: 64)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SnootsPalette.surface)
            }
        }
        .frame(width: 144, height: 144)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.10), radius: 7, y: 3)
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(SnootsPalette.navigationActive)
                .frame(width: 36, height: 36)
                .background(SnootsPalette.surface, in: Circle())
                .offset(x: 2, y: 2)
        }
    }

    private var socialBehaviorPage: some View {
        ScrollView(showsIndicators: false) {
            SocialReactionCarousel(selection: $selectedSocialStyle, language: language)
                .padding(.top, 24)
                .padding(.bottom, 20)
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 8) {
            Button("返回") { stage = .basicInformation }
                .font(.snootsButton(17))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 12)
                .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            Button("開始探索 Snoots!", action: advance)
                .buttonStyle(OnboardingPrimaryButtonStyle(fill: SnootsPalette.primary, cornerRadius: 28))
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1 : 0.45)
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(SnootsPalette.canvas)
    }

    private var canAdvance: Bool {
        guard submission == .editing && basicSubmission == .editing && !isLoadingPhoto && !isCroppingPhoto else { return false }
        switch stage {
        case .entry:
            return false
        case .basicInformation:
            // Allow an attempt so missing fields have an actionable error state.
            return true
        case .socialBehavior:
            return basicInformationIsValid && selectedSocialStyle != nil
        }
    }

    private var basicInformationIsValid: Bool {
        RegistrationField.allCases.allSatisfy { validationError($0) == nil }
            && photoData != nil
            && (petBreed != "其他" || !otherBreed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func validationError(_ field: RegistrationField) -> String? {
        switch field {
        case .petName: RegistrationValidation.requiredError(petName, title: "狗勾的名字")
        case .ownerName: RegistrationValidation.requiredError(ownerName, title: "飼主暱稱")
        case .breed: RegistrationValidation.requiredError(petBreed, title: "品種")
        case .size: RegistrationValidation.selectionError(petSize != nil, title: "體型")
        case .sex: RegistrationValidation.selectionError(petSex != nil, title: "性別")
        case .neuter: RegistrationValidation.selectionError(neuterStatus != nil, title: "絕育狀況")
        }
    }

    private func fieldError(_ field: RegistrationField) -> String? {
        validatedFields.contains(field) ? validationError(field) : nil
    }

    private func inlineError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color(.systemRed))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func advance() {
        guard canAdvance else { return }
        if stage == .basicInformation {
            attemptedNext = true
            validatedFields = Set(RegistrationField.allCases)
            if photoData == nil { photoError = "請先上傳狗狗的大頭貼。" }
            guard basicInformationIsValid else { return }
            basicSubmission = .checking
        } else {
            guard selectedSocialStyle != nil else { return }
            submission = .submitting
        }
    }

    @MainActor
    private func checkBasicInformation() async {
        // This is a local check, not a network request. Yield so the disabled/loading state can render.
        await Task.yield()
        guard !Task.isCancelled else { return }
        do {
            try RegistrationValidation.validate(
                ownerName: ownerName, petName: petName,
                breed: petBreed, socialStyle: "待填寫"
            )
            guard photoData != nil else {
                throw RegistrationSubmissionError(message: "請先上傳狗狗的大頭貼。")
            }
            if petBreed == "其他" && otherBreed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw RegistrationSubmissionError(message: "請補充犬種名稱。")
            }
            guard petSize != nil, petSex != nil, neuterStatus != nil else {
                throw RegistrationSubmissionError(message: "請選擇體型、性別與絕育狀況。")
            }
            basicSubmission = .editing
            stage = .socialBehavior
        } catch {
            basicSubmission = .failed(error.localizedDescription)
        }
    }

    private var basicInformationStatusPage: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                switch basicSubmission {
                case .checking:
                    ProgressView().controlSize(.large)
                    Text("正在檢查資料…").font(.snootsSection())
                    resultDescription("請稍候，無需重複點擊下一步。")
                case .failed(let message):
                    resultSymbol("exclamationmark.circle")
                    Text("資料檢查未完成").font(.snootsSection())
                    resultDescription(message)
                    resultDescription("已填內容仍保留，可以重新檢查或返回修改。")
                case .editing:
                    EmptyView()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16))
            Spacer()
            if basicSubmission == .checking {
                Button("下一步") {}
                    .buttonStyle(OnboardingPrimaryButtonStyle(fill: SnootsPalette.primary, cornerRadius: 28))
                    .disabled(true)
                    .opacity(0.45)
                    .accessibilityHint("正在檢查資料，暫時無法重複點擊")
            } else if case .failed = basicSubmission {
                Button("重新檢查") { basicSubmission = .checking }
                    .buttonStyle(OnboardingPrimaryButtonStyle(fill: SnootsPalette.primary, cornerRadius: 28))
                Button("返回修改資料") {
                    basicSubmission = .editing
                    attemptedNext = true
                    validatedFields = Set(RegistrationField.allCases)
                }
                .font(.snootsButton(15))
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    @MainActor
    private func submitRegistration() async {
        // Yield to render the progress state; no artificial network delay or fake API.
        await Task.yield()
        guard !Task.isCancelled else { return }
        guard let selectedSocialStyle, let petSize, let petSex, let neuterStatus,
              let photoData, let account else {
            submission = .failed(.validation("請確認必填資料完整，並選擇一個社交情境。"))
            return
        }
        do {
            try await account.register(RegistrationPayload(
                ownerName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines),
                dogName: petName.trimmingCharacters(in: .whitespacesAndNewlines),
                breed: petBreed,
                otherBreed: petBreed == "其他" ? otherBreed.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                size: petSize.backendValue,
                sex: petSex.backendValue,
                isNeutered: neuterStatus.isNeutered,
                socialStyle: selectedSocialStyle.backendValue,
                photoData: photoData
            ))
            if let owner = account.owner, let dog = account.dog {
                store.applyRegisteredProfile(owner: owner, dog: dog, photoData: account.dogPhotoData)
            }
        } catch {
            submission = .failed(RegistrationFailure(error: error))
        }
    }

    @MainActor
    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoadingPhoto = true
        photoError = nil
        defer { isLoadingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = RegistrationPhotoCropView.previewImage(from: data) else {
                throw RegistrationSubmissionError(message: "無法讀取這張圖片，請重新選擇。")
            }
            guard !Task.isCancelled else { return }
            pendingPhoto = image
            isCroppingPhoto = true
        } catch {
            guard !Task.isCancelled else { return }
            photoError = "無法讀取這張圖片，請重新選擇。"
            selectedPhotoItem = nil
        }
    }

    private func cancelPhotoCrop() {
        isCroppingPhoto = false
        pendingPhoto = nil
        selectedPhotoItem = nil
    }

    private var submissionPage: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                switch submission {
                case .submitting:
                    ProgressView().controlSize(.large)
                    Text("正在儲存資料…").font(.snootsSection())
                    resultDescription("請稍候，無需重複送出。")
                case .failed(let failure):
                    resultSymbol(failure.symbol)
                    Text(failure.title).font(.snootsSection())
                    resultDescription(failure.message)
                    resultDescription("已保留填寫內容，可以重試或返回修改。")
                case .editing:
                    EmptyView()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .contain)
            Spacer()
            if case .failed = submission {
                Button("重新送出") { submission = .submitting }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                Button("返回第 2 步修改") {
                    submission = .editing
                    stage = .socialBehavior
                }
                .font(.snootsButton(15))
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func resultDescription(_ text: String) -> some View {
        Text(text)
            .font(.snootsBody())
            .foregroundStyle(SnootsPalette.secondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func resultSymbol(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 48))
            .foregroundStyle(SnootsPalette.navigationActive)
            .accessibilityHidden(true)
    }
}

private enum RegistrationStage {
    case entry
    case basicInformation
    case socialBehavior
}

private enum RegistrationField: CaseIterable {
    case petName, ownerName, breed, size, sex, neuter
}

private enum RegistrationSubmissionState: Equatable {
    case editing, submitting
    case failed(RegistrationFailure)
}

private enum BasicInformationSubmissionState: Equatable {
    case editing, checking
    case failed(String)
}

private struct OnboardingSegmentedControl<Option: Hashable>: UIViewRepresentable {
    @ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = 17
    let title: String
    let options: [Option]
    @Binding var selection: Option?
    let label: (Option) -> String

    func makeUIView(context: Context) -> OnboardingNativeSegmentedControl {
        let control = OnboardingNativeSegmentedControl(items: options.map(label))
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.addTarget(context.coordinator, action: #selector(Coordinator.selectionChanged(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ control: OnboardingNativeSegmentedControl, context: Context) {
        context.coordinator.parent = self
        let systemFont = UIFont.systemFont(ofSize: fontSize)
        let descriptor = systemFont.fontDescriptor.withDesign(.rounded) ?? systemFont.fontDescriptor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(descriptor: descriptor, size: fontSize),
            .foregroundColor: UIColor.label
        ]
        control.setTitleTextAttributes(attributes, for: .normal)
        control.setTitleTextAttributes(attributes, for: .selected)
        for (index, option) in options.enumerated() {
            control.setTitle(label(option), forSegmentAt: index)
        }
        control.selectedSegmentIndex = selection.flatMap { options.firstIndex(of: $0) } ?? UISegmentedControl.noSegment
        control.accessibilityLabel = title
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: OnboardingSegmentedControl

        init(parent: OnboardingSegmentedControl) {
            self.parent = parent
        }

        @objc func selectionChanged(_ control: UISegmentedControl) {
            guard parent.options.indices.contains(control.selectedSegmentIndex) else { return }
            parent.selection = parent.options[control.selectedSegmentIndex]
        }
    }
}

private final class OnboardingNativeSegmentedControl: UISegmentedControl {
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.height = 48
        return size
    }
}

struct OnboardingFieldLabel: View {
    let title: String
    var showsRequiredMark = false

    var body: some View {
        HStack(alignment: .top, spacing: 3) {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.medium))
            if showsRequiredMark {
                Text("＊")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Color(.systemRed))
                    .offset(y: -2)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(SnootsPalette.secondaryText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsRequiredMark ? "\(title)，必填" : title)
    }
}

private struct OnboardingTextField: View {
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 48
    let title: String
    let prompt: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default
    var compactPrompt = false
    var showsRequiredMark = false
    var showsLabel = true
    var icon: String? = nil
    var error: String? = nil
    var onEditingFinished: () -> Void = {}
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsLabel {
                OnboardingFieldLabel(title: title, showsRequiredMark: showsRequiredMark)
            }
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(SnootsPalette.secondaryText)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                }
                TextField(
                    "",
                    text: $text,
                    prompt: Text(prompt)
                        .font(compactPrompt ? .system(.subheadline, design: .rounded) : .snootsBody())
                        .foregroundColor(SnootsPalette.placeholder)
                )
                    .focused($isFocused)
                    .font(.snootsBody())
                    .textContentType(contentType)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                    .autocorrectionDisabled(keyboardType == .emailAddress)
                    .frame(maxWidth: .infinity, minHeight: fieldHeight)
                    .accessibilityLabel(title)
                    .accessibilityHint(error ?? "必填欄位")
                    .onChange(of: isFocused) { _, focused in
                        if !focused { onEditingFinished() }
                    }
                    .onSubmit(onEditingFinished)
            }
            .padding(.horizontal, 14)
            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(error == nil ? SnootsPalette.divider : Color(.systemRed), lineWidth: 1)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color(.systemRed))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct BreedPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    let language: SnootsLanguage
    @State private var searchText = ""

    private var filteredBreeds: [String] {
        let breeds = ["博美", "柴犬", "貴賓犬", "柯基", "米克斯", "黃金獵犬", "拉布拉多", "法國鬥牛犬", "比熊犬", "臘腸犬", "邊境牧羊犬", "其他"]
        guard !searchText.isEmpty else { return breeds }
        return breeds.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(filteredBreeds, id: \.self) { breed in
            Button {
                selection = breed
                dismiss()
            } label: {
                HStack {
                    Text(breed)
                        .foregroundStyle(SnootsPalette.ink)
                    Spacer()
                    if selection == breed {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(SnootsPalette.navigationActive)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(SnootsPalette.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SnootsPalette.canvas)
        .navigationTitle(language.text("Choose a breed", "選擇品種"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Label("返回", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $searchText, prompt: language.text("Search breeds", "搜尋品種"))
        .overlay {
            if filteredBreeds.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}

private enum PetSize: CaseIterable, Identifiable {
    case small, medium, large

    var id: Self { self }
    var backendValue: String {
        switch self {
        case .small: "small"
        case .medium: "medium"
        case .large: "large"
        }
    }
    var english: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    init(value: String) {
        switch value.lowercased() {
        case "medium", "中型", "中型犬": self = .medium
        case "large", "大型", "大型犬": self = .large
        default: self = .small
        }
    }

    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .small: language.text("Small", "小型")
        case .medium: language.text("Medium", "中型")
        case .large: language.text("Large", "大型")
        }
    }
}

private enum PetSex: CaseIterable, Identifiable {
    case male, female

    var id: Self { self }
    var backendValue: String { self == .male ? "male" : "female" }
    var english: String { self == .male ? "Male" : "Female" }

    init(value: String) {
        self = ["female", "母", "女生"].contains(value.lowercased()) ? .female : .male
    }

    func title(_ language: SnootsLanguage) -> String {
        self == .male ? language.text("Male", "男生") : language.text("Female", "女生")
    }
}

private enum NeuterStatus: CaseIterable, Identifiable {
    case neutered, notNeutered

    var id: Self { self }
    var isNeutered: Bool { self == .neutered }

    init(isNeutered: Bool) {
        self = isNeutered ? .neutered : .notNeutered
    }

    func title(_ language: SnootsLanguage) -> String {
        self == .neutered
            ? language.text("Neutered", "已絕育")
            : language.text("Not neutered", "未絕育")
    }
}

private enum SocialStyle: CaseIterable, Identifiable {
    case proactiveFriendly
    case observeThenInteract
    case fearfulButApproaches
    case fearfulAndHides
    case barksOrGrowls

    var id: Self { self }

    var backendValue: String {
        switch self {
        case .proactiveFriendly: "friendly"
        case .observeThenInteract: "observe_then_interact"
        case .fearfulButApproaches: "fearful_approach"
        case .fearfulAndHides: "fearful_avoid"
        case .barksOrGrowls: "bark_or_growl"
        }
    }

    var english: String {
        switch self {
        case .proactiveFriendly: "Proactively friendly"
        case .observeThenInteract: "Observes first, then interacts"
        case .fearfulButApproaches: "Afraid, but tries to approach"
        case .fearfulAndHides: "Afraid and hides"
        case .barksOrGrowls: "Barks or growls"
        }
    }

    var imageName: String {
        switch self {
        case .proactiveFriendly: "RegistrationSocialProactiveFriendlyCutout"
        case .observeThenInteract: "RegistrationSocialObserveThenInteractCutout"
        case .fearfulButApproaches: "RegistrationSocialFearfulButApproachesCutout"
        case .fearfulAndHides: "RegistrationSocialFearfulAndHidesCutout"
        case .barksOrGrowls: "RegistrationSocialBarksOrGrowlsCutout"
        }
    }

    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .proactiveFriendly: language.text(english, "主動友好")
        case .observeThenInteract: language.text(english, "先觀察，再互動")
        case .fearfulButApproaches: language.text(english, "害怕，但會嘗試靠近")
        case .fearfulAndHides: language.text(english, "害怕並躲開")
        case .barksOrGrowls: language.text(english, "吠叫或低吠")
        }
    }
}

private struct SocialReactionCarousel: View {
    @Binding var selection: SocialStyle?
    let language: SnootsLanguage
    @State private var centeredStyle: SocialStyle? = .proactiveFriendly
    @State private var didSwipe = false

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width - 64, 272)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(SocialStyle.allCases) { option in
                        let isSelected = selection == option
                        Button {
                            selection = isSelected ? nil : option
                            if !isSelected {
                                withAnimation(.snappy) { centeredStyle = option }
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Image(option.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: cardWidth, height: cardWidth * 1.5)
                                    .background(SnootsPalette.primaryTint)
                                    .accessibilityHidden(true)

                                Text(option.title(language))
                                    .font(.snootsUI(16, weight: .bold))
                                    .foregroundStyle(SnootsPalette.ink)
                                    .frame(width: cardWidth, height: 54)
                            }
                            .frame(width: cardWidth)
                            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(SnootsPalette.navigationActive)
                                        .background(.white, in: Circle())
                                        .padding(12)
                                        .accessibilityHidden(true)
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(isSelected ? SnootsPalette.navigationActive : SnootsPalette.divider, lineWidth: isSelected ? 3 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title(language))
                        .accessibilityValue(isSelected
                                            ? language.text("Selected", "已選取")
                                            : language.text("Not selected", "未選取"))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, (geometry.size.width - cardWidth) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredStyle)
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { didSwipe = true }
                if phase == .idle && didSwipe {
                    if let centeredStyle { selection = centeredStyle }
                    didSwipe = false
                }
            }
        }
        .frame(height: 468)
        .onAppear { centeredStyle = selection ?? .proactiveFriendly }
    }
}

private struct DogHeadSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 50, y: 8))
        path.addCurve(to: CGPoint(x: 5, y: 45), control1: CGPoint(x: 26, y: 8), control2: CGPoint(x: 10, y: 19))
        path.addCurve(to: CGPoint(x: 10, y: 81), control1: CGPoint(x: 1, y: 63), control2: CGPoint(x: 3, y: 76))
        path.addCurve(to: CGPoint(x: 21, y: 84), control1: CGPoint(x: 13, y: 83), control2: CGPoint(x: 17, y: 84))
        path.addCurve(to: CGPoint(x: 50, y: 100), control1: CGPoint(x: 27, y: 96), control2: CGPoint(x: 38, y: 100))
        path.addCurve(to: CGPoint(x: 79, y: 84), control1: CGPoint(x: 62, y: 100), control2: CGPoint(x: 73, y: 96))
        path.addCurve(to: CGPoint(x: 90, y: 81), control1: CGPoint(x: 83, y: 84), control2: CGPoint(x: 87, y: 83))
        path.addCurve(to: CGPoint(x: 95, y: 45), control1: CGPoint(x: 97, y: 76), control2: CGPoint(x: 99, y: 63))
        path.addCurve(to: CGPoint(x: 50, y: 8), control1: CGPoint(x: 90, y: 19), control2: CGPoint(x: 74, y: 8))
        path.closeSubpath()

        path.move(to: CGPoint(x: 17, y: 36))
        path.addCurve(to: CGPoint(x: 21, y: 81), control1: CGPoint(x: 14, y: 48), control2: CGPoint(x: 15, y: 67))
        path.addCurve(to: CGPoint(x: 19, y: 36), control1: CGPoint(x: 18, y: 68), control2: CGPoint(x: 18, y: 48))
        path.addQuadCurve(to: CGPoint(x: 17, y: 36), control: CGPoint(x: 18, y: 34))
        path.closeSubpath()

        path.move(to: CGPoint(x: 83, y: 36))
        path.addCurve(to: CGPoint(x: 79, y: 81), control1: CGPoint(x: 86, y: 48), control2: CGPoint(x: 85, y: 67))
        path.addCurve(to: CGPoint(x: 81, y: 36), control1: CGPoint(x: 82, y: 68), control2: CGPoint(x: 82, y: 48))
        path.addQuadCurve(to: CGPoint(x: 83, y: 36), control: CGPoint(x: 82, y: 34))
        path.closeSubpath()

        path.addEllipse(in: CGRect(x: 28, y: 43, width: 12, height: 14))
        path.addEllipse(in: CGRect(x: 60, y: 43, width: 12, height: 14))
        path.move(to: CGPoint(x: 43, y: 71))
        path.addCurve(to: CGPoint(x: 57, y: 71), control1: CGPoint(x: 47, y: 69), control2: CGPoint(x: 53, y: 69))
        path.addCurve(to: CGPoint(x: 55, y: 80), control1: CGPoint(x: 60, y: 73), control2: CGPoint(x: 58, y: 77))
        path.addCurve(to: CGPoint(x: 45, y: 80), control1: CGPoint(x: 52, y: 83), control2: CGPoint(x: 48, y: 83))
        path.addCurve(to: CGPoint(x: 43, y: 71), control1: CGPoint(x: 42, y: 77), control2: CGPoint(x: 40, y: 73))
        path.closeSubpath()
        return path.applying(CGAffineTransform(
            a: rect.width / 100, b: 0,
            c: 0, d: rect.height / 100,
            tx: rect.minX, ty: rect.minY
        ))
    }
}

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    var fill: Color = SnootsPalette.lime
    var cornerRadius: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.snootsButton(17))
            .foregroundStyle(SnootsPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 12)
            .background(
                fill.opacity(configuration.isPressed ? 0.75 : 1),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

#if DEBUG
fileprivate enum OnboardingPreviewState {
    case entry, basic, fieldErrors, socialUnselected, socialSelected, submitting, failed
    case blank, socialCleared, photoLoading, photoFailure, offline, timedOut, serviceUnavailable
    case basicChecking, basicFailed
}

extension OnboardingFlow {
    fileprivate static func preview(_ state: OnboardingPreviewState) -> OnboardingFlow {
        let store = SnootsStore()
        var flow = OnboardingFlow(store: store, language: .traditionalChinese)
        // Sample data is confined to previews; the real registration form starts empty.
        flow._stage = State(initialValue: .basicInformation)
        flow._ownerName = State(initialValue: store.profile.name)
        flow._petName = State(initialValue: store.pet.name)
        flow._petBreed = State(initialValue: store.pet.breed)
        flow._petSize = State(initialValue: PetSize(value: store.pet.size))
        flow._petSex = State(initialValue: PetSex(value: store.pet.sex))
        flow._neuterStatus = State(initialValue: NeuterStatus(isNeutered: store.pet.isNeutered))
        switch state {
        case .blank:
            return OnboardingFlow(store: store, language: .traditionalChinese)
        case .entry:
            flow._stage = State(initialValue: .entry)
        case .basic:
            break
        case .basicChecking:
            flow._basicSubmission = State(initialValue: .checking)
            flow.pausesBasicCheckingForPreview = true
        case .basicFailed:
            flow._basicSubmission = State(initialValue: .failed("請確認必填欄位後，再重新檢查。"))
        case .photoLoading:
            flow._isLoadingPhoto = State(initialValue: true)
        case .photoFailure:
            flow._photoError = State(initialValue: "無法讀取這張圖片，請重新選擇。")
        case .fieldErrors:
            flow._petName = State(initialValue: "")
            flow._ownerName = State(initialValue: "")
            flow._petBreed = State(initialValue: "")
            flow._petSize = State(initialValue: nil)
            flow._petSex = State(initialValue: nil)
            flow._neuterStatus = State(initialValue: nil)
            flow._attemptedNext = State(initialValue: true)
            flow._validatedFields = State(initialValue: Set(RegistrationField.allCases))
        case .socialUnselected, .socialCleared:
            flow._stage = State(initialValue: .socialBehavior)
        case .socialSelected:
            flow._stage = State(initialValue: .socialBehavior)
            flow._selectedSocialStyle = State(initialValue: .observeThenInteract)
        case .submitting:
            flow._stage = State(initialValue: .socialBehavior)
            flow._selectedSocialStyle = State(initialValue: .observeThenInteract)
            flow._submission = State(initialValue: .submitting)
            flow.pausesSubmissionForPreview = true
        case .failed:
            flow._stage = State(initialValue: .socialBehavior)
            flow._selectedSocialStyle = State(initialValue: .observeThenInteract)
            flow._submission = State(initialValue: .failed(.validation("請確認必填資料完整，再重新送出。")))
        case .offline, .timedOut, .serviceUnavailable:
            flow._stage = State(initialValue: .socialBehavior)
            flow._selectedSocialStyle = State(initialValue: .observeThenInteract)
            let failure: RegistrationFailure = state == .offline ? .offline : (state == .timedOut ? .timedOut : .serviceUnavailable)
            flow._submission = State(initialValue: .failed(failure))
        }
        return flow
    }

    fileprivate static func fieldErrorPreview(_ field: RegistrationField) -> OnboardingFlow {
        var flow = preview(.basic)
        flow._attemptedNext = State(initialValue: true)
        flow._validatedFields = State(initialValue: [field])
        switch field {
        case .petName: flow._petName = State(initialValue: "")
        case .breed: flow._petBreed = State(initialValue: "")
        case .size: flow._petSize = State(initialValue: nil)
        case .sex: flow._petSex = State(initialValue: nil)
        case .neuter: flow._neuterStatus = State(initialValue: nil)
        case .ownerName:
            flow._stage = State(initialValue: .entry)
            flow._ownerName = State(initialValue: "")
        }
        return flow
    }
}

#Preview("入口・開始註冊") { OnboardingFlow.preview(.blank) }
#Preview("返回入口") { OnboardingFlow.preview(.entry) }
#Preview("註冊 1・紫色頁首") { OnboardingFlow.preview(.basic) }
#Preview("註冊 1・照片裁切與確認") {
    if let image = UIImage(named: "Tofu") ?? UIImage(systemName: "photo") {
        RegistrationPhotoCropView(image: image, onCancel: {}, onConfirm: { _ in })
    }
}
#Preview("註冊 1・品種搜尋") {
    NavigationStack { BreedPickerView(selection: .constant(""), language: .traditionalChinese) }
}
#Preview("註冊 1・照片讀取中") { OnboardingFlow.preview(.photoLoading) }
#Preview("註冊 1・照片讀取失敗") { OnboardingFlow.preview(.photoFailure) }
#Preview("註冊 1・欄位錯誤") { OnboardingFlow.preview(.fieldErrors) }
#Preview("註冊 1・狗名未填") { OnboardingFlow.fieldErrorPreview(.petName) }
#Preview("註冊 1・品種未選") { OnboardingFlow.fieldErrorPreview(.breed) }
#Preview("註冊 1・體型未選") { OnboardingFlow.fieldErrorPreview(.size) }
#Preview("註冊 1・性別未選") { OnboardingFlow.fieldErrorPreview(.sex) }
#Preview("註冊 1・絕育未選") { OnboardingFlow.fieldErrorPreview(.neuter) }
#Preview("入口・飼主暱稱未填") { OnboardingFlow.fieldErrorPreview(.ownerName) }
#Preview("註冊 1・檢查中") { OnboardingFlow.preview(.basicChecking) }
#Preview("註冊 1・檢查失敗與重試") { OnboardingFlow.preview(.basicFailed) }
#Preview("註冊 2・未選擇") { OnboardingFlow.preview(.socialUnselected) }
#Preview("註冊 2・已單選") { OnboardingFlow.preview(.socialSelected) }
#Preview("註冊 2・取消後") { OnboardingFlow.preview(.socialCleared) }
#Preview("送出中") { OnboardingFlow.preview(.submitting) }
#Preview("送出失敗・可重試") { OnboardingFlow.preview(.failed) }
#Preview("送出・網路中斷") { OnboardingFlow.preview(.offline) }
#Preview("送出・連線逾時") { OnboardingFlow.preview(.timedOut) }
#Preview("送出・服務失敗") { OnboardingFlow.preview(.serviceUnavailable) }
#Preview("完成後・社群首頁") {
    ContentView(
        store: SnootsStore(),
        language: .traditionalChinese,
        displayLanguageRawValue: .constant(SnootsLanguage.traditionalChinese.rawValue)
    )
}
#endif
