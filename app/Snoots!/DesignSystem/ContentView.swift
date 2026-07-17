import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    let store: SnootsStore
    let language: SnootsLanguage
    @Binding var displayLanguageRawValue: String
    @State private var selectedTab: AppTab = .feed
    @State private var selectedNearbyCategory: NearbyCategory?
    @State private var selectedNearbyRegion: NearbyRegion = .currentLocation
    @State private var meetupFocusRequest = 0
    @State private var matchPath: [SnootsRoute] = []
    @State private var mapsPath: [SnootsRoute] = []
    @State private var profilePath: [SnootsRoute] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $matchPath) {
                PlaydatesView(store: store, language: language) { matchPath.append($0) }
                    .navigationDestination(for: SnootsRoute.self) { route in
                        switch route {
                        case .match:
                            MatchConfirmationView(
                                candidate: store.playdate,
                                store: store,
                                language: language,
                                onNavigate: { matchPath.append($0) }
                            )
                        case .chat:
                            MatchChatRoom(candidate: store.playdate, store: store, language: language)
                        case .emergency, .place:
                            EmptyView()
                        }
                    }
            }
                .tabItem { Label(language.text("Match", "配對"), systemImage: AppTab.match.symbol) }
                .tag(AppTab.match)

            NavigationStack(path: $mapsPath) {
                MapsView(
                    store: store,
                    language: language,
                    selectedCategory: $selectedNearbyCategory,
                    selectedRegion: $selectedNearbyRegion,
                    meetupFocusRequest: meetupFocusRequest
                ) { mapsPath.append($0) }
                    .navigationDestination(for: SnootsRoute.self) { route in
                        switch route {
                        case .emergency:
                            CareView(store: store, language: language)
                        case .place(let placeID):
                            if let place = store.place(id: placeID) {
                                PlaceDetailView(place: place, store: store, language: language)
                            }
                        case .match, .chat:
                            EmptyView()
                        }
                    }
            }
                .tabItem { Label(language.text("Nearby", "附近"), systemImage: AppTab.maps.symbol) }
                .tag(AppTab.maps)

            NavigationStack {
                FeedView(
                    store: store,
                    language: language,
                    onViewMeetups: showMeetups,
                    onMeetupCreated: showMeetups
                )
            }
                .tabItem { Label(language.text("Feed", "社群"), systemImage: AppTab.feed.symbol) }
                .tag(AppTab.feed)

            NavigationStack(path: $profilePath) {
                ProfileView(
                    store: store,
                    language: language,
                    displayLanguageRawValue: $displayLanguageRawValue
                ) { profilePath.append($0) }
                    .navigationDestination(for: SnootsRoute.self) { route in
                        switch route {
                        case .place(let placeID):
                            if let place = store.place(id: placeID) {
                                PlaceDetailView(place: place, store: store, language: language)
                            }
                        case .match, .chat, .emergency:
                            EmptyView()
                        }
                    }
            }
                .tabItem { Label(language.text("Profile", "檔案"), systemImage: AppTab.profile.symbol) }
                .tag(AppTab.profile)
        }
        .tint(SnootsPalette.navigationActive)
        .sensoryFeedback(.success, trigger: store.isMatched)
    }

    private func showMeetups() {
        selectedNearbyCategory = .meetups
        selectedNearbyRegion = .currentLocation
        meetupFocusRequest += 1
        selectedTab = .maps
    }
}

enum SnootsRoute: Hashable {
    case match
    case chat
    case emergency
    case place(String)
}

struct FeedView: View {
    let store: SnootsStore
    let language: SnootsLanguage
    let onViewMeetups: () -> Void
    let onMeetupCreated: () -> Void
    @State private var likedPostIDs: Set<UUID> = []
    @State private var savedPostIDs: Set<UUID> = []
    @State private var presentedSheet: FeedSheet?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading) {
                        Text(language.text("Feed", "社群"))
                            .font(.snootsScreenTitle())
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        FeedHeaderButton(symbol: "heart")
                        FeedHeaderButton(symbol: "paperplane")
                    }
                }

                CreateActivityButton(
                    language: language,
                    onView: onViewMeetups,
                    onCreate: { presentedSheet = .createMeetup }
                )

                FeedStoryStrip(stories: store.feedStories, language: language)

                ForEach(store.socialPosts) { post in
                    FeedPostCard(
                        post: post,
                        language: language,
                        isLiked: likedPostIDs.contains(post.id),
                        isSaved: savedPostIDs.contains(post.id),
                        onToggleLike: { toggle(post.id, in: &likedPostIDs) },
                        onToggleSave: { toggle(post.id, in: &savedPostIDs) }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .createMeetup:
                CreateMeetupSheet(
                    store: store,
                    language: language,
                    onPublished: onMeetupCreated
                )
            }
        }
    }

    private func toggle(_ id: UUID, in selection: inout Set<UUID>) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    private enum FeedSheet: Identifiable {
        case createMeetup

        var id: String { "createMeetup" }
    }
}

private struct FeedHeaderButton: View {
    let symbol: String

    var body: some View {
        Button(action: {}) {
            Image(systemName: symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(SnootsPalette.ink)
                .frame(width: 44, height: 44)
                .background(SnootsPalette.surface, in: Circle())
        }
        .accessibilityLabel(symbol == "heart" ? "Activity" : "Messages")
    }
}

private struct FeedStoryStrip: View {
    let stories: [FeedStory]
    let language: SnootsLanguage

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(stories) { story in
                    Button(action: {}) {
                        VStack(spacing: 7) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(story.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 62, height: 62)
                                    .clipShape(Circle())
                                    .overlay { Circle().stroke(SnootsPalette.surface, lineWidth: 3) }
                                    .padding(3)
                                    .background(
                                        AngularGradient(
                                            colors: [SnootsPalette.primary, SnootsPalette.lime, SnootsPalette.primary],
                                            center: .center
                                        ),
                                        in: Circle()
                                    )

                                if story.isCurrentUser {
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(SnootsPalette.ink)
                                        .frame(width: 20, height: 20)
                                        .background(SnootsPalette.lime, in: Circle())
                                        .overlay { Circle().stroke(SnootsPalette.surface, lineWidth: 2) }
                                }
                            }
                            Text(story.isCurrentUser ? language.text(story.name, "你的限時") : story.name)
                                .font(.snootsMetadata())
                                .foregroundStyle(SnootsPalette.ink)
                                .lineLimit(1)
                        }
                        .frame(width: 68)
                    }
                    .accessibilityLabel(story.isCurrentUser ? language.text(story.name, "你的限時") : story.name)
                }
            }
        }
    }
}

private struct CreateActivityButton: View {
    let language: SnootsLanguage
    let onView: () -> Void
    let onCreate: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onView) {
                Label(language.text("View meetups", "檢視狗聚"), systemImage: "person.2")
                    .font(.snootsButton(16))
                    .foregroundStyle(SnootsPalette.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.plain)
            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.buttonRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SnootsMetrics.buttonRadius, style: .continuous)
                    .stroke(SnootsPalette.lime, lineWidth: 2)
            }
            .accessibilityLabel(language.text("View meetups", "檢視狗聚"))

            Button(action: onCreate) {
                Label(language.text("Create a meetup", "發起狗聚"), systemImage: "plus")
                    .font(.snootsButton(16))
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
            .accessibilityLabel(language.text("Create a meetup", "發起狗聚"))
        }
    }
}

private struct CreateMeetupSheet: View {
    let store: SnootsStore
    let language: SnootsLanguage
    let onPublished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedTypeID = ""
    @State private var selectedVenueID = ""
    @State private var startDate = Date.now.addingTimeInterval(60 * 60)
    @State private var durationHours = 2
    @State private var attendeeLimit = 6
    @State private var requiresApproval = true
    @State private var selectedSafetyTags: Set<String> = ["Leash on", "Slow introductions"]
    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var activityPhoto: Image?
    @FocusState private var isTitleFocused: Bool

    private var selectedType: MeetupActivityType? {
        store.meetupActivityTypes.first { $0.id == selectedTypeID }
    }

    private var selectedVenue: MeetupVenue? {
        store.meetupVenues.first { $0.id == selectedVenueID }
    }

    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedType != nil && selectedVenue != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(language.text("Bring compatible dogs together", "為合拍的狗狗發起相聚"))
                            .font(.snootsSection())
                        Text(language.text("Set clear expectations so every hello starts calmly.", "清楚設定期待，讓每一次見面都能安心開始。"))
                            .font(.snootsBody())
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }

                    MeetupComposerSection(title: language.text("Activity type", "活動類型")) {
                        HStack(spacing: 10) {
                            ForEach(store.meetupActivityTypes) { type in
                                MeetupTypeTile(
                                    type: type,
                                    language: language,
                                    isSelected: selectedTypeID == type.id
                                ) {
                                    selectedTypeID = type.id
                                }
                            }
                        }
                    }

                    MeetupComposerSection(title: language.text("Details", "活動詳情")) {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Image(systemName: "textformat")
                                    .foregroundStyle(SnootsPalette.navigationActive)
                                    .frame(width: 24)
                                TextField(language.text("Give your meetup a name", "為狗聚取個名稱"), text: $title)
                                    .font(.snootsBody())
                                    .focused($isTitleFocused)
                            }
                            .padding(16)

                            Divider().padding(.leading, 52)

                            DatePicker(
                                selection: $startDate,
                                in: Date.now...,
                                displayedComponents: [.date, .hourAndMinute]
                            ) {
                                Label(language.text("Starts", "開始時間"), systemImage: "calendar")
                                    .font(.snootsBody())
                                    .foregroundStyle(SnootsPalette.ink)
                            }
                            .tint(SnootsPalette.navigationActive)
                            .padding(16)

                            Divider().padding(.leading, 52)

                            Picker(selection: $durationHours) {
                                ForEach(store.meetupDurations) { duration in
                                    Text(duration.localizedLabel(language)).tag(duration.hours)
                                }
                            } label: {
                                Label(language.text("Duration", "活動時長"), systemImage: "clock")
                                    .font(.snootsBody())
                            }
                            .tint(SnootsPalette.navigationActive)
                            .padding(16)
                        }
                    }

                    MeetupComposerSection(title: language.text("Location", "地點")) {
                        Picker(selection: $selectedVenueID) {
                            ForEach(store.meetupVenues) { venue in
                                Text(venue.localizedName(language)).tag(venue.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(SnootsPalette.navigationActive)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.text("Meet at", "集合地點"))
                                        .font(.snootsMetadata())
                                        .foregroundStyle(SnootsPalette.secondaryText)
                                    Text(selectedVenue?.localizedName(language) ?? language.text("Choose a place", "選擇地點"))
                                        .font(.snootsBody())
                                        .foregroundStyle(SnootsPalette.ink)
                                }
                                Spacer()
                            }
                        }
                        .tint(SnootsPalette.navigationActive)
                        .padding(16)
                    }

                    MeetupComposerSection(title: language.text("Cover photo", "活動照片")) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            HStack(spacing: 14) {
                                Group {
                                    if let activityPhoto {
                                        activityPhoto
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.title2)
                                            .foregroundStyle(SnootsPalette.navigationActive)
                                    }
                                }
                                .frame(width: 58, height: 58)
                                .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(language.text("Add a photo", "新增照片"))
                                        .font(.snootsCardTitle())
                                        .foregroundStyle(SnootsPalette.ink)
                                    Text(language.text("Help nearby dog parents recognise the meetup.", "讓附近的飼主更容易辨識狗聚。"))
                                        .font(.snootsMetadata())
                                        .foregroundStyle(SnootsPalette.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(SnootsPalette.inactive)
                            }
                            .padding(16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    MeetupComposerSection(title: language.text("Dog-friendly settings", "安心狗聚設定")) {
                        VStack(spacing: 0) {
                            Toggle(isOn: $requiresApproval) {
                                Label(language.text("Review join requests", "審核參加申請"), systemImage: "checkmark.shield")
                                    .font(.snootsBody())
                            }
                            .tint(SnootsPalette.lime)
                            .padding(16)

                            Divider().padding(.leading, 52)

                            Stepper(value: $attendeeLimit, in: 2...20) {
                                Label("\\(language.text(\"Up to\", \"最多\")) \\(attendeeLimit) \\(language.text(\"dogs\", \"隻狗狗\"))", systemImage: "dog")
                                    .font(.snootsBody())
                            }
                            .tint(SnootsPalette.navigationActive)
                            .padding(16)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(language.text("Shared expectations", "共同約定"))
                                .font(.snootsMetadata())
                                .foregroundStyle(SnootsPalette.secondaryText)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(store.meetupSafetyOptions) { option in
                                        Button {
                                            toggleSafetyTag(option.id)
                                        } label: {
                                            Label(
                                                option.localizedTitle(language),
                                                systemImage: selectedSafetyTags.contains(option.id) ? "checkmark.circle.fill" : "circle"
                                            )
                                            .font(.snootsChip())
                                            .foregroundStyle(SnootsPalette.ink)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedSafetyTags.contains(option.id) ? SnootsPalette.primaryTint : SnootsPalette.canvas,
                                                in: Capsule()
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityAddTraits(selectedSafetyTags.contains(option.id) ? .isSelected : [])
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }

                    MeetupComposerSection(title: language.text("A note for dog parents", "給飼主的補充說明")) {
                        TextEditor(text: $notes)
                            .font(.snootsBody())
                            .frame(minHeight: 104)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(SnootsPalette.surface)
                            .accessibilityLabel(language.text("Meetup notes", "狗聚說明"))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .background(SnootsPalette.canvas)
            .navigationTitle(language.text("Create a meetup", "發起狗聚"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("Cancel", "取消")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("Publish", "發佈")) {
                        publish()
                    }
                    .font(.snootsButton(16))
                    .disabled(!canPublish)
                }
            }
            .onAppear {
                if selectedTypeID.isEmpty {
                    selectedTypeID = store.meetupActivityTypes.first?.id ?? ""
                }
                if selectedVenueID.isEmpty {
                    selectedVenueID = store.meetupVenues.first?.id ?? ""
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                loadPhoto(from: newValue)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func toggleSafetyTag(_ id: String) {
        if selectedSafetyTags.contains(id) {
            selectedSafetyTags.remove(id)
        } else {
            selectedSafetyTags.insert(id)
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        Task {
            guard let data = try? await item?.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else { return }
            activityPhoto = Image(uiImage: uiImage)
        }
    }

    private func publish() {
        guard let selectedType, let selectedVenue else { return }
        store.createMeetup(
            MeetupDraft(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                activityTypeID: selectedType.id,
                venueID: selectedVenue.id,
                startDate: startDate,
                durationHours: durationHours,
                attendeeLimit: attendeeLimit,
                requiresApproval: requiresApproval,
                safetyTagIDs: Array(selectedSafetyTags),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                hasCoverPhoto: activityPhoto != nil
            )
        )
        dismiss()
        onPublished()
    }
}

private struct MeetupComposerSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.snootsSection())
            content
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                .snootsCardShadow()
        }
    }
}

private struct MeetupTypeTile: View {
    let type: MeetupActivityType
    let language: SnootsLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: type.symbol)
                    .font(.title3.weight(.semibold))
                Text(type.localizedTitle(language))
                    .font(.snootsChip())
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(SnootsPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .padding(12)
            .background(isSelected ? SnootsPalette.lime : SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous)
                    .stroke(isSelected ? SnootsPalette.lime : SnootsPalette.divider, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FeedPostCard: View {
    let post: SocialPost
    let language: SnootsLanguage
    let isLiked: Bool
    let isSaved: Bool
    let onToggleLike: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            FeedPostAuthorRow(post: post, language: language)
            if let photoName = post.photoName {
                Image(photoName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 292)
                    .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.profileImageRadius, style: .continuous))
                    .accessibilityLabel("Photo of \(post.petName)")
            }
            HStack(spacing: 16) {
                Button(action: onToggleLike) {
                    Label("\(post.likes + (isLiked ? 1 : 0))", systemImage: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? SnootsPalette.navigationActive : SnootsPalette.ink)
                        .frame(minWidth: 44, minHeight: 44)
                }
                Button(action: {}) {
                    Label("\(post.comments)", systemImage: "bubble.right")
                        .frame(minWidth: 44, minHeight: 44)
                }
                Button(action: {}) {
                    Image(systemName: "paperplane")
                        .frame(minWidth: 44, minHeight: 44)
                }
                Spacer()
                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isSaved ? SnootsPalette.navigationActive : SnootsPalette.ink)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .font(.snootsUI(15, weight: .semibold))
            .buttonStyle(.plain)

            Text(post.localizedBody(language))
                .font(.snootsBody())
                .fixedSize(horizontal: false, vertical: true)
            DeclarationChips(labels: post.localizedDeclarations(language), tint: SnootsPalette.primaryTint)
        }
        .padding(15)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

private struct FeedPostAuthorRow: View {
    let post: SocialPost
    let language: SnootsLanguage

    var body: some View {
        HStack(spacing: 10) {
            Image(post.photoName ?? "Nori")
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay { Circle().stroke(SnootsPalette.primary.opacity(0.7), lineWidth: 2) }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.owner).font(.snootsUI(14, weight: .semibold))
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(SnootsPalette.navigationActive)
                        .accessibilityLabel("Verified parent")
                }
                Text("\(post.location) · \(post.localizedTimeAgo(language))")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            Spacer()
            Image(systemName: "ellipsis")
                .foregroundStyle(SnootsPalette.secondaryText)
                .frame(width: 30, height: 30)
                .accessibilityLabel("More post options")
        }
    }
}

struct PlaydatesView: View {
    let store: SnootsStore
    let language: SnootsLanguage
    let onNavigate: (SnootsRoute) -> Void
    @State private var isPassed = false
    @State private var dragOffset: CGSize = .zero

    private let swipeThreshold: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(language.text("Find Paws", "找狗朋友"))
                    .font(.snootsScreenTitle())
                Text(language.text("Swipe right to MATCH. Swipe left to SKIP.", "向右滑即可配對，向左滑即可略過。"))
                    .font(.snootsBody())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }

            Group {
                if store.isMatched {
                    MatchedBanner(candidate: store.playdate, language: language)
                } else if isPassed {
                    ContentUnavailableView(
                        language.text("More checked matches nearby", "附近暫時沒有更多合適的配對"),
                        systemImage: "pawprint.fill",
                        description: Text(language.text("Mochi is still available for a leashed hello.", "Mochi 仍在等候一場牽繩初次見面。"))
                    )
                    Button(language.text("Revisit Mochi", "再看看 Mochi")) { isPassed = false }
                        .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                } else {
                    SwipeableMatchCard(
                        candidate: store.playdate,
                        language: language,
                        dragOffset: $dragOffset,
                        swipeThreshold: swipeThreshold,
                        onSwipe: completeSwipe
                    )
                }
            }
            .frame(maxWidth: 390)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func completeSwipe(_ direction: MatchSwipeDirection) {
        withAnimation(.snappy(duration: 0.2, extraBounce: 0)) {
            dragOffset = CGSize(width: direction.horizontalOffset, height: dragOffset.height)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            dragOffset = .zero
            switch direction {
            case .skip:
                isPassed = true
            case .playdate:
                onNavigate(.match)
            }
        }
    }
}

private enum MatchSwipeDirection: Equatable {
    case skip
    case playdate

    var horizontalOffset: CGFloat {
        switch self {
        case .skip: -900
        case .playdate: 900
        }
    }
}

private struct SwipeableMatchCard: View {
    let candidate: PlaydateCandidate
    let language: SnootsLanguage
    @Binding var dragOffset: CGSize
    let swipeThreshold: CGFloat
    let onSwipe: (MatchSwipeDirection) -> Void

    private var swipeProgress: CGFloat { min(abs(dragOffset.width) / swipeThreshold, 1) }
    private var isShowingPlaydate: Bool { dragOffset.width > 0 }

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                Image(candidate.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width)
                    .frame(maxHeight: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(candidate.name), \(localizedAge)")
                            .font(.snootsHeading(28))
                        Text(language.text("with \(candidate.owner) · \(localizedDistance)", "飼主 \(candidate.owner) · 距離 \(localizedDistance)"))
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }
                    Text(localizedIntro)
                        .font(.snootsUI(14))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    MatchTraitChips(labels: localizedCompatibility)
                    Label(localizedSafetyLine, systemImage: "checkmark.shield.fill")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.lavender)
                }
                .padding(18)
                .frame(width: geometry.size.width, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 230, alignment: .topLeading)
                .layoutPriority(1)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .overlay {
            if dragOffset != .zero {
                SwipeFeedbackOverlay(
                    direction: isShowingPlaydate ? .playdate : .skip,
                    opacity: swipeProgress
                )
                .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
            }
        }
        .snootsCardShadow()
        .rotationEffect(.degrees(Double(dragOffset.width / 20)))
        .offset(x: dragOffset.width, y: dragOffset.height * 0.14)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        withAnimation(.snappy) { dragOffset = .zero }
                        return
                    }
                    if value.translation.width > swipeThreshold {
                        onSwipe(.playdate)
                    } else if value.translation.width < -swipeThreshold {
                        onSwipe(.skip)
                    } else {
                        withAnimation(.snappy) { dragOffset = .zero }
                    }
                }
        )
        .accessibilityElement(children: .contain)
        .accessibilityHint(language.text("Swipe right to show interest or left to skip.", "向右滑表示有興趣，向左滑略過。"))
    }

    private var localizedCompatibility: [String] {
        language == .english
            ? candidate.compatibility
            : ["慢熟", "牽繩初識", "體型相近"]
    }

    private var localizedAge: String {
        language.text(candidate.age, "2 歲")
    }

    private var localizedDistance: String {
        language.text(candidate.distance, "1.2 公里")
    }

    private var localizedSafetyLine: String {
        language.text(
            candidate.accountability,
            "身分已驗證 · 已分享疫苗紀錄"
        )
    }

    private var localizedIntro: String {
        language.text(
            candidate.intro,
            "慢慢認識後很愛玩。偏好先一起散步 20 分鐘，再開始自由玩耍。"
        )
    }
}

private struct MatchTraitChips: View {
    let labels: [String]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.snootsChip())
                    .foregroundStyle(SnootsPalette.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(SnootsPalette.primaryTint, in: Capsule())
            }
        }
    }
}

private struct SwipeFeedbackOverlay: View {
    let direction: MatchSwipeDirection
    let opacity: CGFloat

    var body: some View {
        let isPlaydate = direction == .playdate
        let feedbackOpacity = min(opacity * 1.35, 1)

        ZStack {
            RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous)
                .fill(
                    (isPlaydate ? SnootsPalette.lime : SnootsPalette.primary)
                        .opacity(0.62 * feedbackOpacity)
                )

            HStack {
                if !isPlaydate {
                    feedbackIcon(isPlaydate: isPlaydate)
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    feedbackIcon(isPlaydate: isPlaydate)
                }
            }
            .padding(24)
            .opacity(feedbackOpacity)
        }
        .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .allowsHitTesting(false)
    }

    private func feedbackIcon(isPlaydate: Bool) -> some View {
        Image(systemName: isPlaydate ? "heart.fill" : "xmark")
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(SnootsPalette.ink)
            .frame(width: 82, height: 82)
            .background(isPlaydate ? SnootsPalette.lime : SnootsPalette.primary, in: Circle())
            .overlay(Circle().stroke(SnootsPalette.ink, lineWidth: 2))
    }
}

private struct MatchedBanner: View {
    let candidate: PlaydateCandidate
    let language: SnootsLanguage

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(SnootsPalette.pink)
            Text(language.text("It’s a careful match!", "這是一場安心配對！")).font(.snootsScreenTitle())
            Text(language.text("You and \(candidate.owner) agreed to a quiet, leashed first hello.", "你和 \(candidate.owner) 都同意先來一場安靜、牽繩的初次見面。"))
                .font(.snootsBody())
                .multilineTextAlignment(.center)
                .foregroundStyle(SnootsPalette.secondaryText)
            Label(language.text("Shared behavior cards", "已分享行為資料卡"), systemImage: "checkmark.seal.fill")
                .font(.snootsUI(15, weight: .semibold))
                .foregroundStyle(SnootsPalette.deepLilac)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
    }
}

struct CareView: View {
    let store: SnootsStore
    let language: SnootsLanguage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.text("Emergency guidance", "緊急處置指引")).font(.snootsScreenTitle())
                        Text(language.text("Stay with your pet. Keep it simple.", "陪在狗狗身邊，簡單應對。"))
                            .font(.snootsBody())
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "cross.case.fill")
                        .font(.title2)
                        .foregroundStyle(SnootsPalette.ink)
                        .frame(width: 44, height: 44)
                        .background(SnootsPalette.careBlue, in: Circle())
                }

                Label(language.text("DEMO GUIDANCE ONLY · NOT CLINICAL TRIAGE", "僅供流程示範 · 非醫療分流"), systemImage: "info.circle.fill")
                    .font(.snootsChip())
                    .foregroundStyle(SnootsPalette.alert)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .background(SnootsPalette.alert.opacity(0.09), in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))

                CareProgressCard(step: store.currentCareStep, index: store.careStepIndex, total: store.careSteps.count, language: language)

                VStack(alignment: .leading, spacing: 12) {
                    Text(language.text("Critical symptoms noted", "已記錄的危急症狀")).font(.snootsCardTitle())
                    DeclarationChips(labels: store.criticalSymptoms.map { localizedCriticalSymptom($0, language: language) }, tint: SnootsPalette.softPink)
                }
                .padding(16)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                ClinicCard(clinic: store.clinic, language: language)

                Button(store.careStepIndex == store.careSteps.count - 1 ? language.text("Demo handoff complete", "示範交接完成") : language.text("Next scripted step", "下一個示範步驟")) {
                    store.advanceCareStep()
                }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.careBlue))
                .disabled(store.careStepIndex == store.careSteps.count - 1)

                Text(language.text("This prototype demonstrates an in-transit handoff flow. Contact local emergency services or a licensed clinic for real medical decisions.", "此原型示範前往診所途中的交接流程。實際醫療決策請聯絡當地緊急服務或合格診所。"))
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle(language.text("Emergency guidance", "緊急處置指引"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: store.careStepIndex)
    }
}

private func localizedCriticalSymptom(_ symptom: String, language: SnootsLanguage) -> String {
    switch symptom {
    case "Repeated vomiting": language.text(symptom, "反覆嘔吐")
    case "Very quiet": language.text(symptom, "異常安靜")
    case "Possible toxin": language.text(symptom, "疑似接觸毒物")
    default: symptom
    }
}

private struct CareProgressCard: View {
    let step: CareStep
    let index: Int
    let total: Int
    let language: SnootsLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(language.text("IN TRANSIT · STEP \(index + 1) OF \(total)", "前往診所中 · 第 \(index + 1)/\(total) 步"))
                    .font(.snootsChip())
                    .foregroundStyle(SnootsPalette.ink.opacity(0.78))
                Spacer()
                Image(systemName: step.symbol)
                    .font(.title2)
                    .foregroundStyle(SnootsPalette.ink)
            }
            Text(localizedTitle).font(.snootsCardTitle())
            Text(localizedInstruction).font(.snootsBody())
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { item in
                    Capsule().fill(item <= index ? SnootsPalette.ink : SnootsPalette.ink.opacity(0.18)).frame(height: 6)
                }
            }
        }
        .padding(18)
        .foregroundStyle(SnootsPalette.ink)
        .background(SnootsPalette.lavender, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }

    private var localizedTitle: String {
        guard language == .traditionalChinese else { return step.title }
        switch index {
        case 0: return "保持乘車環境平靜"
        case 1: return "準備交接資訊"
        default: return "抵達後重述重點"
        }
    }

    private var localizedInstruction: String {
        guard language == .traditionalChinese else { return step.instruction }
        switch index {
        case 0: return "使用穩固的提籠或胸背帶。保持空間安靜；除非合格臨床人員指示，避免餵食或用藥。"
        case 1: return "準備症狀開始時間、可能接觸物，以及一段可供分享的短影片。"
        default: return "到掛號處時，清楚說明症狀與可能接觸物，後續評估由診所接手。"
        }
    }
}

private struct ClinicCard: View {
    let clinic: Clinic
    let language: SnootsLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.title)
                    .foregroundStyle(SnootsPalette.careBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("Destination clinic", "目的地診所")).font(.snootsMetadata()).foregroundStyle(SnootsPalette.secondaryText)
                    Text(clinic.localizedName(language)).font(.snootsCardTitle())
                }
                Spacer()
                Text(clinic.localizedETA(language)).font(.snootsUI(15, weight: .semibold)).foregroundStyle(SnootsPalette.careBlue)
            }
            Divider().overlay(SnootsPalette.divider)
            Label(clinic.localizedAddress(language), systemImage: "location.fill")
            Label(clinic.localizedHandoff(language), systemImage: "doc.text.fill")
        }
        .font(.snootsUI(14))
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

struct MapsView: View {
    let store: SnootsStore
    let language: SnootsLanguage
    @Binding var selectedCategory: NearbyCategory?
    @Binding var selectedRegion: NearbyRegion
    let meetupFocusRequest: Int
    let onNavigate: (SnootsRoute) -> Void
    @State private var selectedSubcategory: NearbySubcategory? = nil
    @State private var selectedPlaceID: String?
    @State private var resultsPanelDetent: NearbyResultsDetent = .compact
    @State private var isRegionPickerPresented = false
    @State private var hasInitializedNearby = false
    @State private var handledMeetupFocusRequest = 0

    private var visiblePlaces: [Place] {
        return store.allPlaces.filter { place in
            (selectedCategory.map { place.nearbyCategory == $0 } ?? true)
                && selectedRegion.matches(place)
                && (selectedSubcategory.map { $0.matches(place) } ?? true)
        }
    }

    private var markers: [NearbyMapMarker] {
        guard visiblePlaces.count > 3 else {
            return visiblePlaces.map { NearbyMapMarker(place: $0, language: language) }
        }
        let leadingPins = visiblePlaces.prefix(2).map { NearbyMapMarker(place: $0, language: language) }
        let clustered = Array(visiblePlaces.dropFirst(2))
        return leadingPins + [NearbyMapMarker(cluster: clustered, language: language)]
    }

    private var resultsSummary: String {
        let category = selectedCategory?.title(language) ?? language.text("All activities", "全部活動")
        let region = selectedRegion.title(language)
        guard let selectedSubcategory else { return "\(category) · \(region)" }
        return "\(category) · \(selectedSubcategory.title(language)) · \(region)"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text(language.text("What’s nearby?", "附近有什麼"))
                        .font(.snootsScreenTitle())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button { onNavigate(.emergency) } label: {
                        Image(systemName: "cross.case.fill")
                            .font(.snootsUI(17, weight: .bold))
                            .foregroundStyle(SnootsPalette.ink)
                            .frame(width: 44, height: 44)
                            .background(SnootsPalette.lime, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.text("Find emergency care", "尋找緊急醫療"))
                }

                NearbyCategoryTagBar(selection: $selectedCategory, language: language)

                NearbySubcategoryStrip(
                    region: selectedRegion,
                    category: selectedCategory,
                    selection: $selectedSubcategory,
                    language: language,
                    onSelectRegion: { isRegionPickerPresented = true }
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 10)

            GeometryReader { proxy in
                let panelHeight = resultsPanelDetent.height(in: proxy.size.height)
                VStack(spacing: 0) {
                    NearbyMap(
                        markers: markers,
                        selectedPlaceID: $selectedPlaceID,
                        region: $selectedRegion,
                        language: language
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: max(180, proxy.size.height - panelHeight))

                    NearbyResultsPanel(
                        places: visiblePlaces,
                        summary: resultsSummary,
                        selectedPlaceID: $selectedPlaceID,
                        detent: $resultsPanelDetent,
                        language: language,
                        onOpen: { onNavigate(.place($0.id)) }
                    )
                    .frame(height: panelHeight)
                }
            }
        }
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .tabBar)
        .sheet(isPresented: $isRegionPickerPresented) {
            NearbyRegionPickerSheet(selection: $selectedRegion, language: language)
        }
        .onAppear {
            handleMeetupFocusIfNeeded()
            guard !hasInitializedNearby else { return }
            hasInitializedNearby = true
            selectedSubcategory = nil
        }
        .onChange(of: selectedCategory) { _, _ in
            selectedSubcategory = nil
            resetResults()
        }
        .onChange(of: selectedRegion) { _, _ in resetResults() }
        .onChange(of: selectedSubcategory) { _, _ in resetResults(keepPanelPosition: true) }
        .onChange(of: meetupFocusRequest) { _, _ in handleMeetupFocusIfNeeded() }
    }

    private func handleMeetupFocusIfNeeded() {
        guard handledMeetupFocusRequest != meetupFocusRequest else { return }
        handledMeetupFocusRequest = meetupFocusRequest
        selectedSubcategory = nil
        resetResults()
    }

    private func resetResults(keepPanelPosition: Bool = false) {
        selectedPlaceID = nil
        if !keepPanelPosition {
            resultsPanelDetent = .compact
        }
    }
}

enum NearbyCategory: CaseIterable, Identifiable, Hashable {
    case meetups, dining, parks, vets

    var id: Self { self }
    var symbol: String {
        switch self {
        case .meetups: "pawprint.fill"
        case .dining: "fork.knife"
        case .parks: "tree.fill"
        case .vets: "cross.case.fill"
        }
    }

    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .meetups: language.text("Dog meetups", "狗聚")
        case .dining: language.text("Dining", "用餐")
        case .parks: language.text("Parks", "公園")
        case .vets: language.text("Veterinary care", "獸醫院")
        }
    }
}

enum NearbyRegion: CaseIterable, Identifiable, Hashable {
    case currentLocation, zhongzheng, daan, xinyi

    var id: Self { self }

    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .currentLocation: language.text("Current location", "目前位置")
        case .zhongzheng: language.text("Zhongzheng", "中正區")
        case .daan: language.text("Da’an", "大安區")
        case .xinyi: language.text("Xinyi", "信義區")
        }
    }

    var cameraPosition: MapCameraPosition {
        if self == .currentLocation {
            return .userLocation(fallback: .region(Self.defaultRegion))
        }
        return .region(mapRegion)
    }

    var mapRegion: MKCoordinateRegion {
        let center: CLLocationCoordinate2D
        switch self {
        case .currentLocation: center = Self.defaultRegion.center
        case .zhongzheng: center = CLLocationCoordinate2D(latitude: 25.0324, longitude: 121.5199)
        case .daan: center = CLLocationCoordinate2D(latitude: 25.0268, longitude: 121.5434)
        case .xinyi: center = CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654)
        }
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035))
    }

    func matches(_ place: Place) -> Bool {
        self == .currentLocation || place.region == self
    }

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5480),
        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
    )
}

private enum NearbySubcategory: CaseIterable, Hashable, Identifiable {
    case leashedGroupWalk, indoorDogMeetup
    case freeMovement, floorAllowed, leashRequired, leashNotRequired, largeDog, mediumDog, smallDog
    case offLeash, naturalGrass, safetyFacilities, trainingFacilities, shadeCanopy, seating, allDay, daytime
    case emergency24Hours, residentVeterinarian, oxygenICU, pulseOximeter, bloodPanel, xRay, ultrasound

    var id: Self { self }

    var category: NearbyCategory {
        switch self {
        case .leashedGroupWalk, .indoorDogMeetup: .meetups
        case .freeMovement, .floorAllowed, .leashRequired, .leashNotRequired, .largeDog, .mediumDog, .smallDog: .dining
        case .offLeash, .naturalGrass, .safetyFacilities, .trainingFacilities, .shadeCanopy, .seating, .allDay, .daytime: .parks
        case .emergency24Hours, .residentVeterinarian, .oxygenICU, .pulseOximeter, .bloodPanel, .xRay, .ultrasound: .vets
        }
    }

    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .leashedGroupWalk: language.text("Leashed group walk", "牽繩團體散步")
        case .indoorDogMeetup: language.text("Indoor dog meetup", "室內狗聚")
        case .freeMovement: language.text("Free movement", "可自由活動")
        case .floorAllowed: language.text("Dogs on floor", "可落地")
        case .leashRequired: language.text("Leash required", "需要牽繩")
        case .leashNotRequired: language.text("No leash required", "不需要牽繩")
        case .largeDog: language.text("Large dog", "大型犬")
        case .mediumDog: language.text("Medium dog", "中型犬")
        case .smallDog: language.text("Small dog", "小型犬")
        case .offLeash: language.text("Off leash", "不需要牽繩")
        case .naturalGrass: language.text("Natural grass", "天然草皮")
        case .safetyFacilities: language.text("Safety facilities", "安全設施")
        case .trainingFacilities: language.text("Training facilities", "訓練設施")
        case .shadeCanopy: language.text("Shade canopy", "遮陽棚")
        case .seating: language.text("Seating", "休憩座椅")
        case .allDay: language.text("Good all day", "全天適合")
        case .daytime: language.text("Good in daytime", "適合白天")
        case .emergency24Hours: language.text("24-hour emergency", "24 小時急診")
        case .residentVeterinarian: language.text("Resident veterinarian", "駐診獸醫師")
        case .oxygenICU: language.text("Oxygen ICU", "ICU 氧氣病籠")
        case .pulseOximeter: language.text("Pulse oximeter", "血氧機")
        case .bloodPanel: language.text("Blood panel", "全套血檢")
        case .xRay: language.text("X-ray", "X 光")
        case .ultrasound: language.text("Ultrasound", "超音波")
        }
    }

    func matches(_ place: Place) -> Bool {
        switch self {
        case .leashedGroupWalk: place.category == "Leashed group walk"
        case .indoorDogMeetup: place.category == "Indoor dog meetup"
        case .freeMovement: place.intentKeywords.contains("free roam")
        case .floorAllowed: place.dogAccess != .carrierRequired
        case .leashRequired: place.rules.contains(.indoorLeash)
        case .leashNotRequired: !place.rules.contains(.indoorLeash)
        case .largeDog: place.acceptsLargeDogs
        case .mediumDog, .smallDog: place.nearbyCategory == .dining
        case .offLeash: place.intentKeywords.contains("free roam")
        case .naturalGrass: place.nearbyCategory == .parks
        case .safetyFacilities, .trainingFacilities: place.id == "xinyi-dog-park"
        case .shadeCanopy: place.facilities.contains(.shade)
        case .seating: place.facilities.contains(.outdoorSeating)
        case .allDay: place.id == "daan-forest"
        case .daytime: place.nearbyCategory == .parks
        case .emergency24Hours: place.id == "daan-night"
        case .residentVeterinarian: place.id == "xinyi-vet"
        case .oxygenICU, .pulseOximeter, .bloodPanel, .xRay, .ultrasound: place.id == "daan-night"
        }
    }

    static func options(for category: NearbyCategory) -> [Self] {
        allCases.filter { $0.category == category }
    }
}

private enum NearbyResultsDetent: Equatable {
    case compact, expanded

    func height(in availableHeight: CGFloat) -> CGFloat {
        let reservedForMap = max(180, availableHeight * 0.34)
        let maximumPanelHeight = max(220, availableHeight - reservedForMap)
        let preferredHeight: CGFloat = self == .compact ? 282 : 470
        return min(preferredHeight, maximumPanelHeight)
    }

    mutating func toggle() {
        self = self == .compact ? .expanded : .compact
    }
}

private struct NearbyCategoryTagBar: View {
    @Binding var selection: NearbyCategory?
    let language: SnootsLanguage

    var body: some View {
        HStack(spacing: 7) {
            ForEach(NearbyCategory.allCases) { category in
                let isSelected = selection == category
                Button {
                    selection = isSelected ? nil : category
                } label: {
                    Text(category.title(language))
                        .font(.snootsUI(14, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(SnootsPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(isSelected ? SnootsPalette.primary : SnootsPalette.surface, in: Capsule())
                        .overlay(Capsule().stroke(isSelected ? SnootsPalette.ink : SnootsPalette.divider, lineWidth: isSelected ? 1.5 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

private struct NearbySubcategoryStrip: View {
    let region: NearbyRegion
    let category: NearbyCategory?
    @Binding var selection: NearbySubcategory?
    let language: SnootsLanguage
    let onSelectRegion: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelectRegion) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                    Text(region.title(language))
                    Image(systemName: "chevron.down")
                        .font(.snootsUI(10, weight: .bold))
                }
                .font(.snootsChip())
                .foregroundStyle(SnootsPalette.ink)
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .background(SnootsPalette.lavenderTint, in: Capsule())
                .overlay(Capsule().stroke(SnootsPalette.lavender, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)

            if let category {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(NearbySubcategory.options(for: category)) { subcategory in
                            let isSelected = selection == subcategory
                            Button {
                                selection = isSelected ? nil : subcategory
                            } label: {
                                Text(subcategory.title(language))
                                    .font(.snootsChip())
                                    .foregroundStyle(SnootsPalette.ink)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 40)
                                    .background(isSelected ? SnootsPalette.primary : SnootsPalette.surface, in: Capsule())
                                    .overlay(Capsule().stroke(isSelected ? SnootsPalette.ink : SnootsPalette.divider, lineWidth: isSelected ? 1.5 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .id(category)
                .contentMargins(.horizontal, 1, for: .scrollContent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NearbyRegionPickerSheet: View {
    @Binding var selection: NearbyRegion
    let language: SnootsLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(NearbyRegion.allCases) { region in
                Button {
                    selection = region
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: region == .currentLocation ? "location.fill" : "mappin.and.ellipse")
                            .font(.snootsUI(17, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(selection == region ? SnootsPalette.lavenderTint : SnootsPalette.canvas, in: Circle())
                        Text(region.title(language))
                            .font(.snootsUI(17, weight: .semibold))
                        Spacer()
                        if selection == region {
                            Image(systemName: "checkmark")
                                .font(.snootsUI(15, weight: .bold))
                        }
                    }
                    .foregroundStyle(SnootsPalette.ink)
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(language.text("Choose area", "選擇區域"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

private struct NearbyMapMarker: Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let placeIDs: [String]

    init(place: Place, language: SnootsLanguage) {
        id = place.id
        name = place.localizedName(language)
        latitude = place.latitude
        longitude = place.longitude
        placeIDs = [place.id]
    }

    init(cluster: [Place], language: SnootsLanguage) {
        id = "cluster-\(cluster.map(\.id).joined(separator: "-"))"
        name = language.text("\(cluster.count) places", "\(cluster.count) 個地點")
        latitude = cluster.map(\.latitude).reduce(0, +) / Double(cluster.count)
        longitude = cluster.map(\.longitude).reduce(0, +) / Double(cluster.count)
        placeIDs = cluster.map(\.id)
    }

    var isCluster: Bool { placeIDs.count > 1 }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

private struct NearbyMap: View {
    let markers: [NearbyMapMarker]
    @Binding var selectedPlaceID: String?
    @Binding var region: NearbyRegion
    let language: SnootsLanguage
    @State private var position: MapCameraPosition = NearbyRegion.currentLocation.cameraPosition

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(markers) { marker in
                Annotation(marker.name, coordinate: marker.coordinate, anchor: .bottom) {
                    Button {
                        selectedPlaceID = marker.placeIDs.first
                    } label: {
                        NearbyMapPin(count: marker.placeIDs.count, isSelected: marker.placeIDs.contains(selectedPlaceID ?? ""))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(marker.isCluster ? language.text("\(marker.placeIDs.count) places clustered", "\(marker.placeIDs.count) 個地點群組") : marker.name)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .overlay(alignment: .topTrailing) {
            Button {
                region = .currentLocation
            } label: {
                Image(systemName: "location.fill")
                    .font(.snootsUI(16, weight: .bold))
                    .foregroundStyle(SnootsPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(SnootsPalette.surface, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            }
                .buttonStyle(.plain)
                .padding(14)
                .accessibilityLabel(language.text("Use current location", "使用目前位置"))
        }
        .onAppear { position = region.cameraPosition }
        .onChange(of: region) { _, newRegion in
            withAnimation(.snappy) {
                position = newRegion.cameraPosition
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(language.text("Nearby results map", "附近結果地圖"))
    }
}

private struct NearbyMapPin: View {
    let count: Int
    let isSelected: Bool

    var body: some View {
        Group {
            if count == 1 {
                Image(systemName: "mappin.circle.fill")
                    .font(.snootsUI(23, weight: .bold))
            } else {
                Text("\(count)")
                    .font(.snootsUI(15, weight: .bold))
            }
        }
            .foregroundStyle(SnootsPalette.ink)
            .frame(width: isSelected ? 54 : 46, height: isSelected ? 54 : 46)
            .background(isSelected ? SnootsPalette.lime : SnootsPalette.primary, in: Circle())
            .overlay(Circle().stroke(SnootsPalette.ink, lineWidth: 2))
            .shadow(color: .black.opacity(isSelected ? 0.18 : 0.10), radius: isSelected ? 10 : 6, y: isSelected ? 6 : 3)
            .offset(y: isSelected ? -6 : 0)
            .animation(.snappy, value: isSelected)
    }
}

private struct NearbyResultsPanel: View {
    let places: [Place]
    let summary: String
    @Binding var selectedPlaceID: String?
    @Binding var detent: NearbyResultsDetent
    let language: SnootsLanguage
    let onOpen: (Place) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { detent.toggle() }
            } label: {
                Capsule()
                    .fill(SnootsPalette.ink.opacity(0.18))
                    .frame(width: 44, height: 5)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onEnded { value in
                        guard abs(value.translation.height) > 28 else { return }
                        withAnimation(.snappy) {
                            detent = value.translation.height < 0 ? .expanded : .compact
                        }
                    }
            )
            .accessibilityLabel(detent == .expanded ? language.text("Collapse results", "收合結果") : language.text("Expand results", "展開結果"))
            .accessibilityHint(language.text("Drag up to see the full list. Drag down to see more of the map", "向上拉查看完整清單；向下拉查看更多地圖"))

            HStack(alignment: .firstTextBaseline) {
                Text(summary)
                    .font(.snootsSection())
                    .lineLimit(1)
                Spacer()
                Text(language.text("\(places.count) found", "找到 \(places.count) 個"))
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            if places.isEmpty {
                ContentUnavailableView(language.text("No matches yet", "暫時沒有符合的結果"), systemImage: "pawprint.fill", description: Text(language.text("Try removing one condition.", "試著移除一個條件。")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(places) { place in
                                NearbyPlaceCard(place: place, isSelected: selectedPlaceID == place.id, language: language) {
                                    selectedPlaceID = place.id
                                    onOpen(place)
                                }
                                .id(place.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 14)
                    }
                    .onChange(of: selectedPlaceID) { _, placeID in
                        guard let placeID, places.contains(where: { $0.id == placeID }) else { return }
                        withAnimation(.snappy) {
                            proxy.scrollTo(placeID, anchor: .top)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(SnootsPalette.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: SnootsMetrics.cardRadius, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: SnootsMetrics.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, y: -5)
    }
}

private struct NearbyPlaceCard: View {
    let place: Place
    let isSelected: Bool
    let language: SnootsLanguage
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 5) {
                Text(place.localizedName(language))
                    .font(.snootsCardTitle())
                    .foregroundStyle(SnootsPalette.ink)
                Text(place.localizedCategory(language))
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
                HStack(spacing: 5) {
                    Text(place.localizedWalk(language))
                    Text("·")
                    Text(place.isOpenNow ? language.text("Open", "營業中") : language.text("Closed", "休息中"))
                        .foregroundStyle(place.isOpenNow ? SnootsPalette.deepLilac : SnootsPalette.secondaryText)
                }
                .font(.snootsMetadata())
                Text(place.dogAccess.label(language))
                    .font(.snootsChip())
                    .foregroundStyle(SnootsPalette.ink)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(SnootsPalette.butter, in: Capsule())
                Label("\(place.verificationLevel.label(language)) · \(place.localizedLastConfirmed(language))", systemImage: "checkmark.seal.fill")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(isSelected ? SnootsPalette.primaryTint : SnootsPalette.canvas, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous)
                    .stroke(isSelected ? SnootsPalette.ink : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(language.text("Open place details", "開啟地點詳情"))
    }
}

struct PlaceDetailView: View {
    let place: Place
    let store: SnootsStore
    let language: SnootsLanguage
    @State private var feedback: PlaceFeedback?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                    PhotoTile(imageName: place.imageName, label: place.localizedName(language), language: language)
                        .frame(height: 210)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.localizedName(language)).font(.snootsScreenTitle())
                        Text("\(place.localizedCategory(language)) · \(place.localizedWalk(language))")
                            .font(.snootsBody())
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }

                    DogAccessPolicyCard(place: place, language: language)
                    PracticalPlaceInfo(place: place, language: language)
                    FeedbackCard(feedback: $feedback, language: language)

                    Button(store.isSaved(place) ? language.text("Remove saved place", "移除已儲存地點") : language.text("Save place", "儲存地點")) { store.toggleSaved(place) }
                        .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                        .accessibilityValue(store.isSaved(place) ? language.text("Saved", "已儲存") : language.text("Not saved", "尚未儲存"))
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle(language.text("Place details", "地點詳情"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct DogAccessPolicyCard: View {
    let place: Place
    let language: SnootsLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(language.text("Dog access policy", "狗狗入場規範"), systemImage: "pawprint.fill")
                .font(.snootsSection())
            Text(place.policySummary(language))
                .font(.snootsBody())
                .foregroundStyle(SnootsPalette.secondaryText)

            PolicyLine(title: language.text("Indoor access", "室內可進入？"), value: place.dogAccess.detail(language), symbol: "house.fill")
            PolicyLine(title: language.text("Size / weight limits", "體型／重量限制"), value: place.sizeRule(language), symbol: "scalemass.fill")
            PolicyLine(title: language.text("Equipment required", "需要的裝備"), value: place.equipmentRule(language), symbol: "link")
            PolicyLine(title: language.text("Seating / floor rules", "座位／地面規則"), value: place.seatingRule(language), symbol: "chair.lounge.fill")
            PolicyLine(title: language.text("Time / day restrictions", "時段／日期限制"), value: place.timeRule(language), symbol: "clock.fill")

            Label("\(language.text("Source", "來源")): \(place.localizedVerificationSource(language)) · \(place.localizedLastConfirmed(language))", systemImage: "checkmark.seal.fill")
                .font(.snootsMetadata())
                .foregroundStyle(SnootsPalette.deepLilac)
        }
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

private struct PolicyLine: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.snootsUI(14, weight: .semibold))
                .foregroundStyle(SnootsPalette.ink)
                .frame(width: 28, height: 28)
                .background(SnootsPalette.primaryTint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.snootsMetadata()).foregroundStyle(SnootsPalette.secondaryText)
                Text(value).font(.snootsUI(14, weight: .medium))
            }
        }
    }
}

private struct PracticalPlaceInfo: View {
    let place: Place
    let language: SnootsLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.text("Practical info", "實用資訊"))
                .font(.snootsSection())
            HStack {
                Label(place.openingHours(language), systemImage: "clock.fill")
                Spacer()
                Text(place.isOpenNow ? language.text("Open now", "營業中") : language.text("Closed", "休息中"))
                    .font(.snootsChip())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(place.isOpenNow ? SnootsPalette.lime : SnootsPalette.canvas, in: Capsule())
            }
            .font(.snootsUI(14, weight: .medium))
            Label(place.localizedAddress(language), systemImage: "location.fill")
                .font(.snootsUI(14))

            HStack(spacing: 8) {
                PlaceActionLink(title: language.text("Call", "撥打"), symbol: "phone.fill", destination: URL(string: "tel://0227012020")!)
                PlaceActionLink(title: language.text("Navigate", "導航"), symbol: "arrow.triangle.turn.up.right.diamond.fill", destination: URL(string: "https://maps.apple.com/?q=\(place.latitude),\(place.longitude)")!)
                PlaceActionLink(title: language.text("Website", "網站"), symbol: "safari.fill", destination: URL(string: "https://example.com")!)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(language.text("Facilities", "設施")).font(.snootsMetadata()).foregroundStyle(SnootsPalette.secondaryText)
                DeclarationChips(labels: place.facilities.map { $0.label(language) }, tint: SnootsPalette.butter)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(language.text("Real-world notes", "現場提醒")).font(.snootsMetadata()).foregroundStyle(SnootsPalette.secondaryText)
                ForEach(place.realWorldNotes(language), id: \.self) { note in
                    Label(note, systemImage: "text.bubble.fill")
                        .font(.snootsUI(14))
                }
            }
        }
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

private struct PlaceActionLink: View {
    let title: String
    let symbol: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            Label(title, systemImage: symbol)
                .font(.snootsUI(13, weight: .semibold))
                .foregroundStyle(SnootsPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(SnootsPalette.canvas, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
        }
    }
}

private enum PlaceFeedback: String, CaseIterable, Identifiable {
    case confirm, reportChange, addCondition, markClosed
    var id: Self { self }
    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .confirm: language.text("Confirm", "確認正確")
        case .reportChange: language.text("Report change", "回報變更")
        case .addCondition: language.text("Add condition", "新增條件")
        case .markClosed: language.text("Mark closed", "標示已歇業")
        }
    }
}

private struct FeedbackCard: View {
    @Binding var feedback: PlaceFeedback?
    let language: SnootsLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.text("Was the dog-access info correct?", "狗狗入場資訊正確嗎？"))
                .font(.snootsCardTitle())
            if feedback != nil {
                Label(language.text("Thanks — your update helps other dog owners.", "謝謝，你的更新能幫助其他飼主。"), systemImage: "checkmark.circle.fill")
                    .font(.snootsUI(14, weight: .medium))
                    .foregroundStyle(SnootsPalette.deepLilac)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PlaceFeedback.allCases) { option in
                            Button(option.title(language)) { feedback = option }
                                .font(.snootsChip())
                                .foregroundStyle(SnootsPalette.ink)
                                .padding(.horizontal, 11)
                                .frame(minHeight: 40)
                                .background(SnootsPalette.canvas, in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
    }
}

struct ProfileView: View {
    let store: SnootsStore
    let language: SnootsLanguage
    @Binding var displayLanguageRawValue: String
    let onNavigate: (SnootsRoute) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.text("\(store.pet.name)’s profile", "\(store.pet.name) 的檔案")).font(.snootsScreenTitle())
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        NavigationLink {
                            EditProfileView(store: store, language: language)
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(SnootsPalette.ink)
                                .frame(width: 44, height: 44)
                                .background(SnootsPalette.surface, in: Circle())
                        }
                        .accessibilityLabel(language.text("Edit profile", "編輯檔案"))

                        NavigationLink {
                            LanguageSettingsView(selectedLanguageRawValue: $displayLanguageRawValue)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(SnootsPalette.ink)
                                .frame(width: 44, height: 44)
                                .background(SnootsPalette.surface, in: Circle())
                        }
                        .accessibilityLabel(language.text("Settings", "設定"))
                    }
                }

                HStack(spacing: 14) {
                    PhotoTile(
                        imageName: store.pet.imageName,
                        label: store.pet.name,
                        language: language,
                        showsLabel: false
                    )
                        .frame(width: 104, height: 104)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.pet.name).font(.snootsScreenTitle())
                        Text(language.text("Managed by \(store.profile.name)", "由 \(store.profile.name) 管理"))
                            .font(.snootsBody())
                            .foregroundStyle(SnootsPalette.secondaryText)
                        Label(localizedNeighborhood(store.profile.neighborhood, language: language), systemImage: "location.fill")
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.deepLilac)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                FeedingInformationCard(monitor: store.feedingMonitor, language: language)

                VStack(alignment: .leading, spacing: 8) {
                    Text(language.text("Interaction tags", "互動標籤")).font(.snootsSection())
                    DeclarationChips(labels: store.pet.traits.map { localizedTrait($0, language: language) }, tint: SnootsPalette.butter)
                }
                .padding(16)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text(language.text("Care essentials", "照護重點")).font(.snootsSection())
                    NavigationLink {
                        RabiesRecordView(record: store.care.rabies, language: language)
                    } label: {
                        CareStatusRow(
                            symbol: "cross.case.fill",
                            title: language.text("Rabies vaccination", "狂犬病疫苗"),
                            detail: language.text("Verified · Valid until \(store.care.rabies.validUntil)", "已驗證 · 有效至 2026 年 9 月 14 日"),
                            accent: SnootsPalette.lime
                        )
                    }
                    .buttonStyle(.plain)
                    CareStatusRow(
                            symbol: "heart.text.square.fill",
                            title: language.text("Health notes", "健康備註"),
                            detail: language.text(store.care.healthNotes, "結紮日期：2025 年 3 月 8 日 · 無慢性病\n上次看診：2026 年 7 月 10 日"),
                        accent: SnootsPalette.lavenderTint
                    )
                }
                .padding(16)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                if !store.savedPlaces.isEmpty {
                    Text(language.text("Saved places", "已儲存地點")).font(.snootsSection())
                    ForEach(store.savedPlaces) { place in
                        Button { onNavigate(.place(place.id)) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.localizedName(language)).font(.snootsCardTitle())
                                    Text("\(place.localizedCategory(language)) · \(place.localizedWalk(language))").font(.snootsMetadata())
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(SnootsPalette.ink)
                            .padding(14)
                            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(language.text("Shows venue rules and save options", "顯示地點規範與儲存選項"))
                    }
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private func localizedTrait(_ trait: String, language: SnootsLanguage) -> String {
    switch trait {
    case "Slow introductions": language.text("Slow introductions", "慢慢認識")
    case "Adult dogs": language.text("Adult dogs", "偏好成犬")
    case "Long lead": language.text("Long lead", "長牽繩散步")
    case "Calm walks": language.text("Calm walks", "平靜散步")
    case "Needs space": language.text("Needs space", "需要一些空間")
    default: language.text(trait, "溫和互動")
    }
}

private func localizedNeighborhood(_ neighborhood: String, language: SnootsLanguage) -> String {
    language.text(neighborhood, "臺北市大安區")
}

private struct CareStatusRow: View {
    let symbol: String
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(SnootsPalette.ink)
                .frame(width: 42, height: 42)
                .background(accent, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.snootsCardTitle())
                Text(detail).font(.snootsMetadata()).foregroundStyle(SnootsPalette.secondaryText)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct RabiesRecordView: View {
    let record: VaccineRecord
    let language: SnootsLanguage

    var body: some View {
        List {
            Section {
                Label(language.text("Verified · Valid until \(record.validUntil)", "已驗證 · 有效至 \(record.validUntil)"), systemImage: "checkmark.seal.fill")
                    .font(.snootsCardTitle())
                    .foregroundStyle(SnootsPalette.deepLilac)
            }
            Section(language.text("Record details", "疫苗紀錄")) {
                LabeledContent(language.text("Vaccinated on", "接種日期"), value: language.text(record.vaccinatedOn, "2025 年 9 月 14 日"))
                LabeledContent(language.text("Valid until", "有效期限"), value: language.text(record.validUntil, "2026 年 9 月 14 日"))
                LabeledContent(language.text("Veterinary clinic", "施打診所"), value: language.text(record.clinic, "大安動物醫院"))
                LabeledContent(language.text("Vaccine", "疫苗名稱"), value: record.manufacturer)
                LabeledContent(language.text("Batch number", "批號"), value: record.batchNumber)
            }
            Section(language.text("Privacy", "隱私")) {
                Label(language.text("Only a verified status is shared with matches.", "配對對象只會看到已驗證的狀態。"), systemImage: "lock.fill")
                    .font(.snootsBody())
            }
        }
        .navigationTitle(language.text("Rabies vaccination", "狂犬病疫苗"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LanguageSettingsView: View {
    @Binding var selectedLanguageRawValue: String

    private var language: SnootsLanguage {
        SnootsLanguage(rawValue: selectedLanguageRawValue) ?? .traditionalChinese
    }

    var body: some View {
        Form {
            Section(language.text("Display language", "顯示語言")) {
                Picker(language.text("App language", "App 語言"), selection: $selectedLanguageRawValue) {
                    ForEach(SnootsLanguage.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle(language.text("Settings", "設定"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FeedingInformationCard: View {
    let monitor: FeedingMonitor
    let language: SnootsLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(language.text("Feeding information", "餵養資訊"))
                    .font(.snootsSection())
                Spacer()
                Label(
                    monitor.isOnline
                        ? language.text("Monitor online", "監視器已連線")
                        : language.text("Monitor offline", "監視器離線"),
                    systemImage: monitor.isOnline ? "dot.radiowaves.left.and.right" : "wifi.slash"
                )
                .font(.snootsMetadata())
                .foregroundStyle(monitor.isOnline ? SnootsPalette.navigationActive : SnootsPalette.secondaryText)
            }

            HStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.headline)
                    .foregroundStyle(SnootsPalette.ink)
                    .frame(width: 40, height: 40)
                    .background(SnootsPalette.lime, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("Last fed", "上次餵食"))
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                    Text(language.text("\(monitor.lastFedHoursAgo) hours ago", "\(monitor.lastFedHoursAgo) 小時前"))
                        .font(.snootsCardTitle())
                }
                Spacer()
                Label(
                    language.text("Feeding detected", "已偵測到餵食"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.snootsMetadata())
                .foregroundStyle(SnootsPalette.navigationActive)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label(language.text("Water", "飲水量"), systemImage: "drop.fill")
                        .font(.snootsUI(15, weight: .semibold))
                    Spacer()
                    Text("\(monitor.waterIntakeMilliliters) / \(monitor.waterGoalMilliliters) \(language.text("mL", "毫升"))")
                        .font(.snootsUI(15, weight: .semibold))
                }
                ProgressView(value: monitor.waterProgress)
                    .tint(SnootsPalette.primary)
                Label(
                    language.text("Drinking detected by pet monitor", "寵物監視器已偵測到飲水"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.snootsMetadata())
                .foregroundStyle(SnootsPalette.secondaryText)
            }
        }
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(language.text("Feeding monitor status", "餵養監視器狀態"))
    }
}

private struct EditProfileView: View {
    let store: SnootsStore
    let language: SnootsLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var ownerName: String
    @State private var city: String
    @State private var district: String
    @State private var petName: String
    @State private var socialSummary: String

    init(store: SnootsStore, language: SnootsLanguage) {
        self.store = store
        self.language = language
        _ownerName = State(initialValue: store.profile.name)
        _city = State(initialValue: store.profile.neighborhood.contains("New Taipei") ? "New Taipei City" : "Taipei City")
        _district = State(initialValue: store.profile.neighborhood.contains("Xinyi") ? "Xinyi District" : "Da’an District")
        _petName = State(initialValue: store.pet.name)
        _socialSummary = State(initialValue: language == .traditionalChinese ? "Nori 需要一些時間熟悉彼此，之後喜歡平靜散步與熟悉的夥伴。" : store.pet.summary)
    }

    private var suggestedTraits: [String] {
        let text = socialSummary.lowercased()
        var tags: [String] = []

        if text.contains("slow") || text.contains("慢") { tags.append("Slow introductions") }
        if text.contains("adult") || text.contains("成犬") { tags.append("Adult dogs") }
        if text.contains("long lead") || text.contains("長牽繩") { tags.append("Long lead") }
        if text.contains("calm") || text.contains("quiet") || text.contains("平靜") || text.contains("安靜") { tags.append("Calm walks") }
        if text.contains("space") || text.contains("距離") || text.contains("空間") { tags.append("Needs space") }

        return tags.isEmpty ? ["Slow introductions"] : tags
    }

    private var cities: [String] { ["Taipei City", "New Taipei City"] }

    private var districts: [String] {
        city == "Taipei City"
            ? ["Da’an District", "Xinyi District", "Zhongshan District"]
            : ["Banqiao District", "Xindian District", "Yonghe District"]
    }

    private func locationLabel(_ value: String) -> String {
        switch value {
        case "Taipei City": language.text("Taipei City", "臺北市")
        case "New Taipei City": language.text("New Taipei City", "新北市")
        case "Da’an District": language.text("Da’an District", "大安區")
        case "Xinyi District": language.text("Xinyi District", "信義區")
        case "Zhongshan District": language.text("Zhongshan District", "中山區")
        case "Banqiao District": language.text("Banqiao District", "板橋區")
        case "Xindian District": language.text("Xindian District", "新店區")
        case "Yonghe District": language.text("Yonghe District", "永和區")
        default: value
        }
    }

    var body: some View {
        Form {
            Section(language.text("Dog information", "狗狗資料")) {
                TextField(language.text("Dog’s name", "狗狗名字"), text: $petName)
            }

            Section(language.text("Social preferences", "互動偏好")) {
                TextField(language.text("Describe how \(petName) likes to meet and play", "描述 \(petName) 喜歡如何認識與互動"), text: $socialSummary, axis: .vertical)
                    .lineLimit(3...5)
                VStack(alignment: .leading, spacing: 8) {
                    Text(language.text("Suggested tags", "建議標籤"))
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                    DeclarationChips(labels: suggestedTraits.map { localizedTrait($0, language: language) }, tint: SnootsPalette.butter)
                }
            }

            Section {
                TextField(language.text("Owner’s name", "飼主姓名"), text: $ownerName)
                Picker(language.text("City", "縣市"), selection: $city) {
                    ForEach(cities, id: \.self) { city in
                        Text(locationLabel(city)).tag(city)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: city) { _, _ in
                    if !districts.contains(district) { district = districts[0] }
                }

                Picker(language.text("District", "行政區"), selection: $district) {
                    ForEach(districts, id: \.self) { district in
                        Text(locationLabel(district)).tag(district)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                HStack {
                    Text(language.text("Owner details", "飼主資料"))
                    Spacer()
                    Label(language.text("Verified", "已驗證"), systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle(language.text("Edit profile", "編輯檔案"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(language.text("Save", "儲存")) {
                    store.updateProfile(
                        ownerName: ownerName,
                        neighborhood: "\(district), \(city)",
                        petName: petName,
                        summary: socialSummary,
                        traits: suggestedTraits
                    )
                    dismiss()
                }
                .font(.snootsUI(15, weight: .semibold))
            }
        }
    }
}

struct MatchConfirmationView: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    let language: SnootsLanguage
    let onNavigate: (SnootsRoute) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(SnootsPalette.pink)
                .frame(width: 112, height: 112)
                .background(SnootsPalette.softPink, in: Circle())
            Text(language.text("\(candidate.name) is interested too!", "\(candidate.name) 也有興趣！")).font(.snootsScreenTitle())
            Text(language.text("Review your verified behavior cards and confirm a safe first hello.", "查看彼此已驗證的互動資料卡，再確認一場安全的初次見面。"))
                .font(.snootsBody())
                .multilineTextAlignment(.center)
                .foregroundStyle(SnootsPalette.secondaryText)
                .padding(.horizontal, 26)
            Button(language.text("Confirm match", "確認配對")) {
                store.isMatched = true
                store.createMatchChat()
                onNavigate(.chat)
            }
            .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
            Button(language.text("Not yet", "暫時不要")) { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
            Spacer()
        }
        .padding(22)
        .navigationTitle(language.text("Confirm match", "確認配對"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct MatchChatRoom: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    let language: SnootsLanguage
    @FocusState private var isComposerFocused: Bool
    @State private var draft = ""

    private var openingGreetings: [String] {
        [
            language.text(
                "Hi Elena! Mochi seems lovely. Would you like to start with a walk together?",
                "嗨 Elena！Mochi 看起來很可愛，要不要先一起散步？"
            ),
            language.text(
                "Would a 20-minute parallel walk feel good for Mochi?",
                "先安排 20 分鐘的平行散步，Mochi 會覺得舒服嗎？"
            ),
            language.text(
                "What time works well for a calm first hello this week?",
                "這週什麼時間適合來一場安靜的初次見面？"
            )
        ]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(candidate.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.text("You matched with \(candidate.name)", "你和 \(candidate.name) 配對成功"))
                            .font(.snootsCardTitle())
                        Label(
                            language.text("Elena · Identity verified", "Elena · 身分已驗證"),
                            systemImage: "checkmark.seal.fill"
                        )
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))

                if !store.matchChatMessages.isEmpty {
                    Text(language.text("Messages", "訊息"))
                        .font(.snootsSection())
                        .padding(.top, 4)

                    ForEach(store.matchChatMessages) { message in
                        HStack {
                            if message.isOutgoing { Spacer(minLength: 52) }
                            Text(message.text)
                                .font(.snootsBody())
                                .foregroundStyle(SnootsPalette.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background(
                                    message.isOutgoing ? SnootsPalette.lime : SnootsPalette.surface,
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                )
                            if !message.isOutgoing { Spacer(minLength: 52) }
                        }
                    }
                }
            }
            .padding(18)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.text("Start with a friendly hello", "從一句友善的問候開始"))
                    .font(.snootsSection())

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(openingGreetings, id: \.self) { greeting in
                            Button {
                                send(greeting)
                            } label: {
                                Text(greeting)
                                    .font(.snootsUI(14, weight: .medium))
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(SnootsPalette.ink)
                                    .frame(width: 230, alignment: .leading)
                                    .padding(14)
                                    .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }

                HStack(spacing: 10) {
                    TextField(language.text("Write a message", "輸入訊息"), text: $draft, axis: .vertical)
                        .font(.snootsBody())
                        .lineLimit(1...4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
                        .focused($isComposerFocused)
                        .submitLabel(.send)
                        .onSubmit { send(draft) }

                    Button { send(draft) } label: {
                        Image(systemName: "arrow.up")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(SnootsPalette.ink)
                            .frame(width: 44, height: 44)
                            .background(SnootsPalette.lime, in: Circle())
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                    .accessibilityLabel(language.text("Send message", "傳送訊息"))
                }
            }
            .padding(14)
            .background(SnootsPalette.canvas)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle(language.text("Chat with Elena", "與 Elena 聊天"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func send(_ text: String) {
        store.sendMatchChatMessage(text)
        draft = ""
        isComposerFocused = false
    }
}

private struct PhotoTile: View {
    let imageName: String
    let label: String
    let language: SnootsLanguage
    var showsLabel = true

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                if showsLabel {
                    HStack(spacing: 5) {
                        Image(systemName: "camera.fill")
                        Text(label)
                    }
                    .font(.snootsChip())
                    .foregroundStyle(SnootsPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(SnootsPalette.butter, in: Capsule())
                    .padding(12)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.profileImageRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text("Photo: \(label)", "照片：\(label)"))
    }
}

private struct DeclarationChips: View {
    let labels: [String]
    let tint: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.snootsChip())
                        .foregroundStyle(SnootsPalette.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(tint, in: Capsule())
                }
            }
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.snootsButton(17))
            .foregroundStyle(SnootsPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: SnootsMetrics.buttonRadius, style: .continuous))
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.snootsButton(17))
            .foregroundStyle(SnootsPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(SnootsPalette.surface.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: SnootsMetrics.buttonRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SnootsMetrics.buttonRadius, style: .continuous)
                    .stroke(SnootsPalette.primary, lineWidth: 2)
            }
    }
}

enum SnootsPalette {
    static let background = Color(light: 0xF7F7F4, dark: 0x11110F)
    static let card = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let ink = Color(light: 0x222222, dark: 0xF2F2F7)
    static let inactive = Color(light: 0x888888, dark: 0xA0A0A7)
    static let secondaryText = Color(light: 0x666666, dark: 0xB0B0B8)
    static let placeholder = Color(light: 0xA3A3A3, dark: 0x8E8E93)
    static let divider = Color(light: 0xECECEC, dark: 0x38383A)
    static let primary = Color(hex: 0xB8A1FF)
    static let primaryTint = primary.opacity(0.32)
    static let lime = Color(hex: 0xC7F36B)
    static let navigationActive = Color(light: 0x705A9D, dark: 0xCBB9FF)

    static let canvas = background
    static let surface = card
    static let pink = primary
    static let softPink = primaryTint
    static let lavender = primary
    static let lavenderTint = primaryTint
    static let lilac = primary
    static let deepLilac = ink
    static let sky = primary
    static let careBlue = primary
    static let careTint = primaryTint
    static let butter = primaryTint
    static let alert = ink
}

private extension Color {
    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private enum SnootsMetrics {
    static let buttonRadius: CGFloat = 20
    static let cardRadius: CGFloat = 28
    static let inputRadius: CGFloat = 18
    static let profileImageRadius: CGFloat = 24
}

private extension View {
    func snootsCardShadow() -> some View {
        shadow(color: .black.opacity(0.08), radius: 20, y: 6)
    }
}

extension Font {
    static func snootsLogo(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func snootsHeading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func snootsScreenTitle() -> Font { .system(.largeTitle, design: .rounded).weight(.semibold) }
    static func snootsSection() -> Font { .system(.title3, design: .rounded).weight(.semibold) }
    static func snootsCardTitle() -> Font { .system(.headline, design: .rounded).weight(.semibold) }
    static func snootsUI(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let textStyle: Font.TextStyle
        switch size {
        case ..<13: textStyle = .caption
        case ..<15: textStyle = .subheadline
        case ..<18: textStyle = .body
        default: textStyle = .title3
        }
        return .system(textStyle, design: .rounded).weight(weight)
    }

    static func snootsBody() -> Font { .system(.body, design: .rounded) }
    static func snootsMetadata() -> Font { .system(.caption, design: .rounded).weight(.medium) }
    static func snootsChip() -> Font { .system(.caption, design: .rounded).weight(.medium) }
    static func snootsButton(_ size: CGFloat) -> Font { .system(.headline, design: .rounded).weight(.bold) }
}
