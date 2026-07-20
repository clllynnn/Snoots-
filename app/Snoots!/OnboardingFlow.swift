import SwiftUI

struct OnboardingFlow: View {
    let store: SnootsStore
    let language: SnootsLanguage

    @State private var stage: Stage = .questions
    @State private var questionIndex = 0
    @State private var guideIndex = 0
    @State private var ownerName: String
    @State private var neighborhood: Neighborhood
    @State private var petName: String
    @State private var petAge: PetAge
    @State private var petSize: PetSize
    @State private var socialStyle: SocialStyle
    @State private var selectedTraits: Set<Trait> = [.slowIntroductions, .leashFirst]

    init(store: SnootsStore, language: SnootsLanguage) {
        self.store = store
        self.language = language
        _ownerName = State(initialValue: store.profile.name)
        _neighborhood = State(initialValue: .daan)
        _petName = State(initialValue: store.pet.name)
        _petAge = State(initialValue: .adult)
        _petSize = State(initialValue: .medium)
        _socialStyle = State(initialValue: .slowToWarmUp)
    }

    var body: some View {
        Group {
            if stage == .questions {
                questionFlow
            } else {
                guideFlow
            }
        }
        .background(SnootsPalette.canvas)
        .foregroundStyle(SnootsPalette.ink)
        .animation(.snappy, value: questionIndex)
        .animation(.snappy, value: guideIndex)
    }

    private var questionFlow: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(language.text("Question \(questionIndex + 1) of 3", "第 \(questionIndex + 1) / 3 題"))
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
                GeometryReader { proxy in
                    Capsule()
                        .fill(SnootsPalette.divider)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(SnootsPalette.lime)
                                .frame(width: proxy.size.width * CGFloat(questionIndex + 1) / 3)
                        }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            Group {
                switch questionIndex {
                case 0: ownerQuestion
                case 1: petQuestion
                default: preferenceQuestion
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                Button(action: advanceQuestion) {
                    Text(questionIndex == 2
                         ? language.text("See your Snoots guide", "看看 Snoots 使用導覽")
                         : language.text("Continue", "繼續"))
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1 : 0.45)

                if questionIndex > 0 {
                    Button(language.text("Back", "返回")) {
                        questionIndex -= 1
                    }
                    .font(.snootsButton(16))
                    .foregroundStyle(SnootsPalette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 32)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }

    private var ownerQuestion: some View {
        OnboardingQuestionContainer(
            icon: "person.2.fill",
            eyebrow: language.text("LET'S GET TO KNOW YOU", "先認識一下你"),
            title: language.text("Where will you and your dog explore?", "你和狗狗通常在哪裡活動？"),
            detail: language.text("We use this to make nearby recommendations feel relevant.", "我們會用這些資訊，推薦更適合你們的附近去處。")
        ) {
            OnboardingTextField(
                title: language.text("Your name", "你的名字"),
                prompt: language.text("e.g. Amber", "例如：小安"),
                text: $ownerName
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(language.text("Your neighborhood", "常活動的地區"))
                    .font(.snootsCardTitle())
                Picker(language.text("Your neighborhood", "常活動的地區"), selection: $neighborhood) {
                    ForEach(Neighborhood.allCases) { neighborhood in
                        Text(neighborhood.title(language)).tag(neighborhood)
                    }
                }
                .pickerStyle(.menu)
                .tint(SnootsPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var petQuestion: some View {
        OnboardingQuestionContainer(
            icon: "pawprint.fill",
            eyebrow: language.text("NOW, YOUR DOG", "接著認識你的狗狗"),
            title: language.text("Tell us the basics", "告訴我們狗狗的基本資料"),
            detail: language.text("This helps set up a profile that feels like them.", "這些資料會幫我們建立更貼近牠的檔案。")
        ) {
            OnboardingTextField(
                title: language.text("Dog's name", "狗狗的名字"),
                prompt: language.text("e.g. Nori", "例如：糯米"),
                text: $petName
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(language.text("Age", "年齡")).font(.snootsCardTitle())
                OnboardingChoiceRow(options: PetAge.allCases, selection: $petAge, label: { $0.title(language) })
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(language.text("Size", "體型")).font(.snootsCardTitle())
                OnboardingChoiceRow(options: PetSize.allCases, selection: $petSize, label: { $0.title(language) })
            }
        }
    }

    private var preferenceQuestion: some View {
        OnboardingQuestionContainer(
            icon: "heart.fill",
            eyebrow: language.text("THEIR COMFORT COMES FIRST", "牠的舒適最重要"),
            title: language.text("What feels right for \(petName.isEmpty ? language.text("your dog", "你的狗狗") : petName)?", "\(petName.isEmpty ? "你的狗狗" : petName) 喜歡怎麼互動？"),
            detail: language.text("We'll use these preferences for safer matches and meetups.", "我們會用這些偏好，安排更安心的配對與狗聚。")
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.text("Social style", "社交方式")).font(.snootsCardTitle())
                OnboardingChoiceRow(options: SocialStyle.allCases, selection: $socialStyle, label: { $0.title(language) })
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(language.text("Choose all that apply", "可複選")).font(.snootsCardTitle())
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Trait.allCases) { trait in
                        Button {
                            toggle(trait)
                        } label: {
                            Label(trait.title(language), systemImage: selectedTraits.contains(trait) ? "checkmark.circle.fill" : "circle")
                                .font(.snootsUI(14, weight: .semibold))
                                .foregroundStyle(SnootsPalette.ink)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .padding(.horizontal, 8)
                                .background(selectedTraits.contains(trait) ? SnootsPalette.lime : SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(selectedTraits.contains(trait) ? SnootsPalette.ink : SnootsPalette.divider, lineWidth: selectedTraits.contains(trait) ? 1.5 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedTraits.contains(trait) ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var guideFlow: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SNOOTS!").font(.snootsLogo(20))
                Spacer()
                Button(language.text("Skip", "略過"), action: finish)
                    .font(.snootsButton(15))
                    .foregroundStyle(SnootsPalette.secondaryText)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)

            TabView(selection: $guideIndex) {
                TutorialSlide(
                    imageName: store.pet.imageName,
                    symbol: "person.2.fill",
                    accent: SnootsPalette.lime,
                    title: language.text("Meet dogs at their pace", "用適合牠的步調認識新朋友"),
                    detail: language.text("Match using the comfort preferences you just shared.", "依照剛才分享的偏好，找到更合拍的狗狗。")
                ).tag(0)
                TutorialSlide(
                    imageName: "CompanionCafe",
                    symbol: "map.fill",
                    accent: SnootsPalette.primary,
                    title: language.text("Find dog-friendly places", "找到真正適合狗狗的地方"),
                    detail: language.text("Check access rules before you leave, so every outing starts smoothly.", "出發前先確認入店規則，讓每次出門都更安心。")
                ).tag(1)
                TutorialSlide(
                    imageName: "Nori",
                    symbol: "checkmark.shield.fill",
                    accent: SnootsPalette.lime,
                    title: language.text("Share clear signals", "用清楚的資訊，照顧彼此"),
                    detail: language.text("Profiles make comfort needs visible before a first hello.", "在第一次見面前，先把彼此的需求說清楚。")
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == guideIndex ? SnootsPalette.ink : SnootsPalette.divider)
                            .frame(width: index == guideIndex ? 24 : 8, height: 8)
                    }
                }
                Button(action: advanceGuide) {
                    Text(guideIndex == 2 ? language.text("Start exploring", "開始探索") : language.text("Next", "下一步"))
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }

    private var canAdvance: Bool {
        switch questionIndex {
        case 0: !ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: !petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: !selectedTraits.isEmpty
        }
    }

    private func advanceQuestion() {
        guard canAdvance else { return }
        if questionIndex == 2 { stage = .guide } else { questionIndex += 1 }
    }

    private func advanceGuide() {
        if guideIndex == 2 { finish() } else { guideIndex += 1 }
    }

    private func finish() {
        store.completeOnboarding(
            ownerName: ownerName.trimmingCharacters(in: .whitespacesAndNewlines),
            neighborhood: neighborhood.english,
            petName: petName.trimmingCharacters(in: .whitespacesAndNewlines),
            petAge: petAge.english,
            petSize: petSize.english,
            socialStyle: socialStyle.english,
            traits: Trait.allCases.filter(selectedTraits.contains).map(\.english)
        )
    }

    private func toggle(_ trait: Trait) {
        if selectedTraits.contains(trait) { selectedTraits.remove(trait) } else { selectedTraits.insert(trait) }
    }
}

private enum Stage { case questions, guide }

private enum Neighborhood: CaseIterable, Identifiable {
    case daan, zhongzheng, xinyi
    var id: Self { self }
    var english: String {
        switch self {
        case .daan: "Da’an District, Taipei"
        case .zhongzheng: "Zhongzheng District, Taipei"
        case .xinyi: "Xinyi District, Taipei"
        }
    }
    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .daan: language.text(english, "台北市大安區")
        case .zhongzheng: language.text(english, "台北市中正區")
        case .xinyi: language.text(english, "台北市信義區")
        }
    }
}

private enum PetAge: CaseIterable, Identifiable {
    case puppy, adult, senior
    var id: Self { self }
    var english: String { switch self { case .puppy: "Puppy"; case .adult: "Adult"; case .senior: "Senior" } }
    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .puppy: language.text("Puppy", "幼犬")
        case .adult: language.text("Adult", "成犬")
        case .senior: language.text("Senior", "熟齡犬")
        }
    }
}

private enum PetSize: CaseIterable, Identifiable {
    case small, medium, large
    var id: Self { self }
    var english: String { switch self { case .small: "Small"; case .medium: "Medium"; case .large: "Large" } }
    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .small: language.text("Small", "小型")
        case .medium: language.text("Medium", "中型")
        case .large: language.text("Large", "大型")
        }
    }
}

private enum SocialStyle: CaseIterable, Identifiable {
    case slowToWarmUp, friendly, selective
    var id: Self { self }
    var english: String {
        switch self {
        case .slowToWarmUp: "Slow to warm up"
        case .friendly: "Friendly with most dogs"
        case .selective: "Selective with new dogs"
        }
    }
    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .slowToWarmUp: language.text("Slow to warm up", "慢熱型")
        case .friendly: language.text("Friendly", "親人親狗")
        case .selective: language.text("Selective", "需要挑選朋友")
        }
    }
}

private enum Trait: CaseIterable, Hashable, Identifiable {
    case slowIntroductions, leashFirst, adultDogs, playful, quietSpaces
    var id: Self { self }
    var english: String {
        switch self {
        case .slowIntroductions: "Slow introductions"
        case .leashFirst: "Leash-first"
        case .adultDogs: "Adult dogs"
        case .playful: "Playful"
        case .quietSpaces: "Quiet spaces"
        }
    }
    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .slowIntroductions: language.text(english, "慢慢認識")
        case .leashFirst: language.text(english, "先牽繩互動")
        case .adultDogs: language.text(english, "偏好成犬")
        case .playful: language.text(english, "喜歡玩耍")
        case .quietSpaces: language.text(english, "喜歡安靜空間")
        }
    }
}

private struct OnboardingQuestionContainer<Content: View>: View {
    let icon: String
    let eyebrow: String
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: icon)
                        .font(.title2.weight(.bold))
                        .frame(width: 52, height: 52)
                        .background(SnootsPalette.lime, in: Circle())
                    Text(eyebrow).font(.snootsMetadata()).foregroundStyle(SnootsPalette.secondaryText)
                    Text(title).font(.snootsScreenTitle()).fixedSize(horizontal: false, vertical: true)
                    Text(detail).font(.snootsBody()).foregroundStyle(SnootsPalette.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 20)
        }
    }
}

private struct OnboardingTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.snootsCardTitle())
            TextField(prompt, text: $text)
                .font(.snootsBody())
                .textContentType(.name)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(SnootsPalette.divider, lineWidth: 1) }
        }
    }
}

private struct OnboardingChoiceRow<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                Button { selection = option } label: {
                    Text(label(option))
                        .font(.snootsUI(14, weight: .semibold))
                        .foregroundStyle(SnootsPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 5)
                        .background(selection == option ? SnootsPalette.lime : SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selection == option ? SnootsPalette.ink : SnootsPalette.divider, lineWidth: selection == option ? 1.5 : 1) }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
    }
}

private struct TutorialSlide: View {
    let imageName: String
    let symbol: String
    let accent: Color
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 30) {
            ZStack(alignment: .bottomTrailing) {
                Image(imageName)
                    .resizable().scaledToFill()
                    .frame(width: 258, height: 258)
                    .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 42, style: .continuous).stroke(SnootsPalette.surface, lineWidth: 7) }
                Image(systemName: symbol)
                    .font(.title2.weight(.bold))
                    .frame(width: 62, height: 62)
                    .background(accent, in: Circle())
                    .overlay { Circle().stroke(SnootsPalette.surface, lineWidth: 5) }
                    .offset(x: 10, y: 10)
            }
            VStack(spacing: 12) {
                Text(title).font(.snootsScreenTitle()).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Text(detail).font(.snootsBody()).foregroundStyle(SnootsPalette.secondaryText).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 8)
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.snootsButton(17))
            .foregroundStyle(SnootsPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(SnootsPalette.lime.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
