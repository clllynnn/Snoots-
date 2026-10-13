import MapKit
import NaturalLanguage
import PhotosUI
import SwiftUI
import UIKit

private enum SnootsFeatureVisibility {
    static let nearby = false
    static let createMeetup = true
    static let feedingInformation = false
}

struct ContentView: View {
    @Environment(MeetupRepository.self) private var meetups
    @State private var showMeetupInvitation = false
    let store: SnootsStore
    let language: SnootsLanguage
    @Binding var displayLanguageRawValue: String
    @State private var selectedTab: AppTab = .feed
    @State private var selectedNearbyCategory: NearbyCategory?
    @State private var selectedNearbyRegion: NearbyRegion = .currentLocation
    @State private var meetupFocusRequest = 0
    @State private var meetupFocusTargetID: String?
    @State private var matchPath: [SnootsRoute] = []
    @State private var mapsPath: [SnootsRoute] = []
    @State private var profilePath: [SnootsRoute] = []
    @State private var chatPath: [SnootsRoute] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $matchPath) {
                PlaydatesView(store: store, language: language) { matchPath.append($0) }
                    .navigationDestination(for: SnootsRoute.self) { route in
                        switch route {
                        case .match:
                            MatchConfirmationView(
                                candidate: store.activeMatchCandidate,
                                store: store,
                                language: language,
                                onNavigate: { matchPath.append($0) }
                            )
                        case .matchSetup:
                            BeforeMatchingView(store: store)
                        case .chat:
                            MatchChatRoom(
                                candidate: store.activeMatchCandidate,
                                store: store,
                                language: language,
                                onNavigate: { matchPath.append($0) },
                                onBackToChatList: { matchPath = [.chatList] }
                            )
                        case .chatList:
                            MatchChatListView(
                                candidate: store.activeMatchCandidate,
                                store: store,
                                language: language,
                                onNavigate: { matchPath.append($0) }
                            )
                        case .meetupChatList:
                            MatchChatListView(
                                candidate: store.activeMatchCandidate,
                                store: store,
                                language: language,
                                initiallySelectedTab: .meetups,
                                onNavigate: { matchPath.append($0) }
                            )
                        case .meetupChat:
                            MeetupGroupChatRoom(
                                meetup: store.upcomingMeetup,
                                store: store,
                                language: language,
                                onOpenDashboard: { matchPath.append(.groupDashboard) },
                                onOpenSettings: { matchPath.append(.groupSettings) }
                            )
                        case .meetupParticipants:
                            MeetupParticipantListView(meetup: store.upcomingMeetup, language: language)
                        case .icebreaker:
                            if store.isMatchVerificationActive {
                                #if DEBUG
                                DailyTaskVerificationView(candidate: store.activeMatchCandidate)
                                #endif
                            } else {
                                DailyIcebreakerTaskView(
                                    candidate: store.activeMatchCandidate,
                                    store: store,
                                    language: language,
                                    onNavigate: { matchPath.append($0) }
                                )
                            }
                        case .safety:
                            MeetupSafetyView(
                                candidate: store.activeMatchCandidate,
                                store: store,
                                language: language,
                                onNavigate: { matchPath.append($0) }
                            )
                        case .dashboard:
                            OfflineMeetupDashboard(
                                candidate: store.activeMatchCandidate,
                                store: store,
                                language: language
                            )
                        case .groupDashboard:
                            GroupMeetupDashboard(meetup: store.upcomingMeetup, store: store, language: language)
                        case .groupSettings:
                            MeetupGroupSettingsView(
                                meetup: store.upcomingMeetup,
                                store: store,
                                language: language,
                                onOpenParticipants: { matchPath.append(.meetupParticipants) },
                                onLeaveGroup: { matchPath = [.meetupChatList] }
                            )
                        case .memories:
                            SharedMemoriesView(candidate: store.activeMatchCandidate, store: store, language: language)
                        case .emergency, .place:
                            EmptyView()
                        }
                    }
            }
                .tint(SnootsPalette.navigationActive)
                .tabItem { AppTab.match.icon(isSelected: selectedTab == .match).accessibilityLabel(language.text("Match", "配對")) }
                .tag(AppTab.match)

            if SnootsFeatureVisibility.nearby {
                NavigationStack(path: $mapsPath) {
                    MapsView(
                        store: store,
                        language: language,
                        selectedCategory: $selectedNearbyCategory,
                        selectedRegion: $selectedNearbyRegion,
                        meetupFocusRequest: meetupFocusRequest,
                        meetupFocusTargetID: meetupFocusTargetID
                    ) { mapsPath.append($0) }
                        .navigationDestination(for: SnootsRoute.self) { route in
                            switch route {
                            case .emergency:
                                CareView(store: store, language: language)
                            case .place(let placeID):
                                if let place = store.place(id: placeID) {
                                    PlaceDetailView(place: place, store: store, language: language)
                                }
                        case .match, .matchSetup, .chat, .chatList, .meetupChatList, .meetupChat, .meetupParticipants, .icebreaker, .safety, .dashboard, .groupDashboard, .groupSettings, .memories:
                                EmptyView()
                            }
                        }
                }
                    .tint(SnootsPalette.navigationActive)
                    .tabItem { AppTab.maps.icon(isSelected: selectedTab == .maps).accessibilityLabel(language.text("Nearby", "附近")) }
                    .tag(AppTab.maps)
            }

            NavigationStack {
                FeedView(
                    store: store,
                    language: language,
                    onMeetupCreated: showMeetups,
                    onOpenChats: {
                        chatPath = []
                        selectedTab = .chats
                    },
                    onOpenMeetupChats: {
                        matchPath = [.meetupChatList]
                        selectedTab = .match
                    },
                    onOpenMatch: { matchPath = []; selectedTab = .match },
                    onOpenMatchForm: { matchPath = [.matchSetup]; selectedTab = .match },
                    onOpenChatRoom: { chatPath = [.chat]; selectedTab = .chats },
                    onOpenDailyTask: { chatPath = [.icebreaker]; selectedTab = .chats }
                )
            }
                .tint(SnootsPalette.navigationActive)
                .tabItem { AppTab.feed.icon(isSelected: selectedTab == .feed).accessibilityLabel(language.text("Home", "首頁")) }
                .tag(AppTab.feed)

            NavigationStack(path: $chatPath) {
                MatchChatListView(candidate: store.activeMatchCandidate, store: store, language: language,
                    onNavigate: { chatPath.append($0) })
                    .navigationDestination(for: SnootsRoute.self) { route in
                        switch route {
                        case .chat:
                            MatchChatRoom(candidate: store.activeMatchCandidate, store: store, language: language,
                                onNavigate: { chatPath.append($0) }, onBackToChatList: { chatPath = [] })
                        case .icebreaker:
                            if store.isMatchVerificationActive {
                                #if DEBUG
                                DailyTaskVerificationView(candidate: store.activeMatchCandidate)
                                #endif
                            } else {
                                DailyIcebreakerTaskView(candidate: store.activeMatchCandidate, store: store, language: language,
                                    onNavigate: { chatPath.append($0) })
                            }
                        case .safety:
                            MeetupSafetyView(candidate: store.activeMatchCandidate, store: store, language: language,
                                onNavigate: { chatPath.append($0) })
                        case .dashboard:
                            OfflineMeetupDashboard(candidate: store.activeMatchCandidate, store: store, language: language)
                        case .meetupChatList, .meetupChat:
                            MeetupHubView()
                        default:
                            ContentUnavailableView("請從聊天室列表開啟對話", systemImage: "bubble.left.and.bubble.right")
                        }
                    }
            }
                .tint(SnootsPalette.navigationActive)
                .tabItem { AppTab.chats.icon(isSelected: selectedTab == .chats).accessibilityLabel("聊天室") }
                .tag(AppTab.chats)

            NavigationStack(path: $profilePath) {
                OwnProfileScreen(store: store)
                    .navigationDestination(for: SnootsRoute.self) { route in
                        switch route {
                        case .place(let placeID):
                            if let place = store.place(id: placeID) {
                                PlaceDetailView(place: place, store: store, language: language)
                            }
                        case .matchSetup:
                            BeforeMatchingView(store: store)
                        case .match, .chat, .chatList, .meetupChatList, .meetupChat, .meetupParticipants, .icebreaker, .safety, .dashboard, .groupDashboard, .groupSettings, .memories, .emergency:
                            EmptyView()
                        }
                    }
            }
                .tint(SnootsPalette.navigationActive)
                .tabItem { AppTab.profile.icon(isSelected: selectedTab == .profile).accessibilityLabel(language.text("Profile", "檔案")) }
                .tag(AppTab.profile)
        }
        .tint(.black)
        .sensoryFeedback(.success, trigger: store.isMatched)
        .onAppear { showMeetupInvitation = meetups.pendingInvitation != nil }
        .onChange(of: meetups.pendingInvitation) { _, code in
            if code != nil { showMeetupInvitation = true }
        }
        .sheet(isPresented: $showMeetupInvitation) {
            NavigationStack {
                MeetupHubView()
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("關閉") { showMeetupInvitation = false } } }
            }
        }
        .onChange(of: selectedTab) { _, tab in
            guard tab == .match, matchPath.isEmpty, !store.matchDetailsCompleted,
                  !store.matchVerificationBypassesSetup else { return }
            matchPath = [.matchSetup]
        }
    }

    private func showMeetups(_ meetupPlaceID: String) {
        meetupFocusTargetID = meetupPlaceID
        selectedNearbyCategory = .meetups
        selectedNearbyRegion = store.place(id: meetupPlaceID)?.region ?? .currentLocation
        meetupFocusRequest += 1
        selectedTab = .maps
    }
}

enum SnootsRoute: Hashable {
    case match
    case matchSetup
    case chat
    case chatList
    case meetupChatList
    case meetupChat
    case meetupParticipants
    case icebreaker
    case safety
    case dashboard
    case groupDashboard
    case groupSettings
    case memories
    case emergency
    case place(String)
}

struct FeedView: View {
    @Environment(SnootsAccountSession.self) private var account
    let store: SnootsStore
    let language: SnootsLanguage
    let onMeetupCreated: (String) -> Void
    let onOpenChats: () -> Void
    let onOpenMeetupChats: () -> Void
    let onOpenMatch: () -> Void
    let onOpenMatchForm: () -> Void
    let onOpenChatRoom: () -> Void
    let onOpenDailyTask: () -> Void
    @State private var likedPostIDs: Set<UUID> = []
    @State private var isShowingMyMeetups = false
    @State private var isShowingPostComposer = false
    #if DEBUG
    @State private var isShowingVerificationCenter = false
    #endif

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                Text("豆花示範區")
                    .font(.snootsSection())
                    .accessibilityAddTraits(.isHeader)
                Text("示範內容，不是封閉測試者的真實貼文。")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
                ForEach(store.socialPosts.filter { $0.owner == "豆花" && !$0.isLocallyCreated }) { post in
                    FeedPostCard(
                        post: post,
                        language: language,
                        isLiked: likedPostIDs.contains(post.id),
                        onToggleLike: { toggle(post.id, in: &likedPostIDs) },
                        onSendComment: { store.addSocialPostComment(to: post.id, text: $0) }
                    )
                }

                Text("最新貼文")
                    .font(.snootsSection())
                    .accessibilityAddTraits(.isHeader)
                if !store.socialPosts.contains(where: \.isLocallyCreated) {
                    ContentUnavailableView(
                        "目前沒有測試貼文",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text(account.usesPreviewAccount
                                          ? "使用右上角「發文」建立本機測試貼文；正式社群尚未串接。"
                                          : "正式社群貼文尚未串接，目前不會顯示其他測試者的貼文。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                }
                ForEach(store.socialPosts.filter(\.isLocallyCreated)) { post in
                    FeedPostCard(
                        post: post,
                        language: language,
                        isLiked: likedPostIDs.contains(post.id),
                        onToggleLike: { toggle(post.id, in: &likedPostIDs) },
                        onSendComment: { store.addSocialPostComment(to: post.id, text: $0) },
                        onDelete: { store.deleteLocalPost(post.id) }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            #if DEBUG
            if account.usesPreviewAccount {
                ToolbarItem(placement: .topBarLeading) {
                    Button { isShowingVerificationCenter = true } label: {
                        Image(systemName: "testtube.2")
                    }
                    .snootsWhiteTopBarActionStyle()
                    .accessibilityLabel("畫面驗證入口")
                }
                .sharedBackgroundVisibility(.hidden)
            }
            #endif
            ToolbarItem(placement: .topBarLeading) {
                Button { isShowingMyMeetups = true } label: {
                    Image(systemName: "calendar")
                }
                .snootsWhiteTopBarActionStyle()
                .accessibilityLabel(language.text("View meetups", "檢視狗聚"))
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { WarmHeartCenter() } label: {
                    Image(systemName: "heart")
                }
                .snootsWhiteTopBarActionStyle()
                .accessibilityLabel(language.text("Community notifications", "社群通知"))
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button { isShowingPostComposer = true } label: {
                    Image(systemName: "plus.square")
                }
                .snootsWhiteTopBarActionStyle()
                .accessibilityLabel("發文")
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .navigationDestination(isPresented: $isShowingMyMeetups) {
            MeetupHubView()
        }
        .sheet(isPresented: $isShowingPostComposer) {
            NavigationStack { LocalPostComposer(store: store) }
        }
        #if DEBUG
        .sheet(isPresented: $isShowingVerificationCenter) {
            DebugVerificationCenter(
                store: store,
                openMatch: onOpenMatch,
                openMatchForm: onOpenMatchForm,
                openChatList: onOpenChats,
                openChatRoom: onOpenChatRoom,
                openDailyTask: onOpenDailyTask,
                openMeetups: { isShowingMyMeetups = true },
                openPostComposer: { isShowingPostComposer = true }
            )
        }
        #endif
    }

    private func toggle(_ id: UUID, in selection: inout Set<UUID>) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

}

private struct NativeTopActionButton: View {
    let symbol: String
    var accessibilityLabel: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 30, height: 30)
        }
        .snootsTopBarActionStyle()
        .accessibilityLabel(accessibilityLabel ?? (symbol == "heart" ? "Activity" : "Messages"))
    }
}

extension View {
    /// Native Liquid Glass is scoped to the action so the navigation title and
    /// status bar keep the screen's normal color scheme.
    func snootsWhiteTopBarActionStyle() -> some View {
        buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .glassEffect(.regular.tint(.black.opacity(0.45)).interactive(), in: Circle())
    }

    /// For header actions outside a navigation bar. Toolbar actions use the
    /// navigation bar's own system appearance, just like the native back button.
    func snootsTopBarActionStyle() -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.regular)
            .frame(minWidth: 44, minHeight: 44)
    }
}

private struct CreateActivityButton: View {
    let language: SnootsLanguage
    let onCreate: () -> Void

    var body: some View {
        if SnootsFeatureVisibility.createMeetup {
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

private struct MeetupCardShowcase: Identifiable {
    let id: String
    let date: Date
    let organizer: String
    let title: String
    let tags: [String]
    let attendeeCount: Int
    let participants: [MeetupParticipant]
    let opensDetails: Bool
}

private struct MyMeetupsView: View {
    let store: SnootsStore
    let language: SnootsLanguage
    let onShowOnMap: (String) -> Void
    let onOpenMeetupChats: () -> Void
    @State private var isShowingCreateMeetup = false
    @State private var isShowingUpcomingMeetup = false

    var body: some View {
        Group {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Text(language.text("Coming up", "即將到來"))
                        .font(.snootsSection())

                    ForEach(showcaseMeetups) { meetup in
                        showcaseMeetupRow(meetup)
                    }

                    if !store.createdMeetups.isEmpty {
                        Text(language.text("Published by you", "你發佈的狗聚"))
                            .font(.snootsSection())
                            .padding(.top, 8)

                        ForEach(store.createdMeetups) { meetup in
                            meetupCard(meetup)
                        }
                    }
                }
                .padding(18)
            }
            .background(SnootsPalette.canvas)
            .navigationTitle(language.text("My meetups", "我的狗聚"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isShowingCreateMeetup = true } label: {
                        Label(language.text("Create a meetup", "發起狗聚"), systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $isShowingUpcomingMeetup) {
            UpcomingMeetupDetailView(
                store: store,
                language: language,
                onOpenMeetupChats: onOpenMeetupChats
            )
        }
        .navigationDestination(isPresented: $isShowingCreateMeetup) {
            CreateMeetupView(store: store, language: language)
        }
    }

    private func showcaseMeetupRow(_ meetup: MeetupCardShowcase) -> some View {
        Group {
            if meetup.opensDetails {
                Button { isShowingUpcomingMeetup = true } label: {
                    upcomingMeetupCard(meetup)
                }
                .buttonStyle(.plain)
                .accessibilityHint(language.text("Open meetup details", "開啟狗聚詳情"))
            } else {
                upcomingMeetupCard(meetup)
            }
        }
        .padding(.leading, 56)
        .overlay(alignment: .leading) {
            meetupDateRail(meetup.date)
                .frame(width: 46)
                .frame(maxHeight: .infinity)
        }
        .padding(.top, 4)
    }

    private func meetupDateRail(_ date: Date) -> some View {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.month, .day], from: date)
        let month = String(format: "%02d", components.month ?? 0)
        let day = String(format: "%02d", components.day ?? 0)

        return VStack(spacing: -2) {
            Text(language.text(month, "\(month)月"))
                .font(.snootsUI(16, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(day)
                .font(.snootsHeading(32))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(SnootsPalette.secondaryText)
        .padding(.vertical, 8)
        .frame(maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text("\(month)/\(day)", "\(month)月\(day)日"))
    }

    private func upcomingMeetupCard(_ meetup: MeetupCardShowcase) -> some View {
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(language.text("Hosted by \(meetup.organizer)", "發起人 \(meetup.organizer)"))
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)

                    Text(meetup.title)
                        .font(.snootsHeading(26))
                        .foregroundStyle(SnootsPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.snootsUI(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(SnootsPalette.navigationActive, in: Circle())
                    .accessibilityHidden(true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(meetup.tags, id: \.self) { tag in
                        meetupTagPill(tag)
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(meetup.tags, id: \.self) { tag in
                        meetupTagPill(tag)
                    }
                }
            }

            Divider()
                .overlay(SnootsPalette.ink.opacity(0.12))

            HStack(spacing: 10) {
                MeetupParticipantAvatarStack(
                    participants: meetup.participants,
                    language: language,
                    showsWhiteOutline: false,
                    avatarSize: 32
                )
                    .frame(width: 112, alignment: .leading)
                Text(language.text("\(meetup.attendeeCount) attending", "等 \(meetup.attendeeCount) 位"))
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SnootsPalette.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(SnootsPalette.navigationActive)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }

    private var showcaseMeetups: [MeetupCardShowcase] {
        let meetup = store.upcomingMeetup
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let secondDate = calendar.date(byAdding: .day, value: 7, to: meetup.startDate) ?? meetup.startDate
        let thirdDate = calendar.date(byAdding: .day, value: 14, to: meetup.startDate) ?? meetup.startDate
        let tags = [
            language.text("General park", "一般公園"),
            language.text("Small dogs", "小型犬"),
            language.text("Medium dogs", "中型犬"),
            language.text("Leash required", "需牽繩")
        ]
        let strollTags = [
            language.text("Forest lawn", "森林草地"),
            language.text("Small dogs", "小型犬"),
            language.text("Slow introductions", "慢慢認識"),
            language.text("Leash required", "需牽繩")
        ]
        let riversideTags = [
            language.text("Riverside park", "河濱公園"),
            language.text("Medium dogs", "中型犬"),
            language.text("Gentle walk", "自在散步"),
            language.text("Leash required", "需牽繩")
        ]
        let strollParticipants = Array(meetup.participants.dropFirst().prefix(4))
        let riversideParticipants = Array(meetup.participants.dropFirst(2))
            + Array(meetup.participants.prefix(2))

        return [
            MeetupCardShowcase(
                id: "upcoming-main",
                date: meetup.startDate,
                organizer: meetup.localizedOrganizerName(language),
                title: meetup.localizedTitle(language),
                tags: tags,
                attendeeCount: 10,
                participants: meetup.participants,
                opensDetails: true
            ),
            MeetupCardShowcase(
                id: "upcoming-lavender",
                date: secondDate,
                organizer: language.text("Aoi", "小葵"),
                title: language.text("Autumn Park Stroll", "秋日草地散步"),
                tags: strollTags,
                attendeeCount: 8,
                participants: strollParticipants,
                opensDetails: false
            ),
            MeetupCardShowcase(
                id: "upcoming-lime",
                date: thirdDate,
                organizer: language.text("A-Fu", "阿福"),
                title: language.text("Weekend Dog Friends", "週末狗友相見歡"),
                tags: riversideTags,
                attendeeCount: 12,
                participants: riversideParticipants,
                opensDetails: false
            )
        ]
    }

    private func meetupTagPill(_ tag: String) -> some View {
        Text(tag)
            .font(.snootsMetadata())
            .foregroundStyle(SnootsPalette.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .overlay {
                Capsule()
                    .strokeBorder(SnootsPalette.ink.opacity(0.28), lineWidth: 0.75)
            }
    }

    private func meetupCard(_ meetup: MeetupDraft) -> some View {
        let activity = store.meetupActivityTypes.first { $0.id == meetup.activityTypeID }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(meetup.title)
                        .font(.snootsUI(21, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(activity?.localizedTitle(language) ?? language.text("Dog meetup", "狗聚"))
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.ink.opacity(0.68))
                }
                Spacer(minLength: 0)
                Text(language.text("Published", "已發佈"))
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(SnootsPalette.lime, in: Capsule())
            }

            VStack(alignment: .leading, spacing: 11) {
                Label(
                    meetup.startDate.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened).locale(language.locale)
                    ),
                    systemImage: "calendar"
                )
                if let url = URL(string: meetup.navigationLink),
                   ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
                    Link(destination: url) {
                        Label(meetup.location, systemImage: "mappin")
                    }
                    .buttonStyle(.plain)
                } else {
                    Label(meetup.location, systemImage: "mappin")
                }
                Label(language.text("Up to \(meetup.attendeeLimit) dogs", "最多 \(meetup.attendeeLimit) 隻狗狗"), systemImage: "pawprint.fill")

                if SnootsFeatureVisibility.nearby,
                   store.place(id: store.meetupPlaceID(for: meetup)) != nil {
                    Button {
                        onShowOnMap(store.meetupPlaceID(for: meetup))
                    } label: {
                        Label(language.text("Show on map", "在地圖查看"), systemImage: "map.fill")
                            .font(.snootsButton(15))
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(SnootsPalette.navigationActive)
                }
            }
            .font(.snootsUI(14))
            .foregroundStyle(SnootsPalette.ink)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SnootsPalette.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(SnootsPalette.navigationActive)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

private struct UpcomingMeetupDetailView: View {
    let store: SnootsStore
    let language: SnootsLanguage
    let onOpenMeetupChats: () -> Void

    private var meetup: UpcomingMeetup { store.upcomingMeetup }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                MeetupHeroInformationCard(meetup: meetup, language: language)

                VStack(alignment: .leading, spacing: 18) {
                    MeetupEventInformationContent(meetup: meetup, language: language)

                    if store.isUpcomingMeetupCheckInOpen {
                        eventDaySection
                    }

                    MeetupPurposeAndSafetyCard(meetup: meetup, store: store, language: language)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .background(SnootsPalette.canvas)
        .ignoresSafeArea(edges: .top)
        .navigationTitle(meetup.localizedTitle(language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MeetupEditView(meetup: meetup, store: store, language: language)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .tint(.white)
                .accessibilityLabel(language.text("Edit meetup", "編輯狗聚"))
            }

            ToolbarSpacer(.fixed, placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenMeetupChats) {
                    SnootsChatIcon()
                }
                .tint(.white)
                .accessibilityLabel(language.text("Open meetup chats", "開啟狗聚聊天室"))
            }
        }
    }

    @ViewBuilder
    private var eventDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(language.text("On-site check-in", "現場簽到區"))
                    .font(.snootsSection())
                Spacer()
                Text(language.text("Open", "已開放"))
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(SnootsPalette.lime, in: Capsule())
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SnootsPalette.ink)
                        .frame(width: 48, height: 48)
                        .background(SnootsPalette.lime, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.text("Phone tap check-in", "手機互碰簽到"))
                            .font(.snootsCardTitle())
                            .foregroundStyle(SnootsPalette.ink)
                        Text(language.text("Check in with nearby dog friends by Bluetooth — no roll call needed.", "活動現場透過藍牙與附近參與者快速簽到，免去人工點名。"))
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.secondaryText)
                            .multilineTextAlignment(.leading)
                    }
                }

                if store.areUpcomingMeetupTasksCompleted {
                    NavigationLink {
                        GroupMeetupDashboard(meetup: meetup, store: store, language: language)
                    } label: {
                        Label(language.text("Enter check-in dashboard", "進入現場簽到儀表板"), systemImage: "arrow.right")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                } else {
                    Label(language.text("Complete all pre-event tasks to unlock", "完成所有行前任務後解鎖簽到"), systemImage: "lock.fill")
                        .font(.snootsButton(16))
                        .foregroundStyle(SnootsPalette.inactive)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(SnootsPalette.canvas, in: RoundedRectangle(cornerRadius: SnootsMetrics.buttonRadius, style: .continuous))
                        .opacity(0.65)
                }
            }
            .padding(16)
            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
            .snootsCardShadow()
        }
    }

}

private struct MeetupHeroInformationCard: View {
    let meetup: UpcomingMeetup
    let language: SnootsLanguage

    private var coverImageName: String {
        "MeetupHeroDogs"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let data = meetup.coverPhotoData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable()
                    } else {
                        Image(coverImageName).resizable()
                    }
                }
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(1.14, anchor: .bottom)
                    .clipped()

                LinearGradient(
                    colors: [SnootsPalette.ink.opacity(0.42), SnootsPalette.ink.opacity(0.08), SnootsPalette.ink.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(language.text("Hosted by \(meetup.organizerName)", "發起人 \(meetup.localizedOrganizerName(language))"))
                        .font(.snootsUI(15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))

                    Text(meetup.localizedTitle(language))
                        .font(.snootsHeading(34).weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 32)
            }
        }
        .frame(height: 430)
    }
}

private struct MeetupEventInformationContent: View {
    let meetup: UpcomingMeetup
    let language: SnootsLanguage
    @Environment(\.openURL) private var openURL
    @State private var isShowingNavigationOptions = false

    private var appleMapsURL: URL {
        if meetup.traditionalChineseLocation == "大安森林公園" {
            return URL(string: "https://maps.apple.com/?daddr=25.0296587%2C121.5362867&dirflg=w")!
        }
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "daddr", value: meetup.localizedLocation(language)), URLQueryItem(name: "dirflg", value: "w")]
        return components.url!
    }

    private var googleMapsURL: URL {
        if let url = URL(string: meetup.navigationLink), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
            return url
        }
        var components = URLComponents(string: "https://www.google.com/maps/dir/")!
        components.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "destination", value: meetup.localizedLocation(language))]
        return components.url!
    }

    private var dateText: String {
        meetup.startDate.formatted(
            Date.FormatStyle(date: .numeric, time: .omitted).locale(language.locale)
        )
    }

    private var startTimeText: String {
        meetup.startDate.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened).locale(language.locale)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    metadataValue(startTimeText, symbol: "clock")
                    metadataValue(dateText, symbol: "calendar")
                }

                VStack(alignment: .leading, spacing: 14) {
                    metadataValue(startTimeText, symbol: "clock")
                    metadataValue(dateText, symbol: "calendar")
                }
            }

            Button {
                isShowingNavigationOptions = true
            } label: {
                metadataValue("\(meetup.localizedLocation(language))（點我導航）", symbol: "mappin")
            }
            .buttonStyle(.plain)
            .accessibilityHint(language.text("Choose Apple Maps or Google Maps for directions", "選擇 Apple 地圖或 Google 地圖導航"))

            NavigationLink {
                MeetupParticipantListView(meetup: meetup, language: language)
            } label: {
                HStack(spacing: 10) {
                    MeetupParticipantAvatarStack(
                        participants: meetup.participants,
                        language: language,
                        showsWhiteOutline: false,
                        avatarSize: 34
                    )
                    Text(language.text("\(meetup.readyParticipantCount) participants", "\(meetup.readyParticipantCount) 位參加者"))
                        .font(.snootsUI(16, weight: .medium))
                        .foregroundStyle(SnootsPalette.secondaryText)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.snootsUI(14, weight: .semibold))
                        .foregroundStyle(SnootsPalette.inactive)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(language.text("View participant list", "查看參與名單與防範標籤"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .confirmationDialog(
            language.text("Choose a navigation app", "選擇導航 App"),
            isPresented: $isShowingNavigationOptions,
            titleVisibility: .visible
        ) {
            Button(language.text("Apple Maps", "Apple 地圖")) {
                openURL(appleMapsURL)
            }
            Button(language.text("Google Maps", "Google 地圖")) {
                openURL(googleMapsURL)
            }
            Button(language.text("Cancel", "取消"), role: .cancel) { }
        } message: {
            Text("前往\(meetup.localizedLocation(language))")
        }
    }

    private func metadataValue(_ text: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            metadataIcon(symbol)
                .frame(width: 20, height: 20)
            Text(text)
                .font(.snootsUI(16, weight: .medium))
                .foregroundStyle(SnootsPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    @ViewBuilder
    private func metadataIcon(_ symbol: String) -> some View {
        switch symbol {
        case "clock":
            MeetupClockOutlineIcon(color: SnootsPalette.navigationActive)
        case "calendar":
            MeetupCalendarOutlineIcon(color: SnootsPalette.navigationActive)
        case "mappin":
            MeetupLocationOutlineIcon(color: SnootsPalette.navigationActive)
        default:
            Image(systemName: symbol)
                .font(.snootsUI(16, weight: .regular))
                .foregroundStyle(SnootsPalette.navigationActive)
        }
    }
}

private struct MeetupClockOutlineIcon: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let circle = CGRect(
                x: width * 0.10,
                y: height * 0.10,
                width: width * 0.80,
                height: height * 0.80
            )

            var clock = Path()
            clock.addEllipse(in: circle)
            clock.move(to: CGPoint(x: width * 0.5, y: height * 0.5))
            clock.addLine(to: CGPoint(x: width * 0.5, y: height * 0.25))
            clock.move(to: CGPoint(x: width * 0.5, y: height * 0.5))
            clock.addLine(to: CGPoint(x: width * 0.29, y: height * 0.5))
            context.stroke(
                clock,
                with: .color(color),
                style: StrokeStyle(lineWidth: MeetupMetadataIconStyle.strokeWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}

private struct MeetupLocationOutlineIcon: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            var pin = Path()
            pin.move(to: CGPoint(x: width * 0.5, y: height * 0.94))
            pin.addCurve(
                to: CGPoint(x: width * 0.17, y: height * 0.39),
                control1: CGPoint(x: width * 0.39, y: height * 0.72),
                control2: CGPoint(x: width * 0.17, y: height * 0.57)
            )
            pin.addCurve(
                to: CGPoint(x: width * 0.5, y: height * 0.08),
                control1: CGPoint(x: width * 0.17, y: height * 0.18),
                control2: CGPoint(x: width * 0.31, y: height * 0.08)
            )
            pin.addCurve(
                to: CGPoint(x: width * 0.83, y: height * 0.39),
                control1: CGPoint(x: width * 0.69, y: height * 0.08),
                control2: CGPoint(x: width * 0.83, y: height * 0.18)
            )
            pin.addCurve(
                to: CGPoint(x: width * 0.5, y: height * 0.94),
                control1: CGPoint(x: width * 0.83, y: height * 0.57),
                control2: CGPoint(x: width * 0.61, y: height * 0.72)
            )

            let center = CGRect(
                x: width * 0.39,
                y: height * 0.25,
                width: width * 0.22,
                height: height * 0.22
            )
            pin.addEllipse(in: center)
            context.stroke(
                pin,
                with: .color(color),
                style: StrokeStyle(lineWidth: MeetupMetadataIconStyle.strokeWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}

private struct MeetupCalendarOutlineIcon: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let frame = CGRect(
                x: width * 0.11,
                y: height * 0.15,
                width: width * 0.78,
                height: height * 0.76
            )

            var outline = Path()
            outline.addRoundedRect(in: frame, cornerSize: CGSize(width: 3, height: 3))
            outline.move(to: CGPoint(x: width * 0.13, y: height * 0.39))
            outline.addLine(to: CGPoint(x: width * 0.87, y: height * 0.39))
            outline.move(to: CGPoint(x: width * 0.32, y: height * 0.08))
            outline.addLine(to: CGPoint(x: width * 0.32, y: height * 0.28))
            outline.move(to: CGPoint(x: width * 0.68, y: height * 0.08))
            outline.addLine(to: CGPoint(x: width * 0.68, y: height * 0.28))
            context.stroke(
                outline,
                with: .color(color),
                style: StrokeStyle(lineWidth: MeetupMetadataIconStyle.strokeWidth, lineCap: .round, lineJoin: .round)
            )

            var dateMarks = Path()
            for row in 0..<2 {
                for column in 0..<3 {
                    let x = width * (0.30 + CGFloat(column) * 0.20)
                    let y = height * (0.55 + CGFloat(row) * 0.19)
                    dateMarks.addEllipse(in: CGRect(x: x, y: y, width: 1.4, height: 1.4))
                }
            }
            context.fill(dateMarks, with: .color(color))
        }
        .accessibilityHidden(true)
    }
}

private enum MeetupMetadataIconStyle {
    static let strokeWidth: CGFloat = 2.3
}

private struct MeetupPurposeAndSafetyCard: View {
    let meetup: UpcomingMeetup
    let store: SnootsStore
    let language: SnootsLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(language.text("About the meetup", "聚會主旨"))
                .font(.snootsSection())
                .foregroundStyle(SnootsPalette.ink)

            Text(meetup.localizedHostNote(language))
                .font(.snootsBody())
                .foregroundStyle(SnootsPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Array(meetup.safetyPrinciples.enumerated()), id: \.offset) { _, principle in
                        SafetyPrincipleChip(title: principle)
                    }
                }
            }

            Text(meetup.preparationNotes)
                .font(.snootsMetadata())
                .foregroundStyle(SnootsPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button {
                store.toggleUpcomingMeetupGuidanceAcknowledgement()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(SnootsPalette.navigationActive)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(language.text("Read the meetup purpose & safety rules", "閱讀本次活動主旨與安全守則"))
                            .font(.snootsBody())
                            .foregroundStyle(SnootsPalette.ink)
                            .multilineTextAlignment(.leading)
                        Text(language.text("Confirm the notes to prepare before the meetup.", "請於聚會前確認注意事項內容。"))
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.secondaryText)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: store.hasAcknowledgedUpcomingMeetupGuidance ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(store.hasAcknowledgedUpcomingMeetupGuidance ? SnootsPalette.navigationActive : SnootsPalette.inactive)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(store.hasAcknowledgedUpcomingMeetupGuidance ? .isSelected : [])
        }
    }
}

private struct SafetyPrincipleChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.snootsChip())
            .foregroundStyle(SnootsPalette.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(SnootsPalette.surface.opacity(0.78), in: Capsule())
    }
}

private struct MeetupParticipantListView: View {
    let meetup: UpcomingMeetup
    let language: SnootsLanguage

    var body: some View {
        List {
            Section {
                ForEach(meetup.participants) { participant in
                    NavigationLink {
                        MeetupParticipantProfileView(participant: participant, language: language)
                    } label: {
                        HStack(spacing: 12) {
                            Image(participant.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 6) {
                                Text(participant.localizedName(language))
                                    .font(.snootsCardTitle())
                                Text("\(participant.breed) · \(participant.age) · \(participant.size)")
                                    .font(.snootsMetadata())
                                    .foregroundStyle(SnootsPalette.secondaryText)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(participant.safetyTagIDs, id: \.self) { id in
                                            Text(localizedSafetyTag(id))
                                                .font(.snootsChip())
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(SnootsPalette.primaryTint, in: Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .foregroundStyle(SnootsPalette.ink)
                }
            } header: {
                Text(language.text("Participants", "參與名單"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(SnootsPalette.canvas)
        .navigationTitle(language.text("Participants", "參與名單"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func localizedSafetyTag(_ id: String) -> String {
        switch id {
        case "slow-intro": language.text("Slow introductions", "慢慢認識")
        case "leash": language.text("Leash on", "全程牽繩")
        case "adult": language.text("Adult dogs", "偏好成犬")
        default: id
        }
    }
}

private struct MeetupParticipantProfileView: View {
    let participant: MeetupParticipant
    let language: SnootsLanguage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 10) {
                    Image(participant.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 132, height: 132)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(SnootsPalette.primaryTint, lineWidth: 5))
                    Text(participant.localizedName(language))
                        .font(.snootsHeading(28))
                    Text("\(participant.breed) · \(participant.age) · \(participant.size)")
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                profileSection("自我介紹") {
                    Text(participant.summary)
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.ink)
                }

                profileSection("互動與社交界線") {
                    HStack(spacing: 8) {
                        ForEach(participant.safetyTagIDs, id: \.self) { tagID in
                            Text(localizedSafetyTag(tagID))
                                .font(.snootsChip())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(SnootsPalette.primaryTint, in: Capsule())
                        }
                    }
                }

                profileSection("健康摘要") {
                    Label(participant.healthSummary, systemImage: "checkmark.shield.fill")
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.navigationActive)
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle("狗狗檔案")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func profileSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.snootsSection())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
    }

    private func localizedSafetyTag(_ id: String) -> String {
        switch id {
        case "slow-intro": "慢慢認識"
        case "leash": "全程牽繩"
        case "adult": "偏好成犬"
        default: id
        }
    }
}

private struct MeetupRulesSheet: View {
    let store: SnootsStore
    let task: MeetupPreparationTask?
    let language: SnootsLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label(language.text("Meetup rules", "聚會守則"), systemImage: "checkmark.shield.fill")
                    .font(.snootsHeading(22))

                VStack(alignment: .leading, spacing: 12) {
                    Label(language.text("Let dogs choose their own pace.", "不強迫狗狗互動，讓牠們自己決定靠近的步調。"), systemImage: "hand.raised.fill")
                    Label(language.text("Please don’t feed another dog.", "未經飼主同意，請勿餵食其他狗狗。"), systemImage: "fork.knife")
                    Label(language.text("Keep a leash on throughout the meetup.", "活動全程使用胸背帶與牽繩。"), systemImage: "link")
                }
                .font(.snootsBody())
                .foregroundStyle(SnootsPalette.ink)

                Spacer()

                Button(language.text("I understand and agree", "我已閱讀並同意")) {
                    if let task, !store.isUpcomingMeetupTaskCompleted(task) {
                        store.toggleUpcomingMeetupTask(task)
                    }
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
            }
            .padding(20)
            .background(SnootsPalette.canvas)
            .navigationTitle(language.text("Safety first", "安全第一"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MeetupBluetoothCheckInView: View {
    let meetup: UpcomingMeetup
    let language: SnootsLanguage
    @State private var isSearchingForNearbyPhones = false
    @State private var isExitConfirmationPresented = false
    @State private var hasLeftMeetup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(SnootsPalette.ink)
                        .frame(width: 100, height: 100)
                        .background(SnootsPalette.lime, in: Circle())

                    Text(language.text("Phone tap check-in", "手機互碰簽到"))
                        .font(.snootsHeading(24))

                    Text(
                        language.text(
                            "At the meetup, bring your phone close to another participant’s phone to check in together.",
                            "抵達狗聚後，將手機靠近其他參與者的手機，即可一起完成簽到。"
                        )
                    )
                    .font(.snootsBody())
                    .foregroundStyle(SnootsPalette.secondaryText)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 34)

                VStack(alignment: .leading, spacing: 10) {
                    Label(meetup.localizedTitle(language), systemImage: "pawprint.fill")
                    Label(meetup.localizedLocation(language), systemImage: "mappin")
                }
                .font(.snootsUI(15, weight: .medium))
                .foregroundStyle(SnootsPalette.ink)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        isSearchingForNearbyPhones
                            ? language.text("Looking for nearby phones", "正在尋找附近的手機")
                            : language.text("Ready when you are", "準備好即可開始"),
                        systemImage: isSearchingForNearbyPhones ? "wave.3.right.circle.fill" : "bluetooth"
                    )
                    .font(.snootsCardTitle())
                    .foregroundStyle(SnootsPalette.ink)

                    Text(
                        language.text(
                            "Bluetooth must be enabled at the venue before a tap check-in can begin.",
                            "請在活動地點開啟藍牙，再開始進行手機互碰簽到。"
                        )
                    )
                    .font(.snootsBody())
                    .foregroundStyle(SnootsPalette.secondaryText)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                Button {
                    isSearchingForNearbyPhones.toggle()
                } label: {
                    Label(
                        isSearchingForNearbyPhones
                            ? language.text("Stop check-in", "停止尋找")
                            : language.text("Start nearby check-in", "開始附近簽到"),
                        systemImage: isSearchingForNearbyPhones ? "stop.fill" : "dot.radiowaves.left.and.right"
                    )
                }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))

                VStack(alignment: .leading, spacing: 12) {
                    Text(language.text("Nearby member status", "現場成員狀態"))
                        .font(.snootsSection())

                    VStack(spacing: 0) {
                        ForEach(Array(meetup.participants.prefix(5).enumerated()), id: \.element.id) { index, participant in
                            HStack(spacing: 12) {
                                Image(participant.imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())

                                Text(participant.localizedName(language))
                                    .font(.snootsBody())
                                    .foregroundStyle(SnootsPalette.ink)

                                Spacer()

                                Label(
                                    index < 2 ? language.text("Checked in", "已簽到") : language.text("On the way", "前往中"),
                                    systemImage: index < 2 ? "checkmark.circle.fill" : "clock"
                                )
                                .font(.snootsMetadata())
                                .foregroundStyle(index < 2 ? SnootsPalette.navigationActive : SnootsPalette.secondaryText)
                            }
                            .padding(14)

                            if index < meetup.participants.prefix(5).count - 1 {
                                Divider().padding(.leading, 66)
                            }
                        }
                    }
                    .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                }

                if hasLeftMeetup {
                    Label(language.text("You have left the meetup. The host has been notified.", "你已離開活動，發起人已收到通知。"), systemImage: "checkmark.circle.fill")
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                } else {
                    Button(language.text("Leave meetup safely", "安全離開活動"), role: .destructive) {
                        isExitConfirmationPresented = true
                    }
                    .font(.snootsButton(16))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.buttonRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: SnootsMetrics.buttonRadius, style: .continuous)
                            .stroke(SnootsPalette.divider, lineWidth: 1)
                    }
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle(language.text("Check-in dashboard", "現場簽到儀表板"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            language.text("Leave this meetup?", "要離開這場狗聚嗎？"),
            isPresented: $isExitConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(language.text("Leave meetup", "確認離開"), role: .destructive) {
                hasLeftMeetup = true
                isSearchingForNearbyPhones = false
            }
            Button(language.text("Stay", "繼續參加"), role: .cancel) {}
        } message: {
            Text(language.text("The host will be notified so the group can stay coordinated.", "系統會通知發起人，讓現場安排維持清楚。"))
        }
    }
}

private struct MeetupParticipantAvatarStack: View {
    let participants: [MeetupParticipant]
    let language: SnootsLanguage
    var showsWhiteOutline = true
    var avatarSize: CGFloat = 34

    var body: some View {
        HStack(spacing: avatarSize * -0.26) {
            ForEach(Array(participants.prefix(4))) { participant in
                Image(participant.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .overlay {
                        if showsWhiteOutline {
                            Circle().stroke(SnootsPalette.surface, lineWidth: 2)
                        }
                    }
                    .accessibilityLabel(participant.localizedName(language))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct PlaydatesView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let store: SnootsStore
    let language: SnootsLanguage
    let onNavigate: (SnootsRoute) -> Void
    @State private var selectedCandidateIndex = 0
    @State private var selectedPhotoIndex = 0
    @State private var demoChoices: [Int: DemoChoice] = [:]
    @State private var showMutualMatchPrompt = false

    private enum DemoChoice { case skipped, interested }
    private var demoCandidates: [PlaydateCandidate] { store.demoPlaydateCandidates }
    private var candidate: PlaydateCandidate { demoCandidates[selectedCandidateIndex] }
    private var photoNames: [String] {
        candidate.photoNames.isEmpty ? [candidate.imageName] : candidate.photoNames
    }

    var body: some View {
        Group {
            if store.matchVerificationScenario == .loading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("模擬：正在載入候選")
                    Text("返回首頁的畫面驗證入口可切換情境。")
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
                .padding(24)
            } else if store.matchVerificationScenario == .empty {
                emptyState("目前沒有合適候選", symbol: "pawprint", detail: "模擬空狀態：稍後再回來看看，或調整配對偏好。")
            } else if store.matchVerificationScenario == .failure {
                VStack(spacing: 20) {
                    emptyState("候選載入失敗", symbol: "wifi.exclamationmark", detail: "模擬連線失敗，請檢查網路後重試。")
                    Button("重試載入") { store.matchVerificationScenario = .cards }
                        .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                }
                .padding(24)
            } else if !store.matchDetailsCompleted && !store.matchVerificationBypassesSetup {
                VStack(spacing: 20) {
                    ContentUnavailableView(
                        "先完成配對資料",
                        systemImage: "slider.horizontal.3",
                        description: Text("填寫活動力、見面偏好與健康公開設定後，即可查看候選卡。")
                    )
                    Button("填寫配對資料") { onNavigate(.matchSetup) }
                        .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                }
                .padding(24)
            } else if store.isMatchBlocked {
                emptyState("已封鎖\(store.activeMatchCandidate.name)", symbol: "hand.raised.fill", detail: "可在「檔案 > 設定 > 封鎖名單」解除封鎖。")
            } else if store.isMatchCancelled {
                emptyState("配對已取消", symbol: "person.2.slash", detail: "聊天室已從配對列表中移除。")
            } else if store.isMatched {
                VStack(spacing: 18) {
                    MatchedBanner(candidate: store.activeMatchCandidate, language: language)
                    Button("現在進入聊天室") { onNavigate(.chat) }
                        .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                }
                .padding(24)
            } else if demoChoices.count == demoCandidates.count {
                VStack(spacing: 20) {
                    emptyState(
                        "已看完示範候選",
                        symbol: "pawprint",
                        detail: "已查看全部 \(demoCandidates.count) 位示範候選。正式候選與互選功能尚未串接，操作不會傳送給對方。Debug 模擬對方互選請由首頁畫面驗證入口操作。"
                    )
                    Button("重新查看示範卡片") { resetDemoCards() }
                        .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                }
                .padding(24)
            } else {
                candidateCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { syncVerificationCandidate() }
        .onChange(of: store.matchVerificationCandidateIndex) { _, index in
            if index == nil { demoChoices.removeAll() }
            syncVerificationCandidate()
        }
        .onChange(of: store.isMatched) { _, matched in
            guard matched else { return }
            store.createMatchChat()
            showMutualMatchPrompt = true
        }
        .alert("與\(store.activeMatchCandidate.name)配對成功！", isPresented: $showMutualMatchPrompt) {
            Button("現在進入聊天室") { onNavigate(.chat) }
            Button("稍後", role: .cancel) {}
        } message: {
            Text("雙方都選擇想認識，聊天室已建立。稍後也能在聊天室列表找到新配對。")
        }
    }

    private var candidateCard: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    MatchPhotoGallery(photoNames: photoNames, selectedIndex: $selectedPhotoIndex)
                        .frame(height: min(max(geometry.size.height * 0.47, 240), 390))
                        .overlay(alignment: .topLeading) {
                            Text("示範候選")
                                .font(.snootsUI(13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(.black.opacity(0.68), in: Capsule())
                                .padding(18)
                        }
                        .overlay(alignment: .bottom) {
                            if photoNames.count > 1 {
                                HStack(spacing: 5) {
                                    ForEach(photoNames.indices, id: \.self) { index in
                                        Capsule()
                                            .fill(index == selectedPhotoIndex ? .white : .white.opacity(0.48))
                                            .frame(height: 4)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                                .accessibilityHidden(true)
                                .allowsHitTesting(false)
                            }
                        }

                    candidateNavigation

                    matchPhotoInfo
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SnootsPalette.surface)
                }
            }
            .id(selectedCandidateIndex)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    Text(store.isMatchVerificationActive ? "模擬互選：不會傳送給真實使用者" : "示範卡片，操作不會傳送給對方")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) { matchActionButtons }
                    } else {
                        HStack(spacing: 12) { matchActionButtons }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
            }
        }
    }

    private var candidateNavigation: some View {
        HStack(spacing: 8) {
            Button {
                showCandidate(at: selectedCandidateIndex - 1)
            } label: {
                Label("上一位", systemImage: "chevron.left")
            }
            .disabled(selectedCandidateIndex == 0)

            Spacer(minLength: 4)

            Text("候選 \(selectedCandidateIndex + 1) / \(demoCandidates.count)")
                .foregroundStyle(SnootsPalette.secondaryText)

            Spacer(minLength: 4)

            Button {
                showCandidate(at: selectedCandidateIndex + 1)
            } label: {
                Label("下一位", systemImage: "chevron.right")
            }
            .disabled(selectedCandidateIndex == demoCandidates.count - 1)
        }
        .font(.snootsUI(14, weight: .semibold))
        .buttonStyle(.borderless)
        .padding(.horizontal, 20)
        .frame(minHeight: 56)
        .background(SnootsPalette.surface)
    }

    @ViewBuilder private var matchActionButtons: some View {
        Button("先略過") { recordDemoChoice(.skipped) }
            .buttonStyle(SecondaryButtonStyle())
        Button("想認識") { recordDemoChoice(.interested) }
            .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
    }

    private func showCandidate(at index: Int) {
        guard demoCandidates.indices.contains(index) else { return }
        selectedPhotoIndex = 0
        selectedCandidateIndex = index
        #if DEBUG
        if store.isMatchVerificationActive && store.matchVerificationCandidateIndex != index {
            store.beginMatchVerification(candidateIndex: index)
        }
        #endif
    }

    private func recordDemoChoice(_ choice: DemoChoice) {
        #if DEBUG
        if store.isMatchVerificationActive {
            if choice == .interested {
                if store.matchVerificationCandidateIndex != selectedCandidateIndex {
                    store.beginMatchVerification(candidateIndex: selectedCandidateIndex)
                }
                store.recordMatchVerificationInterest(fromSelf: true)
            }
            demoChoices[selectedCandidateIndex] = choice
            if let nextIndex = demoCandidates.indices.first(where: { demoChoices[$0] == nil }) {
                selectedCandidateIndex = nextIndex
                selectedPhotoIndex = 0
            }
            return
        }
        #endif
        demoChoices[selectedCandidateIndex] = choice
        if let nextIndex = demoCandidates.indices.first(where: { demoChoices[$0] == nil }) {
            showCandidate(at: nextIndex)
        }
    }

    private func resetDemoCards() {
        demoChoices.removeAll()
        #if DEBUG
        if store.isMatchVerificationActive { store.beginMatchVerification(candidateIndex: 0) }
        #endif
        showCandidate(at: 0)
    }

    private func syncVerificationCandidate() {
        guard let index = store.matchVerificationCandidateIndex,
              demoCandidates.indices.contains(index) else { return }
        selectedCandidateIndex = index
        selectedPhotoIndex = 0
    }

    private var matchPhotoInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(candidate.name)
                    .font(.snootsScreenTitle())
                    .foregroundStyle(SnootsPalette.ink)
                Spacer(minLength: 4)
                Text(candidate.distance.replacingOccurrences(of: " km away", with: " 公里"))
                    .font(.snootsUI(14, weight: .medium))
                    .foregroundStyle(SnootsPalette.secondaryText)
                    .multilineTextAlignment(.trailing)
            }

            Text("\(candidate.breed)・\(candidate.sex)（\(candidate.isNeutered ? "已絕育" : "未絕育")）")
                .font(.snootsBody())
                .foregroundStyle(SnootsPalette.ink)

            Divider()

            matchInfoDetailRow("遇見陌生狗", value: candidate.strangerDogReaction, symbol: "pawprint")
            matchInfoDetailRow("活動力", value: candidate.energyLevel.isEmpty ? "活動量待確認" : candidate.energyLevel, symbol: "figure.walk")
            if !candidate.meetingEnvironments.isEmpty {
                matchInfoDetailRow("偏好見面環境", value: candidate.meetingEnvironments.joined(separator: "・"), symbol: "leaf")
            }

            if !candidate.publicHealthLabels.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("公開健康摘要")
                        .font(.snootsUI(14, weight: .medium))
                        .foregroundStyle(SnootsPalette.secondaryText)
                    ForEach(candidate.publicHealthLabels, id: \.self) { label in
                        matchHealthLabel(label)
                    }
                    Text("由飼主自行確認，非平台文件查驗")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
            }

            if !candidate.intro.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("飼主寄語")
                        .font(.snootsUI(14, weight: .medium))
                        .foregroundStyle(SnootsPalette.secondaryText)
                    Text(candidate.intro)
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func matchInfoDetailRow(
        _ label: String,
        value: String,
        symbol: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.snootsUI(16, weight: .semibold))
                .foregroundStyle(SnootsPalette.navigationActive)
                .frame(width: 22)
            Text(label)
                .font(.snootsUI(14, weight: .medium))
                .foregroundStyle(SnootsPalette.secondaryText)
                .frame(width: 112, alignment: .leading)
            Text(value)
                .font(.snootsBody())
                .foregroundStyle(SnootsPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func matchHealthLabel(_ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(SnootsPalette.navigationActive)
            Text(title)
                .foregroundStyle(SnootsPalette.ink)
        }
        .font(.snootsUI(14, weight: .medium))
    }

    private func emptyState(_ title: String, symbol: String, detail: String) -> some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
            .padding(24)
    }
}

private struct MatchPhotoGallery: View {
    let photoNames: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(photoNames[selectedIndex])
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .id(selectedIndex)
                    .transition(.opacity)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        changePhoto(by: location.x < geometry.size.width / 2 ? -1 : 1)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedIndex)
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 45 else { return }
                    changePhoto(by: value.translation.width > 0 ? -1 : 1)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("配對狗狗照片第 \(selectedIndex + 1) 張，共 \(photoNames.count) 張")
        .accessibilityHint(photoNames.count > 1
            ? "點擊或左右滑動切換照片。配對選擇請使用卡片下方按鈕。"
            : "只有一張照片。請使用上一位或下一位切換候選。")
        .accessibilityAction(named: "下一張") { changePhoto(by: 1) }
        .accessibilityAction(named: "上一張") { changePhoto(by: -1) }
    }

    private func changePhoto(by offset: Int) {
        guard !photoNames.isEmpty else { return }
        withAnimation {
            selectedIndex = (selectedIndex + offset + photoNames.count) % photoNames.count
        }
    }
}

private struct MatchDetailSheet: View {
    let candidate: PlaydateCandidate
    let language: SnootsLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("基本資料") {
                    LabeledContent("品種／體型", value: "\(candidate.breed)／\(candidate.size)")
                    LabeledContent("性別／絕育", value: candidate.isNeutered ? "\(candidate.sex)／已絕育" : "\(candidate.sex)／未絕育")
                    LabeledContent("陌生狗互動反應", value: candidate.strangerDogReaction)
                }
                Section("活動力與見面環境") {
                    LabeledContent("活動力", value: candidate.energyLevel.isEmpty ? "活動量待確認" : candidate.energyLevel)
                    ForEach(candidate.meetingEnvironments, id: \.self) { environment in
                        Label(environment, systemImage: "mappin.and.ellipse")
                    }
                }
                if !candidate.publicHealthLabels.isEmpty {
                    Section("公開健康摘要") {
                        ForEach(candidate.publicHealthLabels, id: \.self) { label in
                            Label(label, systemImage: "checkmark.circle")
                        }
                        Text("由飼主自行確認，非平台文件查驗")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("\(candidate.name) 的詳細資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(language.text("Done", "完成")) { dismiss() }
                }
            }
        }
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
            Text(language.text("You both chose to get acquainted. Start with a conversation and decide what feels comfortable together.", "雙方都選擇想認識。可以先聊天，再一起決定舒服的見面方式。"))
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
    let meetupFocusTargetID: String?
    let onNavigate: (SnootsRoute) -> Void
    @State private var selectedFilterIDs: Set<String> = []
    @State private var selectedPlaceID: String?
    @State private var resultsPanelDetent: NearbyResultsDetent = .compact
    @State private var hasInitializedNearby = false
    @State private var handledMeetupFocusRequest = 0

    private var visiblePlaces: [Place] {
        let candidates: [Place]
        if selectedCategory == .meetups {
            candidates = store.allPlaces.filter { $0.nearbyCategory == .meetups }
        } else if store.mapPlaces.dataSource == .supabase {
            candidates = store.mapPlaces.places.compactMap { $0.asNearbyPlace() }
        } else {
            candidates = store.allPlaces
        }

        return candidates.filter { place in
            (selectedCategory.map { place.nearbyCategory == $0 } ?? true)
                && selectedRegion.matches(place)
                && localMeetupMatches(place)
        }
    }

    private var availableFilterOptions: [MapFilterOption] {
        guard let category = selectedCategory?.databaseCategory else { return [] }
        return store.mapPlaces.filterOptions
            .filter { $0.category == category }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    private var remoteQuery: NearbyRemoteQuery {
        let center = selectedRegion.mapRegion.center
        return NearbyRemoteQuery(
            latitude: center.latitude,
            longitude: center.longitude,
            category: selectedCategory?.databaseCategory,
            filterIDs: selectedFilterIDs.sorted()
        )
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
        language.text("Filtered results", "篩選結果")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Text(language.text("What’s nearby?", "附近有什麼"))
                        .font(.snootsScreenTitle())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    NativeTopActionButton(
                        symbol: "cross.case.fill",
                        accessibilityLabel: language.text("Find emergency care", "尋找緊急醫療"),
                        action: { onNavigate(.emergency) }
                    )
                }

                NearbyCategorySegmentedControl(selection: $selectedCategory, language: language)
                    .frame(height: NearbyCategorySegmentedControl.controlHeight)

                NearbySubcategoryStrip(
                    region: $selectedRegion,
                    options: availableFilterOptions,
                    selections: $selectedFilterIDs,
                    language: language
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
                        language: language
                    )
                    .frame(height: panelHeight)
                }
            }
        }
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.visible, for: .tabBar)
        .onAppear {
            handleMeetupFocusIfNeeded()
            guard !hasInitializedNearby else { return }
            hasInitializedNearby = true
            selectedFilterIDs = []
        }
        .onChange(of: selectedCategory) { _, _ in
            selectedFilterIDs = []
            resetResults()
        }
        .onChange(of: selectedRegion) { _, _ in resetResults() }
        .onChange(of: selectedFilterIDs) { _, _ in resetResults(keepPanelPosition: true) }
        .onChange(of: meetupFocusRequest) { _, _ in handleMeetupFocusIfNeeded() }
        .task(id: remoteQuery) {
            await store.mapPlaces.refresh(
                latitude: remoteQuery.latitude,
                longitude: remoteQuery.longitude,
                category: remoteQuery.category,
                filterIDs: Set(remoteQuery.filterIDs)
            )
        }
    }

    private func handleMeetupFocusIfNeeded() {
        guard handledMeetupFocusRequest != meetupFocusRequest else { return }
        handledMeetupFocusRequest = meetupFocusRequest
        selectedFilterIDs = []
        resetResults()
        let targetID = meetupFocusTargetID
        Task { @MainActor in
            await Task.yield()
            selectedPlaceID = targetID
        }
    }

    private func resetResults(keepPanelPosition: Bool = false) {
        selectedPlaceID = nil
        if !keepPanelPosition {
            resultsPanelDetent = .compact
        }
    }

    private func localMeetupMatches(_ place: Place) -> Bool {
        guard place.nearbyCategory == .meetups else { return true }
        return selectedFilterIDs.allSatisfy { filterID in
            switch filterID {
            case "meetup.leashed_group_walk": place.category == "Leashed group walk"
            case "meetup.indoor": place.category == "Indoor dog meetup"
            default: true
            }
        }
    }
}

private struct NearbyRemoteQuery: Hashable {
    let latitude: Double
    let longitude: Double
    let category: MapPlace.Category?
    let filterIDs: [String]
}

enum NearbyCategory: CaseIterable, Identifiable, Hashable {
    case meetups, dining, parks, vets

    var id: Self { self }
    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .meetups: language.text("Dog meetups", "狗聚")
        case .dining: language.text("Dining", "用餐")
        case .parks: language.text("Parks", "公園")
        case .vets: language.text("Veterinary care", "獸醫院")
        }
    }

    var databaseCategory: MapPlace.Category {
        switch self {
        case .meetups: .meetup
        case .dining: .restaurant
        case .parks: .park
        case .vets: .hospital
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

private struct NearbyCategorySegmentedControl: UIViewRepresentable {
    static let controlHeight: CGFloat = 54

    @Binding var selection: NearbyCategory?
    let language: SnootsLanguage

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = TallSegmentedControl(items: NearbyCategory.allCases.map { $0.title(language) })
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: categoryFont]
        control.setTitleTextAttributes(titleAttributes, for: .normal)
        control.setTitleTextAttributes(titleAttributes, for: .selected)
        control.addTarget(context.coordinator, action: #selector(Coordinator.recordSelectionBeforeTouch(_:)), for: .touchDown)
        control.addTarget(context.coordinator, action: #selector(Coordinator.selectionChanged(_:)), for: .valueChanged)
        control.addTarget(context.coordinator, action: #selector(Coordinator.clearRepeatedSelection(_:)), for: .touchUpInside)
        control.accessibilityLabel = language.text("Nearby category", "附近分類")
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        context.coordinator.parent = self
        for (index, category) in NearbyCategory.allCases.enumerated() {
            control.setTitle(category.title(language), forSegmentAt: index)
        }
        control.selectedSegmentIndex = selection.flatMap { NearbyCategory.allCases.firstIndex(of: $0) } ?? UISegmentedControl.noSegment
        control.accessibilityLabel = language.text("Nearby category", "附近分類")
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    private var categoryFont: UIFont {
        let baseFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
        let roundedDescriptor = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
        let roundedFont = UIFont(descriptor: roundedDescriptor, size: 20)
        return UIFontMetrics(forTextStyle: .title3).scaledFont(for: roundedFont)
    }

    private final class TallSegmentedControl: UISegmentedControl {
        override var intrinsicContentSize: CGSize {
            var size = super.intrinsicContentSize
            size.height = NearbyCategorySegmentedControl.controlHeight
            return size
        }

        override func sizeThatFits(_ size: CGSize) -> CGSize {
            var fittedSize = super.sizeThatFits(size)
            fittedSize.height = NearbyCategorySegmentedControl.controlHeight
            return fittedSize
        }
    }

    final class Coordinator: NSObject {
        var parent: NearbyCategorySegmentedControl
        private var selectedIndexBeforeTouch = UISegmentedControl.noSegment

        init(parent: NearbyCategorySegmentedControl) {
            self.parent = parent
        }

        @objc func recordSelectionBeforeTouch(_ sender: UISegmentedControl) {
            selectedIndexBeforeTouch = sender.selectedSegmentIndex
        }

        @objc func selectionChanged(_ sender: UISegmentedControl) {
            guard NearbyCategory.allCases.indices.contains(sender.selectedSegmentIndex) else {
                parent.selection = nil
                return
            }
            parent.selection = NearbyCategory.allCases[sender.selectedSegmentIndex]
        }

        @objc func clearRepeatedSelection(_ sender: UISegmentedControl) {
            guard sender.selectedSegmentIndex == selectedIndexBeforeTouch else { return }
            sender.selectedSegmentIndex = UISegmentedControl.noSegment
            parent.selection = nil
        }
    }
}

private struct NearbySubcategoryStrip: View {
    @Binding var region: NearbyRegion
    let options: [MapFilterOption]
    @Binding var selections: Set<String>
    let language: SnootsLanguage

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(NearbyRegion.allCases) { option in
                    Button {
                        region = option
                    } label: {
                        if option == region {
                            Label(option.title(language), systemImage: "checkmark")
                        } else {
                            Text(option.title(language))
                        }
                    }
                }
            } label: {
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
            .fixedSize(horizontal: true, vertical: false)

            if !options.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(options) { option in
                            let isSelected = selections.contains(option.id)
                            Button {
                                if isSelected {
                                    selections.remove(option.id)
                                } else {
                                    selections.insert(option.id)
                                }
                            } label: {
                                Text(option.title(language))
                                    .font(.snootsChip())
                                    .foregroundStyle(SnootsPalette.ink)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 40)
                                    .background(isSelected ? SnootsPalette.primary : SnootsPalette.surface, in: Capsule())
                                    .overlay {
                                        if !isSelected {
                                            Capsule().stroke(SnootsPalette.divider, lineWidth: 1)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .id(options.map(\.id))
                .contentMargins(.horizontal, 1, for: .scrollContent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NearbyMapMarker: Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let placeIDs: [String]
    let isUserCreated: Bool

    init(place: Place, language: SnootsLanguage) {
        id = place.id
        name = place.localizedName(language)
        latitude = place.latitude
        longitude = place.longitude
        placeIDs = [place.id]
        isUserCreated = place.verificationLevel == .hostCreated
    }

    init(cluster: [Place], language: SnootsLanguage) {
        id = "cluster-\(cluster.map(\.id).joined(separator: "-"))"
        name = language.text("\(cluster.count) places", "\(cluster.count) 個地點")
        latitude = cluster.map(\.latitude).reduce(0, +) / Double(cluster.count)
        longitude = cluster.map(\.longitude).reduce(0, +) / Double(cluster.count)
        placeIDs = cluster.map(\.id)
        isUserCreated = cluster.contains { $0.verificationLevel == .hostCreated }
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
                        VStack(spacing: 4) {
                            if marker.isUserCreated && !marker.isCluster {
                                Text(language.text("Your meetup", "你的狗聚"))
                                    .font(.snootsUI(11, weight: .bold))
                                    .foregroundStyle(SnootsPalette.ink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(SnootsPalette.surface, in: Capsule())
                                    .overlay(Capsule().stroke(SnootsPalette.ink, lineWidth: 1))
                            }
                            NearbyMapPin(
                                count: marker.placeIDs.count,
                                isSelected: marker.placeIDs.contains(selectedPlaceID ?? ""),
                                isUserCreated: marker.isUserCreated
                            )
                        }
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
    let isUserCreated: Bool

    var body: some View {
        Group {
            if count == 1 {
                Image(systemName: isUserCreated ? "person.2.fill" : "mappin.circle.fill")
                    .font(.snootsUI(23, weight: .bold))
            } else {
                Text("\(count)")
                    .font(.snootsUI(15, weight: .bold))
            }
        }
            .foregroundStyle(SnootsPalette.ink)
            .frame(width: isSelected ? 54 : 46, height: isSelected ? 54 : 46)
            .background(isSelected || isUserCreated ? SnootsPalette.lime : SnootsPalette.primary, in: Circle())
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
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
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
                    if place.hasLiveStatus {
                        Text(place.isOpenNow ? language.text("Open", "營業中") : language.text("Closed", "休息中"))
                            .foregroundStyle(place.isOpenNow ? SnootsPalette.deepLilac : SnootsPalette.secondaryText)
                    } else {
                        Text(language.text("Hours unavailable", "暫無營業資訊"))
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }
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
        .accessibilityHint(language.text("Highlights this place on the map", "在地圖上標示此地點"))
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
                if place.hasLiveStatus {
                    Text(place.isOpenNow ? language.text("Open now", "營業中") : language.text("Closed", "休息中"))
                        .font(.snootsChip())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(place.isOpenNow ? SnootsPalette.lime : SnootsPalette.canvas, in: Capsule())
                }
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
    @State private var completionPhase: ProfileCompletionPhase?

    private var completedProfileSteps: Int {
        [store.matchDetailsCompleted, store.safetyDetailsCompleted].filter { $0 }.count
    }

    private var profileCompletionProgress: Double {
        Double(completedProfileSteps) / 2.0
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    PhotoTile(
                        imageName: store.pet.imageName,
                        label: store.pet.name,
                        language: language,
                        photoData: store.pet.photoData,
                        showsLabel: false
                    )
                        .frame(width: 104, height: 104)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.pet.name).font(.snootsScreenTitle())
                        Text("\(store.pet.breed)・\(store.pet.age)・\((store.pet.sex == "Male" || store.pet.sex == "公") ? language.text("Male", "公") : language.text("Female", "母"))・\(store.pet.isNeutered ? language.text("Neutered", "已結紮") : language.text("Not neutered", "未結紮"))")
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.ink)
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

                if SnootsFeatureVisibility.feedingInformation {
                    FeedingInformationCard(monitor: store.feedingMonitor, language: language)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(language.text("Profile completion", "檔案完成進度"))
                            .font(.snootsSection())
                        Spacer()
                        Text("\(completedProfileSteps)/2")
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }
                    ProgressView(value: profileCompletionProgress)
                        .tint(SnootsPalette.navigationActive)
                        .scaleEffect(y: 1.5, anchor: .center)
                        .padding(.vertical, 4)
                    ProfilePhaseRow(
                        phase: .matching,
                        isComplete: store.matchDetailsCompleted,
                        language: language
                    ) {
                        onNavigate(.matchSetup)
                    }
                    ProfilePhaseRow(
                        phase: .safety,
                        isComplete: store.safetyDetailsCompleted,
                        language: language
                    ) {
                        completionPhase = .safety
                    }
                }
                .padding(16)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(language.text("\(store.pet.name)’s profile", "\(store.pet.name) 的檔案"))
                    .font(.snootsScreenTitle())
                    .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    EditProfileView(store: store, language: language)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .snootsWhiteTopBarActionStyle()
                .accessibilityLabel(language.text("Edit profile", "編輯檔案"))
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    LanguageSettingsView(store: store, selectedLanguageRawValue: $displayLanguageRawValue)
                } label: {
                    Image(systemName: "gearshape")
                }
                .snootsWhiteTopBarActionStyle()
                .accessibilityLabel(language.text("Settings", "設定"))
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(item: $completionPhase) { phase in
            Group {
                ProfileCompletionSheet(phase: phase, store: store, language: language)
            }
            .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private enum ProfileCompletionPhase: String, Identifiable {
    case matching
    case safety
    var id: String { rawValue }

    func title(_ language: SnootsLanguage) -> String {
        switch self {
        case .matching: language.text("Before matching information", "配對前的資料填寫")
        case .safety: language.text("Before-meeting safety reminders", "見面前的安全提醒")
        }
    }

    func detail(_ language: SnootsLanguage) -> String {
        switch self {
        case .matching: language.text("Set expectations for a more comfortable match.", "補充相處界線，讓配對更準確。")
        case .safety: language.text("Prepare key details for a safer first meeting.", "確認健康與聯絡資訊，讓首次見面更安心。")
        }
    }

    var symbol: String { self == .matching ? "person.2.badge.gearshape" : "checkmark.shield" }
}

private struct ProfilePhaseRow: View {
    let phase: ProfileCompletionPhase
    let isComplete: Bool
    let language: SnootsLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: phase.symbol)
                    .foregroundStyle(SnootsPalette.ink)
                    .frame(width: 40, height: 40)
                    .background(isComplete ? SnootsPalette.lime : SnootsPalette.primaryTint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.title(language)).font(.snootsCardTitle())
                    Text(phase.detail(language)).font(.snootsMetadata()).foregroundStyle(SnootsPalette.secondaryText)
                }
                Spacer()
                Image(systemName: isComplete ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(isComplete ? SnootsPalette.navigationActive : SnootsPalette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct BeforeMatchingView: View {
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    let store: SnootsStore
    @Environment(\.dismiss) private var dismiss
    @State private var details: DogMatchingProfile
    @State private var birthDate: Date
    @State private var currentStep = 0
    @State private var isShowingBirthDatePicker = false
    @State private var showBirthDateError = false
    @State private var showActivityNeedsError = false
    @State private var showActivityPreferencesError = false
    @State private var showFirstMeetingPaceError = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var isShowingActivityRecommendation = false
    @State private var isShowingMeetingEnvironmentInfo = false
    @State private var advanceAfterRecommendation = false
    @State private var activityDraft = ""
    @FocusState private var isActivityDraftFocused: Bool

    init(store: SnootsStore) {
        self.store = store
        var profile = store.pet.matchingProfile
        let defaultActivities: Set<String> = ["散步", "嗅聞", "追逐", "拋接", "拔河"]
        for option in profile.activityPreferences where !defaultActivities.contains(option) {
            if !profile.activityKeywords.contains(option) { profile.activityKeywords.append(option) }
        }
        profile.activityPreferences.removeAll { !defaultActivities.contains($0) }
        if profile.activityNeeds.contains("無") {
            profile.activityNeeds = ["無特殊需求"]
        }
        _details = State(initialValue: profile)
        _birthDate = State(initialValue: store.pet.matchingProfile.birthDate ?? .now)
    }

    private let activityNeedOptions = ["分段休息", "留意關節", "避免跳躍", "避免悶熱環境", "避免過度興奮", "避免集體追逐", "給予獨立空間", "無特殊需求"]
    private let activityOptions = ["散步", "嗅聞", "追逐", "拋接", "拔河"]
    private let environmentOptions = ["中立且寬敞的戶外空間", "寵物友善的室內空間", "備有基礎安全設施的寵物公園"]
    private let paceOptions = ["先保持距離平行散步", "遠處觀察後逐步靠近", "雙方放鬆時短暫打招呼"]
    private let protectionOptions = ["核心疫苗已完成", "狂犬病疫苗在有效期間", "已完成體內外驅蟲", "晶片與寵物登記"]

    private var dogName: String { store.pet.name.isEmpty ? "狗狗" : store.pet.name }
    private var activityRecommendation: DogActivityRecommendation {
        DogActivityRecommendation.calculate(
            breed: store.pet.breed,
            size: store.pet.size,
            birthDate: details.birthDate,
            breedMappingPending: store.pet.breedMappingPending,
            needs: details.activityNeeds
        )
    }
    private var birthDateLabel: String {
        guard let birthDate = details.birthDate else { return "請選擇出生日期" }
        return birthDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_TW")))
    }
    private var stepTitle: String {
        switch currentStep {
        case 0: "活動力判斷"
        case 1: "活動喜好與見面環境"
        case 2: "互動偏好"
        default: "健康確認"
        }
    }

    private var headerSubtitle: String? {
        switch currentStep {
        case 0: "根據基本資料、年齡、活動需求規劃\(dogName)的日常活動量"
        case 1: "了解\(dogName)喜歡的活動與見面環境"
        case 2: "選出最符合\(dogName)平常玩玩具時的互動情境"
        default: "疫苗完整、驅蟲做好、身體健康，三個缺一不可"
        }
    }

    private var ageInMonths: Int? {
        guard let birthDate = details.birthDate else { return nil }
        return Calendar.current.dateComponents([.month], from: birthDate, to: .now).month
    }

    private var ageStage: String {
        guard let months = ageInMonths else { return "年紀區間" }
        switch months {
        case ..<5: return "未滿 5 個月"
        case ..<12: return "5 個月–1 歲"
        case ..<24: return "1–2 歲"
        case ..<96: return "滿 2 歲至未滿 8 歲"
        default: return "8 歲以上"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            GeometryReader { availableSpace in
                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        if currentStep == 2 {
                            VStack(spacing: 0) {
                                Spacer(minLength: 16)
                                observationPanel
                                Spacer(minLength: 16)
                            }
                            .frame(height: max(availableSpace.size.height, 500))
                            .id("matchFormTop")
                        } else {
                            VStack(alignment: .leading, spacing: 24) {
                                if currentStep == 0 {
                                    agePanel
                                    activityNeedsPanel
                                } else if currentStep == 1 {
                                    activityPanel
                                    environmentPanel
                                } else {
                                    protectionPanel
                                }
                            }
                            .id("matchFormTop")
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                            .padding(.bottom, 56)
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(.interactively)
                    .mask {
                        if currentStep == 2 {
                            Rectangle().fill(.black)
                        } else {
                            VStack(spacing: 0) {
                                Rectangle().fill(.black)
                                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                    .frame(height: 44)
                            }
                        }
                    }
                    .onChange(of: currentStep) { _, _ in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scrollProxy.scrollTo("matchFormTop", anchor: .top)
                        }
                    }
                }
            }

            bottomAction
        }
        .background(SnootsPalette.canvas)
        .foregroundStyle(SnootsPalette.ink)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isShowingBirthDatePicker) {
            NavigationStack {
                DatePicker("出生日期", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(SnootsPalette.navigationActive)
                    .padding(20)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(SnootsPalette.canvas)
                    .navigationTitle("選擇出生日期")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { isShowingBirthDatePicker = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") {
                                details.birthDate = birthDate
                                showBirthDateError = false
                                isShowingBirthDatePicker = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingActivityRecommendation, onDismiss: {
            guard advanceAfterRecommendation else { return }
            advanceAfterRecommendation = false
            currentStep = 1
        }) {
            activityRecommendationCard
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingMeetingEnvironmentInfo) {
            meetingEnvironmentInfoCard
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background, !isSaving else { return }
            // Only unsaved draft state is discarded; a completed profile stays in the store.
            details = store.pet.matchingProfile
            birthDate = details.birthDate ?? .now
            currentStep = 0
            activityDraft = ""
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(stepTitle)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(currentStep + 1)/4")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            if let headerSubtitle {
                Text(headerSubtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(SnootsPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(SnootsPalette.divider)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(SnootsPalette.lime)
                            .frame(width: proxy.size.width * CGFloat(currentStep + 1) / 4)
                    }
            }
            .frame(height: 6)
            .padding(.top, 12)
            .accessibilityLabel("填寫進度，第 \(currentStep + 1) 步，共 4 步")
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, currentStep == 2 ? 0 : 24)
        .background(SnootsPalette.canvas)
    }

    private var bottomAction: some View {
        VStack(spacing: 10) {
            if let saveError { matchingFieldError(saveError) }
            if isSaving { ProgressView("正在儲存四區資料…") }
            if currentStep > 0 {
                Button("上一步") {
                    currentStep -= 1
                }
                .font(.snootsButton(17))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(SnootsPalette.divider, lineWidth: 1))
                .buttonStyle(.plain)
            }

            Button(currentStep == 3 ? "開始配對找狗友！" : "下一步") {
                if currentStep == 0 {
                    showBirthDateError = details.birthDate == nil
                    showActivityNeedsError = details.activityNeeds.isEmpty
                    guard !showBirthDateError && !showActivityNeedsError else { return }
                    isShowingActivityRecommendation = true
                } else if currentStep == 3 {
                    saveMatchDetails()
                } else if currentStep == 1 {
                    addActivityFromDraft()
                    showActivityPreferencesError = details.activityPreferences.isEmpty
                    showFirstMeetingPaceError = details.firstMeetingPace == nil
                    guard !showActivityPreferencesError && !showFirstMeetingPaceError else { return }
                    currentStep += 1
                } else {
                    currentStep += 1
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(fill: SnootsPalette.primary, cornerRadius: 28))
            .disabled(isSaving)
        }
        .padding(.horizontal, 32)
        .padding(.top, currentStep == 2 ? 0 : 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    private var activityRecommendationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Beta 初步個人化建議")
                    .font(.snootsSection())
                Text("\(dogName)的日常活動建議")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }

            VStack(spacing: 0) {
                recommendationRow("建議活動量", value: activityRecommendation.title)
                if let dailyRange = activityRecommendation.dailyRange {
                    Divider()
                    recommendationRow("每日活動時間", value: dailyRange)
                }
            }
            .padding(.horizontal, 14)
            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16))

            Text(activityRecommendation.guidance)
                .font(.snootsMetadata())
                .foregroundStyle(SnootsPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let sourceURL = activityRecommendation.sourceURL {
                Link("查看犬種活動資料來源", destination: sourceURL)
                    .font(.footnote)
                    .frame(minHeight: 44)
            }
            Text("此為測試版參考，不是獸醫診斷；若有健康問題，請優先遵循獸醫建議。")
                .font(.footnote)
                .foregroundStyle(SnootsPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
            Button("填寫活動喜好與見面環境") {
                advanceAfterRecommendation = true
                isShowingActivityRecommendation = false
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(fill: SnootsPalette.primary, cornerRadius: 28))
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SnootsPalette.canvas)
    }

    private func recommendationRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.snootsUI(14, weight: .medium))
            Spacer()
            Text(value)
                .font(.snootsUI(14, weight: .semibold))
                .foregroundStyle(SnootsPalette.secondaryText)
        }
        .frame(minHeight: 46)
    }

    private var agePanel: some View {
        formSection(title: "出生日期", showsRequiredMark: showBirthDateError && details.birthDate == nil) {
            Button {
                birthDate = details.birthDate ?? .now
                isShowingBirthDatePicker = true
            } label: {
                HStack(spacing: 12) {
                    Text(birthDateLabel)
                        .font(details.birthDate == nil ? .system(.subheadline, design: .rounded) : .snootsBody())
                        .foregroundStyle(details.birthDate == nil ? SnootsPalette.secondaryText : SnootsPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Text(ageStage)
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(details.birthDate == nil ? SnootsPalette.secondaryText : SnootsPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(showBirthDateError ? Color(.systemRed) : SnootsPalette.divider, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("出生日期")
            .accessibilityValue(details.birthDate == nil ? "尚未選擇" : "\(birthDateLabel)，年紀區間\(ageStage)")
            if showBirthDateError && details.birthDate == nil {
                matchingFieldError("請先選擇出生日期。")
            }
        }
    }

    private var activityNeedsPanel: some View {
        formSection(title: "活動需求", showsRequiredMark: showActivityNeedsError && details.activityNeeds.isEmpty) {
            choiceList(activityNeedOptions, selected: details.activityNeeds) { option in
                if option == "無特殊需求" {
                    details.activityNeeds = details.activityNeeds == [option] ? [] : [option]
                } else {
                    details.activityNeeds = toggled(option, in: details.activityNeeds.filter { $0 != "無特殊需求" })
                }
                if !details.activityNeeds.isEmpty { showActivityNeedsError = false }
            }
            if showActivityNeedsError && details.activityNeeds.isEmpty {
                matchingFieldError("請選擇活動需求，若無需調整請選「無特殊需求」。")
            }
        }
    }

    private var activityPanel: some View {
        formSection(title: "\(dogName)喜歡做什麼活動？", showsRequiredMark: showActivityPreferencesError) {
            ActivityChipFlowLayout(spacing: 8) {
                ForEach(activityOptions, id: \.self) { option in
                    activityChip(option, isSelected: details.activityPreferences.contains(option)) {
                        details.activityPreferences = toggled(option, in: details.activityPreferences.filter { $0 != "沒有特別偏好" })
                        showActivityPreferencesError = false
                    }
                }
                activityChip("沒有特別偏好", isSelected: details.activityPreferences.contains("沒有特別偏好")) {
                    details.activityPreferences = details.activityPreferences == ["沒有特別偏好"] ? [] : ["沒有特別偏好"]
                    showActivityPreferencesError = false
                }
                ForEach(details.activityKeywords, id: \.self) { tag in
                    activityChip(tag, isSelected: true) {
                        details.activityKeywords.removeAll { $0 == tag }
                    }
                    .accessibilityHint("再點一下可移除標籤")
                }
            }
            if showActivityPreferencesError && details.activityPreferences.isEmpty {
                matchingFieldError("請選擇喜歡的活動；若沒有特定偏好請選「沒有特別偏好」。")
            }
            VStack(alignment: .leading, spacing: 6) {
                OnboardingFieldLabel(title: "自行選填")
                HStack(spacing: 4) {
                    TextField(
                        "",
                        text: $activityDraft,
                        prompt: Text("例如：草地嗅聞")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(SnootsPalette.placeholder)
                    )
                    .textFieldStyle(.plain)
                    .font(.snootsBody())
                    .focused($isActivityDraftFocused)
                    .submitLabel(.done)
                    .onSubmit(addActivityFromDraft)
                    .padding(.leading, 14)
                    Button(action: addActivityFromDraft) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(SnootsPalette.navigationActive)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(activityDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("新增活動標籤")
                }
                .frame(minHeight: 48)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(SnootsPalette.divider, lineWidth: 1))
            }
        }
    }

    private var environmentPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                OnboardingFieldLabel(title: "初次見面，想選哪裡？")
                Button {
                    isShowingMeetingEnvironmentInfo = true
                } label: {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(SnootsPalette.navigationActive)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看初次見面環境提醒")
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(environmentOptions, id: \.self) { option in
                    let isSelected = details.meetingEnvironments.contains(option)
                    Button {
                        details.meetingEnvironments = toggled(option, in: details.meetingEnvironments)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 17))
                                .foregroundStyle(isSelected ? SnootsPalette.navigationActive : SnootsPalette.inactive)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(option)
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundStyle(SnootsPalette.ink)
                                if isSelected {
                                    Text(environmentTip(for: option))
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(SnootsPalette.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isSelected ? SnootsPalette.primaryTint : SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isSelected ? SnootsPalette.navigationActive : SnootsPalette.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            formSection(title: "第一次見面，希望怎麼開始？", showsRequiredMark: showFirstMeetingPaceError) {
                choiceList(paceOptions, selected: details.firstMeetingPace.map { [$0] } ?? []) { option in
                    details.firstMeetingPace = details.firstMeetingPace == option ? nil : option
                    showFirstMeetingPaceError = false
                }
                if showFirstMeetingPaceError && details.firstMeetingPace == nil {
                    matchingFieldError("請選擇第一次見面的相處步調。")
                }
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var meetingEnvironmentInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("初次見面的小提醒")
                .font(.snootsSection())
            Text("初次見面優先選室外、中立且安靜的場地，並保留讓狗狗觀察與退開的距離。")
                .font(.snootsBody())
                .foregroundStyle(SnootsPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("知道了") { isShowingMeetingEnvironmentInfo = false }
                .buttonStyle(OnboardingPrimaryButtonStyle(fill: SnootsPalette.primary, cornerRadius: 28))
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SnootsPalette.canvas)
    }

    private var observationPanel: some View {
        MatchingInteractionCarousel(selection: $details.interactionScenario, dogName: dogName)
    }

    private var protectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("確認資料正確時再選「有」；不願提供可選「不願透露」。")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(SnootsPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(protectionOptions.filter { $0 != "核心疫苗已完成" || (ageInMonths ?? 999) < 5 }, id: \.self) { option in
                HStack(alignment: .center, spacing: 12) {
                    Text(option)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(SnootsPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 4) {
                        ForEach(["有", "不願透露"], id: \.self) { answer in
                            let isSelected = details.protectionAnswers[option] == answer
                            Button {
                                details.protectionAnswers[option] = details.protectionAnswers[option] == answer ? nil : answer
                            } label: {
                                Text(answer)
                                    .font(.system(.subheadline, design: .rounded).weight(isSelected ? .semibold : .regular))
                                    .foregroundStyle(SnootsPalette.ink)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(isSelected ? SnootsPalette.surface : Color.clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(option)：\(answer)")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    .frame(width: 156)
                    .padding(4)
                    .background(SnootsPalette.divider.opacity(0.55), in: Capsule())
                }
                .frame(minHeight: 56)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choiceList(_ options: [String], selected: [String], action: @escaping (String) -> Void) -> some View {
        VStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                choiceButton(option, isSelected: selected.contains(option)) { action(option) }
            }
        }
    }

    private func activityChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.snootsUI(14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color(light: 0x43296F, dark: 0xF3EBFF) : SnootsPalette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(isSelected ? Color(light: 0xD8C6FF, dark: 0x513B70) : SnootsPalette.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggled(_ option: String, in selected: [String]) -> [String] {
        if selected.contains(option) { return selected.filter { $0 != option } }
        return selected + [option]
    }

    private func addActivityFromDraft() {
        let input = activityDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        if !details.activityKeywords.contains(input) {
            details.activityKeywords.append(input)
        }
        details.activityDescription = [details.activityDescription, input]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        activityDraft = ""
        isActivityDraftFocused = false
    }

    private func environmentTip(for option: String) -> String {
        switch option {
        case "中立且寬敞的戶外空間": "初次見面保留足夠距離，讓狗狗可以觀察、靠近或自行退開。"
        case "寵物友善的室內空間": "選擇寬敞、座位距離足夠，且能讓狗狗分開休息的場所。"
        default: "確認場地不過度擁擠，並具備安全設施與可自由離開的動線。"
        }
    }

    private func formSection<Content: View>(title: String, showsRequiredMark: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            OnboardingFieldLabel(title: title, showsRequiredMark: showsRequiredMark)
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func matchingFieldError(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color(.systemRed))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func choiceButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? SnootsPalette.navigationActive : SnootsPalette.inactive)
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .foregroundStyle(SnootsPalette.ink)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(isSelected ? SnootsPalette.primaryTint : SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(isSelected ? SnootsPalette.navigationActive : SnootsPalette.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func saveMatchDetails() {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        Task {
            do {
                try await account.saveMatchingProfile(details)
                store.saveMatchDetails(details)
                dismiss()
            } catch {
                saveError = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private enum MatchingInteractionScenario: String, CaseIterable, Identifiable {
    case observesAtDistance
    case leavesAfterRejection
    case tugsTogether
    case followsAfterReleasing

    var id: String { rawValue }

    func caption(for dogName: String) -> String {
        switch self {
        case .observesAtDistance: "對方玩玩具時\n\(dogName)能放鬆地在旁觀察"
        case .leavesAfterRejection: "\(dogName)會繞圈留出空間邀玩\n對方沒回應也願意退開"
        case .tugsTogether: "一起拉扯玩具時可能低吼\n尾巴仍自然擺動"
        case .followsAfterReleasing: "對方放開玩具後\n\(dogName)會跟上互動不爭搶"
        }
    }

    var imageName: String {
        switch self {
        case .observesAtDistance: "MatchInteractionObservesCutout"
        case .tugsTogether: "MatchInteractionTugsCutout"
        case .leavesAfterRejection: "MatchInteractionLeavesCutout"
        case .followsAfterReleasing: "MatchInteractionReleasesCutout"
        }
    }
}

private struct MatchingInteractionCarousel: View {
    @Binding var selection: String?
    let dogName: String
    @State private var centeredScenario: String? = MatchingInteractionScenario.observesAtDistance.rawValue
    @State private var didSwipe = false

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width - 64, 272)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(MatchingInteractionScenario.allCases) { option in
                        let isSelected = selection == option.rawValue
                        Button {
                            selection = isSelected ? nil : option.rawValue
                            if !isSelected {
                                withAnimation(.snappy) { centeredScenario = option.rawValue }
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Image(option.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: cardWidth, height: cardWidth * 1.5)
                                    .background(SnootsPalette.primaryTint)
                                    .accessibilityHidden(true)

                                Text(option.caption(for: dogName))
                                    .font(.snootsUI(16, weight: .bold))
                                    .foregroundStyle(SnootsPalette.ink)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.85)
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
                        .accessibilityLabel(option.caption(for: dogName))
                        .accessibilityValue(isSelected ? "已選取" : "未選取")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, (geometry.size.width - cardWidth) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredScenario)
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { didSwipe = true }
                if phase == .idle && didSwipe {
                    if let centeredScenario { selection = centeredScenario }
                    didSwipe = false
                }
            }
        }
        .frame(height: 468)
        .onAppear { centeredScenario = selection ?? MatchingInteractionScenario.observesAtDistance.rawValue }
        .onChange(of: selection) { _, selected in
            let message = selected.flatMap(MatchingInteractionScenario.init(rawValue:))
                .map { "已選擇：\($0.caption(for: dogName))" } ?? "已取消選取"
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

private enum ActivityTagExtractor {
    private static let known = ["散步", "嗅聞", "追逐", "拋接", "拔河", "跑步", "游泳", "益智", "陪伴", "草地", "公園", "飛盤", "慢走", "玩水", "追球", "玩球", "爬山", "打滾", "跳躍", "丟球"]
    private static let ignored: Set<String> = ["喜歡", "很愛", "最愛", "一起", "慢慢", "平常", "通常", "偶爾", "經常", "狗狗", "主人", "朋友", "其他", "每天", "活動", "可以", "時候"]

    static func tags(from input: String, dogName: String) -> [String] {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        if text.count <= 4 { return [text] }
        var tags: [String] = []
        func append(_ candidate: String) {
            let tag = String(candidate.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4))
            guard tag.count >= 2, !ignored.contains(tag), tag != dogName,
                  !tags.contains(where: { $0 == tag || $0.contains(tag) || tag.contains($0) }) else { return }
            tags.append(tag)
        }

        for keyword in known.filter({ text.contains($0) }).sorted(by: {
            text.range(of: $0)!.lowerBound < text.range(of: $1)!.lowerBound
        }) { append(keyword) }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if word.count >= 2, word.count <= 4 { append(word) }
            return tags.count < 5
        }

        if tags.isEmpty {
            var fallback = text.replacingOccurrences(of: dogName, with: "")
            for prefix in ["喜歡在", "喜歡玩", "喜歡", "最愛", "很愛", "愛玩", "一起", "在", "去", "玩"] where fallback.hasPrefix(prefix) {
                fallback.removeFirst(prefix.count)
            }
            let candidate = String(fallback.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4))
            if !candidate.isEmpty { tags.append(candidate) }
        }
        return Array(tags.prefix(5))
    }
}

private struct ActivityChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth = proposal.width ?? 320
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0 && rowWidth + spacing + size.width > availableWidth {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: availableWidth, height: totalHeight + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + spacing + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            if x > bounds.minX { x += spacing }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct ProfileCompletionSheet: View {
    let phase: ProfileCompletionPhase
    let store: SnootsStore
    let language: SnootsLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var vaccineSummary = "狂犬病、核心疫苗、驅蟲皆已完成"
    @State private var emergencyPhone = "0912-345-678"
    @State private var leashHabit = "外出全程使用胸背帶與牽繩"

    var body: some View {
        NavigationStack {
            Form {
                Section(phase.detail(language)) {
                    TextField(language.text("Vaccine and parasite prevention", "疫苗／驅蟲紀錄摘要"), text: $vaccineSummary, axis: .vertical)
                    TextField(language.text("Emergency phone", "緊急聯絡電話"), text: $emergencyPhone)
                        .keyboardType(.phonePad)
                    TextField(language.text("Leash protection", "牽繩防護習慣"), text: $leashHabit, axis: .vertical)
                }
            }
            .navigationTitle(phase.title(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("Save", "儲存")) {
                        store.saveSafetyDetails(
                            vaccineSummary: vaccineSummary,
                            emergencyPhone: emergencyPhone,
                            leashHabit: leashHabit
                        )
                        dismiss()
                    }
                }
            }
        }
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
    @Environment(SnootsAccountSession.self) private var account
    let store: SnootsStore
    @Binding var selectedLanguageRawValue: String
    @State private var showingSignOutConfirmation = false

    var body: some View {
        Form {
            Section("顯示語言") {
                Label("依系統設定顯示繁體中文", systemImage: "globe")
                Text("目前所有介面內容皆使用繁體中文。")
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            Section("封鎖名單") {
                if store.isMatchBlocked {
                    HStack {
                        Label("超超（飼主 David）", systemImage: "hand.raised.fill")
                        Spacer()
                        Button("解除封鎖") {
                            store.unblockMatch()
                        }
                    }
                } else {
                    Label("目前沒有封鎖的使用者", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
            }
            Section("帳號") {
                Button("登出", role: .destructive) {
                    showingSignOutConfirmation = true
                }
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectedLanguageRawValue = SnootsLanguage.traditionalChinese.rawValue }
        .confirmationDialog("確定要登出嗎？", isPresented: $showingSignOutConfirmation) {
            Button("登出", role: .destructive) { Task { await account.signOut() } }
        } message: {
            Text("登出後會清除此裝置的登入狀態；已提交的資料仍保留在帳號中。")
        }
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
    @State private var ownerMessage: String

    init(store: SnootsStore, language: SnootsLanguage) {
        self.store = store
        self.language = language
        _ownerName = State(initialValue: store.profile.name)
        _city = State(initialValue: store.profile.neighborhood.contains("New Taipei") ? "New Taipei City" : "Taipei City")
        _district = State(initialValue: store.profile.neighborhood.contains("Xinyi") ? "Xinyi District" : "Da’an District")
        _petName = State(initialValue: store.pet.name)
        _ownerMessage = State(initialValue: store.profile.ownerMessage)
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

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(language.text("Write a short introduction for the other owner.", "寫一段給對方飼主看的簡短介紹。"))
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.secondaryText)
                        Spacer()
                        Text(language.text("Shown on match cards", "顯示於配對卡片"))
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Text("“")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(SnootsPalette.secondaryText)
                            .padding(.top, 1)
                        TextEditor(text: $ownerMessage)
                            .font(.snootsUI(15))
                            .frame(minHeight: 82, maxHeight: 128)
                            .scrollContentBackground(.hidden)
                            .scrollIndicators(.hidden)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text(language.text("Share a warm introduction so other owners know what kind of first meeting feels comfortable for you.", "用一句溫暖的介紹，讓對方先知道什麼樣的初次見面對你們最舒服。"))
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
            } header: {
                Text(language.text("Owner’s note", "飼主寄語"))
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
                        ownerMessage: ownerMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    dismiss()
                }
            }
        }
    }
}

struct MatchConfirmationView: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    let language: SnootsLanguage
    let onNavigate: (SnootsRoute) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            HStack(spacing: 10) {
                MatchSuccessAvatar(imageName: candidate.imageName, name: candidate.name)
                MatchSuccessAvatar(imageName: store.pet.imageName, name: store.pet.name)
            }
            Text("與 \(candidate.name) 配對成功！")
                .font(.snootsScreenTitle())
            Text("先完成一個小任務，或直接開始聊天。")
                .font(.snootsBody())
                .multilineTextAlignment(.center)
                .foregroundStyle(SnootsPalette.secondaryText)
                .padding(.horizontal, 26)
            Button("開啟破冰小任務") { onNavigate(.icebreaker) }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
            Button("直接發送第一條訊息") {
                store.createMatchChat()
                store.sendMatchChatMessage("嗨 \(candidate.owner)！\(candidate.name)看起來很可愛，要不要先一起散步？")
                onNavigate(.chat)
            }
            .buttonStyle(SecondaryButtonStyle())
            Spacer()
        }
        .padding(22)
        .navigationTitle(language.text("Confirm match", "確認配對"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct MatchSuccessAvatar: View {
    let imageName: String
    let name: String

    var body: some View {
        VStack(spacing: 7) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 82, height: 82)
                .clipShape(Circle())
                .overlay { Circle().stroke(SnootsPalette.primaryTint, lineWidth: 4) }
            Text(name)
                .font(.snootsUI(14, weight: .semibold))
        }
    }
}

private enum ChatListTab: String, CaseIterable, Identifiable {
    case direct
    case meetups

    var id: String { rawValue }
}

private struct MatchChatListView: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    let language: SnootsLanguage
    let onNavigate: (SnootsRoute) -> Void
    @State private var selectedTab: ChatListTab

    init(
        candidate: PlaydateCandidate,
        store: SnootsStore,
        language: SnootsLanguage,
        initiallySelectedTab: ChatListTab = .direct,
        onNavigate: @escaping (SnootsRoute) -> Void
    ) {
        self.candidate = candidate
        self.store = store
        self.language = language
        self.onNavigate = onNavigate
        _selectedTab = State(initialValue: initiallySelectedTab)
    }

    private var latestMessage: String {
        store.matchChatMessages.last?.text ?? language.text("It's a match", "配對成功")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(language.text("Chats", "聊天室"))
                        .font(.snootsScreenTitle())
                    Text(language.text("Get to know matched dog friends at an easy pace, and stay coordinated for meetups.", "慢慢認識配對成功的狗朋友，也和狗聚夥伴保持聯繫。"))
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }

                Picker(language.text("Chat type", "聊天類型"), selection: $selectedTab) {
                    Text(language.text("Personal", "個人")).tag(ChatListTab.direct)
                    Text(language.text("Groups", "群組")).tag(ChatListTab.meetups)
                }
                .pickerStyle(.segmented)

                if selectedTab == .direct {
                    EventFriendChatLinks()
                    directChats
                } else {
                    meetupChats
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle(language.text("Chats", "聊天室"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var directChats: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(language.text("New matches", "新配對"))
                .font(.snootsSection())

            if store.isMatched && store.hasMatchChat {
                Button {
                    onNavigate(.chat)
                } label: {
                    HStack(spacing: 13) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(candidate.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 62, height: 62)
                                .clipShape(Circle())
                                .overlay { Circle().stroke(SnootsPalette.primaryTint, lineWidth: 3) }
                            Image(systemName: "heart.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(SnootsPalette.ink)
                                .frame(width: 23, height: 23)
                                .background(SnootsPalette.lime, in: Circle())
                                .overlay { Circle().stroke(SnootsPalette.surface, lineWidth: 2) }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 7) {
                                Text(candidate.name)
                                    .font(.snootsCardTitle())
                                Text(language.text("New match", "新配對"))
                                    .font(.snootsMetadata())
                                    .foregroundStyle(SnootsPalette.ink)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(SnootsPalette.lime, in: Capsule())
                            }
                            Text(latestMessage)
                                .font(.snootsUI(14))
                                .foregroundStyle(SnootsPalette.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 9) {
                            Text(language.text("Now", "剛剛"))
                                .font(.snootsMetadata())
                                .foregroundStyle(SnootsPalette.secondaryText)
                            Circle()
                                .fill(SnootsPalette.navigationActive)
                                .frame(width: 9, height: 9)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                    .snootsCardShadow()
                }
                .buttonStyle(.plain)
                .accessibilityHint(language.text("Open chat with \(candidate.name)", "開啟和\(candidate.name)的聊天室"))
            } else {
                ContentUnavailableView(
                    "尚無個人聊天室",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("雙方都選擇想認識後，新的聊天室才會出現在這裡。")
                )
            }

            Label(language.text("Only share information that is appropriate for your matched dog friend to see.", "請只在聊天室內分享適合公開給配對對象的資訊。"), systemImage: "lock.fill")
                .font(.snootsMetadata())
                .foregroundStyle(SnootsPalette.secondaryText)
                .padding(.horizontal, 4)
        }
    }

    private var meetupChats: some View { MeetupGroupListSection() }

    private var legacyMeetupChats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.text("Your meetup groups", "你的狗聚群組"))
                .font(.snootsSection())

            Button {
                onNavigate(.meetupChat)
            } label: {
                HStack(spacing: 13) {
                    MeetupParticipantAvatarStack(participants: store.upcomingMeetup.participants, language: language)
                        .frame(width: 112, alignment: .leading)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 7) {
                            Text(store.upcomingMeetup.localizedTitle(language))
                                .font(.snootsCardTitle())
                                .lineLimit(1)
                            Text(language.text("Group", "群組"))
                                .font(.snootsMetadata())
                                .foregroundStyle(SnootsPalette.ink)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(SnootsPalette.lime, in: Capsule())
                        }
                        Text(store.meetupGroupMessages.last?.text ?? store.upcomingMeetup.localizedHostNote(language))
                            .font(.snootsUI(14))
                            .foregroundStyle(SnootsPalette.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                .snootsCardShadow()
            }
            .buttonStyle(.plain)
            .accessibilityHint(language.text("Open meetup group chat", "開啟狗聚群組聊天室"))

            Label(language.text("Use this space to coordinate with everyone before the meetup.", "在活動前，使用群組聊天室和所有夥伴一起確認細節。"), systemImage: "person.3.fill")
                .font(.snootsMetadata())
                .foregroundStyle(SnootsPalette.secondaryText)
                .padding(.horizontal, 4)
        }
    }
}

private struct MeetupGroupChatRoom: View {
    let meetup: UpcomingMeetup
    let store: SnootsStore
    let language: SnootsLanguage
    let onOpenDashboard: () -> Void
    let onOpenSettings: () -> Void
    @FocusState private var isComposerFocused: Bool
    @State private var draft = ""
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("釘選公告", systemImage: "pin.fill")
                            .font(.snootsUI(13, weight: .bold))
                            .foregroundStyle(SnootsPalette.navigationActive)
                        Text(store.meetupGroupAnnouncement)
                            .font(.snootsUI(14, weight: .semibold))
                            .foregroundStyle(SnootsPalette.ink)
                        Text("首次見面請保持牽繩，並依各自的社交界線慢慢認識。")
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.secondaryText)
                        Button("抵達狗聚後，進入現場儀表板", systemImage: "checkmark.shield.fill", action: onOpenDashboard)
                            .font(.snootsUI(14, weight: .semibold))
                            .buttonStyle(.borderedProminent)
                            .tint(SnootsPalette.lime)
                        }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                    ForEach(store.meetupGroupMessages) { message in
                        HStack(alignment: .bottom, spacing: 8) {
                            if message.isOutgoing {
                                Spacer(minLength: 52)
                            } else {
                                Image(avatarImageName(for: message))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 30, height: 30)
                                    .clipShape(Circle())
                                    .overlay { Circle().stroke(SnootsPalette.primaryTint, lineWidth: 2) }
                            }

                            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                                if !message.isOutgoing {
                                    Text(message.senderName)
                                        .font(.snootsMetadata())
                                        .foregroundStyle(SnootsPalette.secondaryText)
                                }
                                Text(message.text)
                                    .font(.snootsBody())
                                    .foregroundStyle(SnootsPalette.ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .background(
                                        message.isOutgoing ? SnootsPalette.lime : SnootsPalette.surface,
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    )
                            }

                            if !message.isOutgoing {
                                Spacer(minLength: 52)
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.meetupGroupMessages.count) { _, _ in
                guard let lastMessageID = store.meetupGroupMessages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastMessageID, anchor: .bottom)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(SnootsPalette.ink)
                            .frame(width: 40, height: 40)
                            .background(SnootsPalette.primaryTint, in: Circle())
                    }
                    .disabled(!store.meetupGroupAllowsPhotoSharing)
                    .accessibilityLabel("傳送照片")

                    TextField(language.text("Message the group", "傳送訊息給群組"), text: $draft, axis: .vertical)
                        .font(.snootsBody())
                        .lineLimit(1...4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
                        .focused($isComposerFocused)
                        .submitLabel(.send)
                        .onSubmit { send(draft) }
                        .disabled(!store.meetupGroupAllowsMemberMessages)

                    Button { send(draft) } label: {
                        Image(systemName: "arrow.up")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(SnootsPalette.ink)
                            .frame(width: 44, height: 44)
                            .background(SnootsPalette.lime, in: Circle())
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .disabled(!store.meetupGroupAllowsMemberMessages)
                    .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.meetupGroupAllowsMemberMessages ? 0.45 : 1)
                    .accessibilityLabel(language.text("Send message", "傳送訊息"))

                    Image(systemName: "mic.fill")
                        .font(.headline)
                        .foregroundStyle(SnootsPalette.secondaryText)
                        .frame(width: 36, height: 44)
                        .accessibilityLabel("語音訊息")
                }
            }
            .padding(14)
            .background(SnootsPalette.canvas)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle(meetup.localizedTitle(language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("群組管理")
            }
        }
    }

    private func avatarImageName(for message: MeetupGroupMessage) -> String {
        meetup.participants.first {
            $0.name == message.senderName || $0.traditionalChineseName == message.senderName
        }?.imageName
            ?? meetup.participants.first?.imageName
            ?? "Tofu"
    }

    private func send(_ text: String) {
        guard store.meetupGroupAllowsMemberMessages else { return }
        store.sendMeetupGroupMessage(text)
        draft = ""
        isComposerFocused = false
    }
}

private struct MeetupGroupSettingsView: View {
    let meetup: UpcomingMeetup
    let store: SnootsStore
    let language: SnootsLanguage
    let onOpenParticipants: () -> Void
    let onLeaveGroup: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var announcement: String
    @State private var allowsMemberMessages: Bool
    @State private var allowsPhotoSharing: Bool
    @State private var isMuted = false
    @State private var isShowingLeaveConfirmation = false

    init(
        meetup: UpcomingMeetup,
        store: SnootsStore,
        language: SnootsLanguage,
        onOpenParticipants: @escaping () -> Void,
        onLeaveGroup: @escaping () -> Void
    ) {
        self.meetup = meetup
        self.store = store
        self.language = language
        self.onOpenParticipants = onOpenParticipants
        self.onLeaveGroup = onLeaveGroup
        _announcement = State(initialValue: store.meetupGroupAnnouncement)
        _allowsMemberMessages = State(initialValue: store.meetupGroupAllowsMemberMessages)
        _allowsPhotoSharing = State(initialValue: store.meetupGroupAllowsPhotoSharing)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    groupActionButton(
                        title: isMuted ? "取消禁音" : "靜音",
                        systemImage: isMuted ? "bell.slash.fill" : "bell.fill"
                    ) {
                        isMuted.toggle()
                    }
                    groupActionButton(title: "成員", systemImage: "person.3.fill", action: onOpenParticipants)
                    ShareLink(
                        item: meetupInvitationText,
                        subject: Text(meetup.localizedTitle(language))
                    ) {
                        groupActionLabel(title: "邀請", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(MeetupGroupActionButtonStyle(isDestructive: false))
                    .accessibilityLabel("邀請")
                    groupActionButton(
                        title: "離開群組",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        isDestructive: true
                    ) {
                        isShowingLeaveConfirmation = true
                    }
                }
                .padding(.vertical, 2)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                Text("釘選公告編輯")
                    .font(.snootsUI(16, weight: .semibold))
                    .foregroundStyle(SnootsPalette.ink)
                TextEditor(text: $announcement)
                    .font(.snootsBody())
                    .frame(minHeight: 96)
            }
        }
        .scrollContentBackground(.hidden)
        .background(SnootsPalette.canvas)
        .navigationTitle(meetup.localizedTitle(language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("儲存", action: save)
            }
        }
        .alert("要離開此群組嗎？", isPresented: $isShowingLeaveConfirmation) {
            Button("取消", role: .cancel) {}
            Button("離開群組", role: .destructive, action: onLeaveGroup)
        } message: {
            Text("離開後將不再收到此活動群組的訊息。")
        }
    }

    private func groupActionButton(
        title: String,
        systemImage: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { groupActionLabel(title: title, systemImage: systemImage) }
        .buttonStyle(MeetupGroupActionButtonStyle(isDestructive: isDestructive))
        .accessibilityLabel(title)
    }

    private func groupActionLabel(title: String, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.snootsUI(17, weight: .semibold))
            Text(title)
                .font(.snootsUI(12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .contentShape(RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
    }

    private var meetupInvitationText: String {
        let dateTime = meetup.startDate.formatted(
            Date.FormatStyle(date: .long, time: .shortened).locale(language.locale)
        )
        return language.text(
            "Join me at \(meetup.localizedTitle(language)) on \(dateTime), \(meetup.localizedLocation(language)).",
            "邀請你一起參加「\(meetup.localizedTitle(language))」，時間：\(dateTime)；地點：\(meetup.localizedLocation(language))。"
        )
    }

    private func save() {
        store.updateMeetupGroupSettings(
            announcement: announcement,
            allowsMemberMessages: allowsMemberMessages,
            allowsPhotoSharing: allowsPhotoSharing
        )
        dismiss()
    }
}

private struct MeetupGroupActionButtonStyle: ButtonStyle {
    let isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                isDestructive
                    ? SnootsPalette.alert
                    : (configuration.isPressed ? SnootsPalette.navigationActive : SnootsPalette.ink)
            )
            .background(
                configuration.isPressed ? SnootsPalette.primaryTint : Color.clear,
                in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous)
            )
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct MatchChatRoom: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    let language: SnootsLanguage
    let onNavigate: (SnootsRoute) -> Void
    let onBackToChatList: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isComposerFocused: Bool
    @State private var draft = ""
    @State private var isGuideExpanded = false
    @State private var isShowingMeetupInvitationPrompt = false
    @State private var isShowingProfile = false
    @State private var isShowingCancelConfirmation = false
    @State private var isShowingBlockConfirmation = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            if store.isMatchVerificationActive {
                Label("模擬聊天室：訊息只留在此裝置，不會送給真實使用者。", systemImage: "testtube.2")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(SnootsPalette.primaryTint)
            }
            VStack(alignment: .leading, spacing: 10) {
                IcebreakerGuideCard(
                    candidate: candidate,
                    store: store,
                    isExpanded: $isGuideExpanded,
                    onUsePrompt: {
                        let reminder = "\(store.pet.name) 第一次見面需要保持 2 公尺距離，且對食物較敏感喔！"
                        draft = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? reminder
                            : "\(draft)\n\(reminder)"
                        isComposerFocused = true
                    },
                    onPrepareMeetupInvite: {
                        isShowingMeetupInvitationPrompt = true
                    },
                    onOpenIcebreaker: { onNavigate(.icebreaker) }
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if store.matchChatMessages.isEmpty {
                        ContentUnavailableView(
                            "開始和 \(candidate.name) 聊天",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("從下方輸入訊息開始聊天。")
                        )
                    }

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
                .padding(18)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(SnootsPalette.ink)
                            .frame(width: 40, height: 40)
                            .background(SnootsPalette.primaryTint, in: Circle())
                    }
                    .disabled(true)
                    .accessibilityLabel("傳送照片尚未開放")
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
        .overlay {
            if isShowingMeetupInvitationPrompt {
                ZStack {
                    Color.black.opacity(0.24)
                        .ignoresSafeArea()

                    MeetupInvitationPromptCard(
                        candidate: candidate,
                        onPrepareInvitation: {
                            isShowingMeetupInvitationPrompt = false
                            prepareMeetupInvitationDraft()
                        },
                        onDismiss: {
                            isShowingMeetupInvitationPrompt = false
                        }
                    )
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .onAppear {
            presentMeetupInvitationIfNeeded()
        }
        .onChange(of: store.sparkPoints) { _, _ in
            presentMeetupInvitationIfNeeded()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onBackToChatList) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("返回聊天室")
            }
            ToolbarItem(placement: .principal) {
                Button { isShowingProfile = true } label: {
                    HStack(spacing: 7) {
                        Image(candidate.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 38, height: 38)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(candidate.name)
                            HStack(spacing: 3) {
                                Text("飼主 \(candidate.owner)")
                                    .foregroundStyle(SnootsPalette.secondaryText)
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(SnootsPalette.navigationActive)
                            }
                            .font(.snootsMetadata())
                        }
                    }
                    .font(.snootsUI(15, weight: .semibold))
                    .lineLimit(1)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("\(candidate.name)，飼主 \(candidate.owner)，已驗證")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("取消配對", role: .destructive) { isShowingCancelConfirmation = true }
                    Button("封鎖", role: .destructive) { isShowingBlockConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("聊天室選單")
            }
        }
        .sheet(isPresented: $isShowingProfile) {
            MatchDetailSheet(candidate: candidate, language: language)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("要取消和\(candidate.name)的配對嗎？", isPresented: $isShowingCancelConfirmation, titleVisibility: .visible) {
            Button("取消配對", role: .destructive) {
                store.cancelMatch()
                dismiss()
            }
        } message: {
            Text("雙方會解除好友關係，聊天室將從列表中消失。對方不會收到通知。")
        }
        .confirmationDialog("要封鎖\(candidate.name)嗎？", isPresented: $isShowingBlockConfirmation, titleVisibility: .visible) {
            Button("封鎖", role: .destructive) {
                store.blockMatch()
                dismiss()
            }
        } message: {
            Text("雙方會解除好友關係，聊天室將消失。對方無法搜尋你與豆花，也不會在多人活動的狗狗辨識牆看到你；之後可在設定解除封鎖。")
        }
    }

    private func send(_ text: String) {
        store.sendMatchChatMessage(text)
        draft = ""
        isComposerFocused = false
    }

    private func presentMeetupInvitationIfNeeded() {
        guard store.sparkPoints >= 100, !store.hasSentMeetupInvite else { return }
        isGuideExpanded = true

        guard !store.hasPreparedMeetupInvitation, !store.hasSeenMeetupInvitationPrompt else { return }
        store.hasSeenMeetupInvitationPrompt = true
        isShowingMeetupInvitationPrompt = true
    }

    private func prepareMeetupInvitationDraft() {
        store.prepareMeetupInvitation()
        draft = "想邀請\(candidate.name)一起來一場 20 分鐘的平行散步，你們這週有適合的時間嗎？"
        isComposerFocused = true
    }
}

private struct MeetupInvitationPromptCard: View {
    let candidate: PlaydateCandidate
    let onPrepareInvitation: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(SnootsPalette.ink)
                .frame(width: 62, height: 62)
                .background(SnootsPalette.primaryTint, in: Circle())

            VStack(spacing: 7) {
                Text("想和\(candidate.name)見面嗎？")
                    .font(.snootsCardTitle())
                Text("邀請會先帶入輸入框，確認後再發送。")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button(action: onPrepareInvitation) {
                    Label("帶入見面邀請草稿", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))

                Button("暫時先不要", action: onDismiss)
                    .font(.snootsUI(16, weight: .semibold))
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(SnootsPalette.canvas, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 28, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct FeedbackRecipient: Identifiable {
    let id: String
    let name: String
    let owner: String
    let breed: String
    let imageName: String
}

private struct PostEventFeedbackSheet: View {
    let recipient: FeedbackRecipient
    let store: SnootsStore
    let language: SnootsLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTags: Set<String> = []
    @State private var wantsAnotherMeetup = true
    @State private var note = ""
    @State private var sharedPhoto: PhotosPickerItem?

    private let tags = ["超有禮貌", "社交大師", "散步穩定", "脾氣好"]

    init(candidate: PlaydateCandidate, store: SnootsStore, language: SnootsLanguage) {
        recipient = FeedbackRecipient(
            id: candidate.name,
            name: candidate.name,
            owner: candidate.owner,
            breed: candidate.breed,
            imageName: candidate.imageName
        )
        self.store = store
        self.language = language
    }

    init(dog: MemoryDog, store: SnootsStore, language: SnootsLanguage) {
        recipient = FeedbackRecipient(
            id: dog.id,
            name: dog.name,
            owner: dog.owner,
            breed: dog.breed,
            imageName: dog.imageName
        )
        self.store = store
        self.language = language
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(recipient.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("你成功認出了\(recipient.name)！")
                                .font(.snootsCardTitle())
                            Text("把今天感受到的好，送給 \(recipient.name) 與 \(recipient.owner)。")
                                .font(.snootsMetadata())
                                .foregroundStyle(SnootsPalette.secondaryText)
                        }
                    }
                } header: {
                    Text("共同回憶卡片 · 02")
                }
                Section("這次見面，你感受到…（可複選）") {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                        } label: {
                            HStack {
                                Text(tag)
                                Spacer()
                                Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                            }
                        }
                        .foregroundStyle(SnootsPalette.ink)
                    }
                }
                Section(language.text("Future meetups", "是否想再約")) {
                    Picker(language.text("Your preference", "你的選擇"), selection: $wantsAnotherMeetup) {
                        Text(language.text("🐾 Hope to meet again", "🐾 希望下次再約")).tag(true)
                        Text(language.text("Keep things as they are", "暫時保持現狀")).tag(false)
                    }
                    .pickerStyle(.inline)
                    Text(language.text("This preference is kept private until both sides choose to reconnect.", "此選擇會匿名保留，直到雙方都願意再次聯絡。"))
                        .font(.snootsMetadata())
                }
                Section("給\(recipient.name)與飼主的一句話") {
                    TextEditor(text: $note)
                        .frame(minHeight: 72)
                        .overlay(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("例如：謝謝\(recipient.name)今天來跟我們玩！你毛好澎、好可愛。")
                                    .font(.snootsBody())
                                    .foregroundStyle(SnootsPalette.placeholder)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                    PhotosPicker(selection: $sharedPhoto, matching: .images) {
                        Label(sharedPhoto == nil ? "上傳今天活動中的照片" : "照片已加入回饋卡", systemImage: sharedPhoto == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                    }
                }
                Section {
                    Button {
                        store.addInteractionRecord(
                            partnerDogName: recipient.name,
                            partnerBreed: recipient.breed,
                            recipientOwner: recipient.owner,
                            recipientImageName: recipient.imageName,
                            positiveTags: Array(selectedTags).sorted(),
                            wantsAnotherMeetup: wantsAnotherMeetup,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            hasSharedPhoto: sharedPhoto != nil
                        )
                        dismiss()
                    } label: {
                        Label("發送暖心回饋卡", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(language.text("Post-meeting feedback", "見面後回饋"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("Save", "儲存")) { dismiss() }
                }
            }
        }
    }
}

private struct IcebreakerGuideCard: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    @Binding var isExpanded: Bool
    let onUsePrompt: () -> Void
    let onPrepareMeetupInvite: () -> Void
    let onOpenIcebreaker: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.hasSentMeetupInvite {
                HStack {
                    Label("正向回饋", systemImage: "heart.text.square.fill")
                        .font(.snootsUI(15, weight: .bold))
                    Spacer()
                    Text("雙向互評")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
                .foregroundStyle(SnootsPalette.ink)

                Text("完成線下見面後，為超超留下正向標籤與暖心回饋。雙方評價會分開提交。")
                    .font(.snootsUI(13, weight: .medium))
                    .foregroundStyle(SnootsPalette.secondaryText)

                Label("狗聚結束後，請從狗聚群組進入共同回憶卡片", systemImage: "person.3.fill")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            } else {
                Button { withAnimation(.snappy) { isExpanded.toggle() } } label: {
                    HStack {
                        Label(cardTitle, systemImage: cardSymbol)
                            .font(.snootsUI(15, weight: .bold))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .foregroundStyle(SnootsPalette.ink)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Divider().overlay(SnootsPalette.divider)
                    HStack {
                        Text("目前熟絡度")
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.secondaryText)
                        Spacer()
                        Text("\(store.sparkPoints)%")
                            .font(.snootsUI(20, weight: .bold))
                            .foregroundStyle(SnootsPalette.navigationActive)
                    }

                    if let result = store.dailyIcebreakerResult, store.hasCompletedTodayIcebreaker {
                        Label("今日已完成：\(result.taskTitle)", systemImage: "checkmark.circle.fill")
                            .font(.snootsUI(14, weight: .semibold))
                            .foregroundStyle(SnootsPalette.navigationActive)
                        Text("你和超超的回答相似度 \(result.similarityPercent)% · 熟絡度 +\(result.familiarityPoints)%")
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.secondaryText)
                    } else {
                        Button(action: onOpenIcebreaker) {
                            Label("抽今天的破冰小任務", systemImage: "rectangle.stack.badge.plus")
                        }
                        .font(.snootsUI(14, weight: .semibold))
                        .foregroundStyle(SnootsPalette.navigationActive)
                        .buttonStyle(.plain)
                        .accessibilityHint("每天可完成一張；雙方回答越相近，熟絡度增加越多。")
                    }

                    Text("每天完成一張共同題目；每張 +20% 至 +25%，連續 5 天即可達到 100%。")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)

                    if store.sparkPoints >= 100 {
                        HStack(spacing: 8) {
                            compactActionButton(
                                "發起見面邀請",
                                systemImage: "calendar.badge.plus",
                                action: onPrepareMeetupInvite
                            )
                            compactActionButton(
                                "帶入社交界線提醒",
                                systemImage: "text.bubble.fill",
                                action: onUsePrompt
                            )
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(SnootsPalette.surface.opacity(0.68), in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous)
                .stroke(SnootsPalette.primary.opacity(0.32), lineWidth: 1)
        }
    }

    private var cardTitle: String {
        if store.hasPreparedMeetupInvitation {
            return "\(store.pet.name) 已發起見面邀請"
        }
        if store.sparkPoints >= 100 {
            return "發起見面邀請"
        }
        return store.hasCompletedTodayIcebreaker ? "今日破冰卡已完成" : "今日破冰卡"
    }

    private var cardSymbol: String {
        store.hasPreparedMeetupInvitation ? "calendar.badge.checkmark" : "sparkles"
    }

    @ViewBuilder
    private func compactActionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.snootsUI(12, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(SnootsPalette.primaryTint, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct IcebreakerTask: Identifiable {
    let id: String
    let title: String
    let detail: String
    let photoPickerTitle: String
    let photoPickerHint: String
    let sentMessage: String
    let replyMessage: String

    static let all = [
        IcebreakerTask(
            id: "favorite-toy",
            title: "分享豆花最愛的玩具照片",
            detail: "用一張照片，讓超超與飼主更快認識豆花的日常與個性。",
            photoPickerTitle: "選擇玩具照片",
            photoPickerHint: "從相簿挑選一張照片",
            sentMessage: "我先分享豆花最喜歡的玩具照片！",
            replyMessage: "超超最喜歡的是會發出聲音的小球，期待看看豆花的玩具！"
        ),
        IcebreakerTask(
            id: "favorite-walk",
            title: "分享豆花最喜歡的散步角落",
            detail: "用一張散步照片，讓超超與飼主認識豆花喜歡的步調。",
            photoPickerTitle: "選擇散步照片",
            photoPickerHint: "從相簿挑選一張散步照片",
            sentMessage: "我想分享豆花最喜歡的散步角落！",
            replyMessage: "這裡看起來很舒服，超超也喜歡安靜地散步。"
        ),
        IcebreakerTask(
            id: "relaxed-moment",
            title: "分享豆花放鬆時的照片",
            detail: "讓超超與飼主看看豆花最自在、最像自己的模樣。",
            photoPickerTitle: "選擇日常照片",
            photoPickerHint: "從相簿挑選一張放鬆時的照片",
            sentMessage: "這是豆花最放鬆的時候！",
            replyMessage: "豆花看起來好自在，超超也喜歡安靜地窩著。"
        )
    ]

    static var random: IcebreakerTask { all.randomElement() ?? all[0] }
}

private struct IcebreakerTaskView: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    let language: SnootsLanguage
    let onNavigate: (SnootsRoute) -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var message = ""
    @State private var task = IcebreakerTask.random

    private func drawAnotherTask() {
        let otherTasks = IcebreakerTask.all.filter { $0.id != task.id }
        task = otherTasks.randomElement() ?? task
        selectedPhoto = nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("隨機題庫")
                            .font(.snootsUI(15, weight: .semibold))
                            .foregroundStyle(SnootsPalette.secondaryText)
                        Spacer()
                        Button("換一題", action: drawAnotherTask)
                            .font(.snootsUI(14, weight: .semibold))
                    }
                    Text(task.title)
                        .font(.snootsUI(28, weight: .bold))
                    Text(task.detail)
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: selectedPhoto == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                            .font(.system(size: 36, weight: .semibold))
                        Text(selectedPhoto == nil ? task.photoPickerTitle : "照片已選擇")
                            .font(.snootsUI(28, weight: .bold))
                        Text(selectedPhoto == nil ? task.photoPickerHint : "準備發送給超超")
                            .font(.snootsBody())
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 230)
                    .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous)
                            .stroke(SnootsPalette.primary.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [8]))
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    Text("簡短地說句話吧（選填）")
                        .font(.snootsUI(15, weight: .semibold))
                    TextEditor(text: $message)
                        .font(.snootsBody())
                        .frame(minHeight: 82, maxHeight: 116)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous)
                                .stroke(SnootsPalette.primary.opacity(0.28), lineWidth: 1)
                        }
                }

                Button("發送") {
                    _ = store.completeDailyIcebreaker(answerID: store.dailyIcebreakerTask.options[0].id)
                    store.createMatchChat()
                    let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedMessage.isEmpty {
                        store.sendMatchChatMessage(trimmedMessage)
                    }
                    onNavigate(.chat)
                }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                .disabled(selectedPhoto == nil)
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle("破冰小任務")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DailyIcebreakerTaskView: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    let language: SnootsLanguage
    let onNavigate: (SnootsRoute) -> Void
    @State private var selectedAnswerID: String?

    private var task: DailyIcebreakerTask { store.dailyIcebreakerTask }
    private var result: DailyIcebreakerResult? {
        guard store.hasCompletedTodayIcebreaker,
              let result = store.dailyIcebreakerResult,
              result.taskID == task.id else { return nil }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("今日共同破冰卡", systemImage: "rectangle.stack.fill")
                        .font(.snootsUI(15, weight: .semibold))
                        .foregroundStyle(SnootsPalette.navigationActive)
                    Text("一天一張，和\(candidate.name)回答同一題。")
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(SnootsPalette.ink)
                        .frame(width: 58, height: 58)
                        .background(SnootsPalette.primaryTint, in: Circle())

                    Text(task.title)
                        .font(.snootsCardTitle())
                    Text(task.prompt)
                        .font(.snootsUI(21, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("回答後會揭曉超超的選擇；答案越接近，熟絡度增加越多。")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                if let result {
                    DailyIcebreakerResultCard(result: result, candidate: candidate, petName: store.pet.name)

                    Button("回到聊天室") {
                        onNavigate(.chat)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("豆花的答案")
                            .font(.snootsUI(16, weight: .bold))

                        ForEach(task.options) { option in
                            Button {
                                selectedAnswerID = option.id
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selectedAnswerID == option.id ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedAnswerID == option.id ? SnootsPalette.navigationActive : SnootsPalette.secondaryText)
                                    Text(option.title)
                                        .font(.snootsUI(16, weight: .semibold))
                                    Spacer()
                                }
                                .foregroundStyle(SnootsPalette.ink)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    selectedAnswerID == option.id ? SnootsPalette.primaryTint : SnootsPalette.surface,
                                    in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous)
                                        .stroke(selectedAnswerID == option.id ? SnootsPalette.navigationActive : SnootsPalette.divider, lineWidth: selectedAnswerID == option.id ? 2 : 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button("送出答案並揭曉") {
                        guard let selectedAnswerID else { return }
                        _ = store.completeDailyIcebreaker(answerID: selectedAnswerID)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                    .disabled(selectedAnswerID == nil)
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle("每日破冰卡")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DailyIcebreakerResultCard: View {
    let result: DailyIcebreakerResult
    let candidate: PlaydateCandidate
    let petName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("答案揭曉", systemImage: "party.popper.fill")
                .font(.snootsUI(17, weight: .bold))
                .foregroundStyle(SnootsPalette.navigationActive)

            HStack(spacing: 10) {
                answerColumn(name: petName, answer: result.tofuAnswer.title)
                Image(systemName: "arrow.left.and.right")
                    .foregroundStyle(SnootsPalette.secondaryText)
                answerColumn(name: candidate.name, answer: result.chaoChaoAnswer.title)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("回答相似度")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                    Text("\(result.similarityPercent)%")
                        .font(.snootsUI(28, weight: .bold))
                }
                Spacer()
                Text("熟絡度 +\(result.familiarityPoints)%")
                    .font(.snootsUI(15, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(SnootsPalette.lime, in: Capsule())
            }
        }
        .padding(18)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous)
                .stroke(SnootsPalette.primary.opacity(0.35), lineWidth: 1)
        }
    }

    private func answerColumn(name: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(name)
                .font(.snootsMetadata())
                .foregroundStyle(SnootsPalette.secondaryText)
            Text(answer)
                .font(.snootsUI(14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SnootsPalette.primaryTint.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MeetupSafetyView: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    let language: SnootsLanguage
    let onNavigate: (SnootsRoute) -> Void
    @State private var hasReadBoundaries = false
    @State private var completedChecks: Set<String> = []

    private let checks = [
        "狗狗今天仍然健康",
        "天氣適合外出",
        "牽繩、胸背與名牌齊全",
        "飲水、水碗與拾便袋已備妥",
        "手機有電，且已告知親友時間地點",
        "已知道附近的獸醫院／緊急醫療位置"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("出發前安全確認")
                        .font(.snootsScreenTitle())
                    Text("豆花與超超的社交界線卡")
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }

                BoundaryComparisonCard(candidate: candidate, store: store)

                Toggle("我已充分閱讀並尊重對方的界線 ☑", isOn: $hasReadBoundaries)
                    .font(.snootsUI(15, weight: .semibold))
                    .tint(SnootsPalette.lime)
                    .padding(16)
                    .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))

                Text("見面前 1 分鐘裝備與狀態 Check-in")
                    .font(.snootsSection())
                ForEach(checks, id: \.self) { check in
                    Button {
                        if completedChecks.contains(check) { completedChecks.remove(check) } else { completedChecks.insert(check) }
                    } label: {
                        Label(check, systemImage: completedChecks.contains(check) ? "checkmark.circle.fill" : "circle")
                            .font(.snootsUI(15, weight: .medium))
                            .foregroundStyle(SnootsPalette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button("雙方皆完成 Check-in，出發！") {
                    store.hasAcknowledgedBoundaries = hasReadBoundaries
                    store.completeSafetyCheckIn()
                    onNavigate(.dashboard)
                }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                .disabled(!hasReadBoundaries || completedChecks.count != checks.count)
                .opacity(hasReadBoundaries && completedChecks.count == checks.count ? 1 : 0.45)
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle("見面安全確認")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BoundaryComparisonCard: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore

    private let rows = ["牽繩與外出注意", "身體觸碰與護物", "必要的健康驗證", "緊急聯絡資訊"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("雙方互動界線")
                .font(.snootsSection())
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("項目").font(.snootsMetadata())
                    Text("豆花").font(.snootsMetadata())
                    Text("超超").font(.snootsMetadata())
                }
                ForEach(rows, id: \.self) { row in
                    GridRow {
                        Text(row).font(.snootsMetadata()).foregroundStyle(SnootsPalette.secondaryText)
                        Text(value(for: row, dog: .current)).font(.snootsUI(13, weight: .medium))
                        Text(value(for: row, dog: .candidate)).font(.snootsUI(13, weight: .medium))
                    }
                }
            }
        }
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
    }

    private enum Dog { case current, candidate }

    private func value(for row: String, dog: Dog) -> String {
        switch (row, dog) {
        case ("牽繩與外出注意", .current): store.pet.leashHabit == "尚未填寫" ? "全程牽繩" : store.pet.leashHabit
        case ("牽繩與外出注意", .candidate): "全程牽繩、慢慢靠近"
        case ("身體觸碰與護物", .current): store.pet.touchBoundary == "尚未填寫" ? "避免突然觸碰" : store.pet.touchBoundary
        case ("身體觸碰與護物", .candidate): "不摸頭；食物分開"
        case ("必要的健康驗證", .current): store.pet.vaccineSummary == "尚未填寫" ? "疫苗已驗證" : store.pet.vaccineSummary
        case ("必要的健康驗證", .candidate): candidate.healthSummary
        case ("緊急聯絡資訊", .current): store.pet.emergencyPhone == "尚未填寫" ? "已提供給配對對象" : store.pet.emergencyPhone
        case ("緊急聯絡資訊", .candidate): "已提供給配對對象"
        default: ""
        }
    }
}

private struct OfflineMeetupDashboard: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    let language: SnootsLanguage
    @State private var isShowingExitHelper = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("一對一見面進行中")
                    .font(.snootsScreenTitle())
                Text("用 3 秒確認彼此狗狗目前的狀態。")
                    .font(.snootsBody())
                    .foregroundStyle(SnootsPalette.secondaryText)
                BehaviorLightCard(color: .green, title: "綠燈：可以繼續觀察", details: ["身體放鬆、動作自然", "願意探索環境", "互相忽略也能自在走路"])
                BehaviorLightCard(color: .yellow, title: "黃燈：請暫停並增加距離", details: ["一直打哈欠、舔嘴唇或甩身體", "躲避、尾巴夾緊、身體僵硬", "持續嗅地或吃草來迴避互動"])
                BehaviorLightCard(color: .red, title: "紅燈：立即停止互動並離開", details: ["持續吠叫、衝撞、露齒或低吼", "追逐不願互動的狗", "任一方感到害怕或不安全"])
                Button("優雅退場助手") { isShowingExitHelper = true }
                    .buttonStyle(SecondaryButtonStyle())
                Button("結束一對一見面") { isShowingExitHelper = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle("狗聚儀表板")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingExitHelper) {
            ExitHelperSheet()
                .presentationDetents([.height(300)])
        }
    }
}

private struct GroupMeetupDashboard: View {
    let meetup: UpcomingMeetup
    let store: SnootsStore
    let language: SnootsLanguage
    @State private var isSearchingForNearbyPhones = false
    @State private var isShowingExitConfirmation = false
    @State private var isShowingFinishConfirmation = false
    @State private var isShowingMemories = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("狗聚進行中", systemImage: "pawprint.fill")
                            .font(.snootsChip())
                            .foregroundStyle(SnootsPalette.navigationActive)
                        Spacer()
                        Text(store.hasTemporarilyLeftGroupMeetup ? "已暫離" : "活動範圍內")
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(store.hasTemporarilyLeftGroupMeetup ? SnootsPalette.surface : SnootsPalette.lime, in: Capsule())
                    }
                    Text("現場儀表板")
                        .font(.snootsScreenTitle())
                    Text("一眼掌握狗聚成員狀態，需要時隨時暫離或結束活動。")
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(meetup.localizedTitle(language), systemImage: "calendar")
                    Label(meetup.localizedLocation(language), systemImage: "mappin.and.ellipse")
                }
                .font(.snootsUI(15, weight: .semibold))
                .foregroundStyle(SnootsPalette.ink)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SnootsPalette.ink)
                            .frame(width: 46, height: 46)
                            .background(SnootsPalette.lime, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.hasCompletedGroupMeetupCheckIn ? "手機互碰完成" : "手機互碰簽到")
                                .font(.snootsCardTitle())
                            Text(store.hasCompletedGroupMeetupCheckIn ? "你已加入本次狗聚的現場狀態同步。" : "靠近其他參與者的手機，快速加入現場狀態同步。")
                                .font(.snootsMetadata())
                                .foregroundStyle(SnootsPalette.secondaryText)
                        }
                    }
                    Button {
                        isSearchingForNearbyPhones.toggle()
                        if isSearchingForNearbyPhones {
                            store.completeGroupMeetupCheckIn()
                        }
                    } label: {
                        Label(
                            store.hasCompletedGroupMeetupCheckIn ? "已完成簽到，再次同步" : (isSearchingForNearbyPhones ? "正在尋找附近手機" : "開始手機互碰"),
                            systemImage: isSearchingForNearbyPhones ? "wave.3.right.circle.fill" : "checkmark.shield.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                }
                .padding(16)
                .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("成員狀態")
                            .font(.snootsSection())
                        Spacer()
                        Text("共同任務：安全相處")
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(meetup.participants.enumerated()), id: \.element.id) { index, participant in
                            VStack(alignment: .leading, spacing: 9) {
                                HStack(spacing: 12) {
                                    Image(participant.imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(participant.localizedName(language))
                                            .font(.snootsCardTitle())
                                        Text(participant.breed)
                                            .font(.snootsMetadata())
                                            .foregroundStyle(SnootsPalette.secondaryText)
                                    }
                                    Spacer()
                                    Label(
                                        store.hasCompletedGroupMeetupCheckIn || index < 2 ? "已簽到" : "前往中",
                                        systemImage: store.hasCompletedGroupMeetupCheckIn || index < 2 ? "checkmark.circle.fill" : "clock"
                                    )
                                    .font(.snootsMetadata())
                                    .foregroundStyle(store.hasCompletedGroupMeetupCheckIn || index < 2 ? SnootsPalette.navigationActive : SnootsPalette.secondaryText)
                                }

                                if !participant.safetyTagIDs.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(participant.safetyTagIDs, id: \.self) { tagID in
                                                Text(safetyTagTitle(tagID))
                                                    .font(.snootsMetadata())
                                                    .foregroundStyle(SnootsPalette.ink)
                                                    .padding(.horizontal, 9)
                                                    .padding(.vertical, 5)
                                                    .background(SnootsPalette.butter, in: Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(14)

                            if index < meetup.participants.count - 1 {
                                Divider().padding(.leading, 70)
                            }
                        }
                    }
                    .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                }

                VStack(spacing: 10) {
                    Button("暫離狗聚", role: .destructive) { isShowingExitConfirmation = true }
                        .font(.snootsButton(16))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.buttonRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: SnootsMetrics.buttonRadius, style: .continuous)
                                .stroke(SnootsPalette.divider, lineWidth: 1)
                        }

                    Button("結束狗聚，建立共同回憶") { isShowingFinishConfirmation = true }
                        .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle("現場儀表板")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingMemories) {
            SharedMemoriesView(candidate: store.activeMatchCandidate, store: store, language: language)
        }
        .confirmationDialog("要暫離這場狗聚嗎？", isPresented: $isShowingExitConfirmation, titleVisibility: .visible) {
            Button("確認暫離", role: .destructive) {
                store.temporarilyLeaveGroupMeetup()
                isSearchingForNearbyPhones = false
            }
            Button("繼續參加", role: .cancel) {}
        } message: {
            Text("系統會通知發起人，讓其他成員知道你的狀態。")
        }
        .confirmationDialog("要結束這場狗聚嗎？", isPresented: $isShowingFinishConfirmation, titleVisibility: .visible) {
            Button("結束狗聚並建立共同回憶") {
                store.endGroupMeetup()
                isShowingMemories = true
            }
            Button("繼續參加", role: .cancel) {}
        } message: {
            Text("結束後會進入成員狗狗辨識牆，完成認親才能送出暖心回饋。")
        }
    }

    private func safetyTagTitle(_ tagID: String) -> String {
        switch tagID {
        case "slow-intro": return "保持 2 公尺距離"
        case "leash": return "黃色牽繩"
        case "adult": return "偏好成犬互動"
        default: return "請先查看界線"
        }
    }
}

private struct BehaviorLightCard: View {
    let color: Color
    let title: String
    let details: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.snootsCardTitle())
            ForEach(details, id: \.self) { Label($0, systemImage: "circle.fill").font(.snootsUI(14)) }
        }
        .foregroundStyle(.black)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.72), in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
    }
}

private struct ExitHelperSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let message = "我家狗狗今天似乎有點累／緊張，我們今天先散步到這邊，下次再約喔！"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("優雅退場助手").font(.snootsScreenTitle())
            Text(message).font(.snootsBody())
                .padding(14)
                .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
            Button("複製訊息") { UIPasteboard.general.string = message }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
            Button("關閉") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(22)
    }
}

private struct MemoryDog: Identifiable {
    let id: String
    let name: String
    let owner: String
    let breed: String
    let size: String
    let imageName: String
    let clue: String
}

private struct SharedMemoriesView: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    let language: SnootsLanguage
    @State private var selectedDogID: String?
    @State private var selectedAnswer = ""
    @State private var recognizedDogIDs: Set<String> = []
    @State private var quizStatus: QuizStatus = .idle
    @State private var showHint = false
    @State private var isShowingFeedback = false
    @State private var isShowingReceivedCard = false

    private enum QuizStatus {
        case idle, wrong, correct
    }

    private var memoryDogs: [MemoryDog] {
        [
            MemoryDog(id: "chaochao", name: candidate.name, owner: candidate.owner, breed: candidate.breed, size: candidate.size, imageName: candidate.imageName, clue: "活潑、喜歡平行散步"),
            MemoryDog(id: "mochi", name: "麻糬", owner: "Yuki", breed: "米克斯", size: "中型犬", imageName: "Mochi", clue: "白襪、很會打招呼"),
            MemoryDog(id: "pudding", name: "布丁", owner: "Mina", breed: "貴賓犬", size: "小型犬", imageName: "Pudding", clue: "捲毛、散步很穩定"),
            MemoryDog(id: "nori", name: "Nori", owner: "Emma", breed: "柯基", size: "中型犬", imageName: "Nori", clue: "短腿、喜歡嗅聞"),
        ]
    }

    private var answerOptions: [String] { memoryDogs.map(\.name) }
    private var selectedDog: MemoryDog? { memoryDogs.first { $0.id == selectedDogID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("狗聚共同回憶卡片 · 01")
                        .font(.snootsChip())
                        .foregroundStyle(SnootsPalette.navigationActive)
                    Text("今天狗聚認識了哪些新朋友？試著認出牠們吧！")
                        .font(.snootsScreenTitle())
                    Text("狗聚結束後的小小記憶驗證。答對某一隻，就能解鎖給牠與飼主的暖心回饋。")
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }

                HStack {
                    Label("本次狗聚的成員狗狗", systemImage: "pawprint.fill")
                        .font(.snootsCardTitle())
                    Spacer()
                    Text("\(recognizedDogIDs.count) / \(memoryDogs.count) 已認出")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(memoryDogs) { dog in
                        let isRecognized = recognizedDogIDs.contains(dog.id)
                        Button {
                            selectedDogID = dog.id
                            selectedAnswer = ""
                            showHint = false
                            quizStatus = isRecognized ? .correct : .idle
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .bottomLeading) {
                                    Image(dog.imageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 124)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                    LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
                                    HStack(alignment: .bottom) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(isRecognized ? dog.name : "名字待確認")
                                                .font(.snootsUI(14, weight: .bold))
                                                .foregroundStyle(.white)
                                            Text("\(dog.breed) · \(dog.size)")
                                                .font(.snootsMetadata())
                                                .foregroundStyle(.white.opacity(0.86))
                                        }
                                        Spacer()
                                        Image(systemName: isRecognized ? "checkmark.seal.fill" : "questionmark.circle.fill")
                                            .foregroundStyle(isRecognized ? SnootsPalette.lime : .white)
                                    }
                                    .padding(10)
                                }
                                Text(isRecognized ? "認親成功！" : dog.clue)
                                    .font(.snootsMetadata())
                                    .foregroundStyle(isRecognized ? SnootsPalette.navigationActive : SnootsPalette.secondaryText)
                                    .padding(.horizontal, 10)
                                    .padding(.bottom, 10)
                                    .lineLimit(1)
                            }
                            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(isRecognized ? SnootsPalette.lime : SnootsPalette.divider, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let dog = selectedDog, !recognizedDogIDs.contains(dog.id) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("記憶小測驗", systemImage: "sparkles")
                            .font(.snootsCardTitle())
                        Text("這隻\(dog.clue)的\(dog.breed)叫什麼名字？")
                            .font(.snootsBody())
                        Picker("選擇名字", selection: $selectedAnswer) {
                            Text("請選擇狗狗名字").tag("")
                            ForEach(answerOptions, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Button("確認答案") {
                            if selectedAnswer == dog.name {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    quizStatus = .correct
                                    recognizedDogIDs.insert(dog.id)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { isShowingFeedback = true }
                            } else {
                                withAnimation(.easeInOut) { quizStatus = .wrong }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                        .disabled(selectedAnswer.isEmpty)
                        if quizStatus == .wrong {
                            VStack(alignment: .leading, spacing: 7) {
                                Label("再想一下，沒關係！", systemImage: "heart.fill")
                                    .font(.snootsUI(14, weight: .bold))
                                    .foregroundStyle(SnootsPalette.alert)
                                if showHint {
                                    Text("小提示：\(dog.clue)，牠的名字是今天狗聚簽到時聽到的名字。")
                                        .font(.snootsMetadata())
                                        .foregroundStyle(SnootsPalette.secondaryText)
                                } else {
                                    Button("查看小提示") { showHint = true }
                                        .font(.snootsUI(13, weight: .semibold))
                                        .foregroundStyle(SnootsPalette.navigationActive)
                                }
                                Button("先跳過") {
                                    selectedDogID = nil
                                    selectedAnswer = ""
                                    quizStatus = .idle
                                    showHint = false
                                }
                                .font(.snootsUI(13, weight: .semibold))
                                .foregroundStyle(SnootsPalette.secondaryText)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(16)
                    .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                }

                if let dog = selectedDog, recognizedDogIDs.contains(dog.id) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("認親成功！", systemImage: "party.popper.fill")
                            .font(.snootsSection())
                            .foregroundStyle(SnootsPalette.navigationActive)
                        Text("你成功認出了\(dog.name)！現在可以把今天的好，送給\(dog.name)與飼主。")
                            .font(.snootsBody())
                            .foregroundStyle(SnootsPalette.secondaryText)
                        Button("前往\(dog.name)的回饋頁面") { isShowingFeedback = true }
                            .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                    }
                    .padding(16)
                    .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                }

                if store.hasSentWarmFeedback {
                    Button { isShowingReceivedCard = true } label: {
                        Label("查看收到的暖心回饋卡片", systemImage: "bell.badge.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationTitle("共同回憶")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingFeedback) {
            if let dog = selectedDog {
                PostEventFeedbackSheet(dog: dog, store: store, language: language)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: isShowingFeedback) { _, isPresented in
            if !isPresented && store.hasSentWarmFeedback { isShowingReceivedCard = true }
        }
        .sheet(isPresented: $isShowingReceivedCard) {
            WarmFeedbackCardView(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct WarmFeedbackCardView: View {
    let store: SnootsStore
    @Environment(\.dismiss) private var dismiss

    private var shareText: String {
        let tags = store.lastWarmFeedbackTags.isEmpty ? "今天的暖心回饋" : store.lastWarmFeedbackTags.joined(separator: "、")
        return "\(store.lastWarmFeedbackRecipientName)有話想對你說！\n\n豆花與主人送來一張暖心回饋卡：\n\(store.lastWarmFeedbackNote.isEmpty ? "今天謝謝你來跟我們玩！" : store.lastWarmFeedbackNote)\n\n\(tags)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.title2)
                            .foregroundStyle(SnootsPalette.alert)
                            .frame(width: 48, height: 48)
                            .background(SnootsPalette.primaryTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("暖心回饋卡片通知")
                                .font(.snootsChip())
                                .foregroundStyle(SnootsPalette.alert)
                            Text("\(store.lastWarmFeedbackRecipientName)有話想對你說！")
                                .font(.snootsScreenTitle())
                        }
                    }
                    Text("你在今天的相遇裡，收到了一份溫柔的回饋。")
                        .font(.snootsBody())
                        .foregroundStyle(SnootsPalette.secondaryText)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image("Tofu")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 42, height: 42)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("來自豆花與主人，寫給\(store.lastWarmFeedbackRecipientName)")
                                    .font(.snootsCardTitle())
                                Text("今天的相遇 · 只分享給你")
                                    .font(.snootsMetadata())
                                    .foregroundStyle(SnootsPalette.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "heart.fill")
                                .foregroundStyle(SnootsPalette.alert)
                        }
                        HStack(spacing: 6) {
                            Image(store.lastWarmFeedbackRecipientImageName)
                                .resizable()
                                .scaledToFill()
                            Image("Tofu")
                                .resizable()
                                .scaledToFill()
                        }
                        .frame(height: 190)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text("給\(store.lastWarmFeedbackRecipientName)與飼主的一句話")
                            .font(.snootsChip())
                            .foregroundStyle(SnootsPalette.secondaryText)
                        Text("「\(store.lastWarmFeedbackNote.isEmpty ? "今天謝謝你來跟我們玩！" : store.lastWarmFeedbackNote)」")
                            .font(.snootsBody())
                        if !store.lastWarmFeedbackTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(store.lastWarmFeedbackTags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.snootsChip())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(SnootsPalette.primaryTint, in: Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
                    ShareLink(item: shareText) {
                        Label("分享至社群", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lime))
                }
                .padding(18)
            }
            .background(SnootsPalette.canvas)
            .navigationTitle("收到的卡片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct PhotoTile: View {
    let imageName: String
    let label: String
    let language: SnootsLanguage
    var photoData: Data? = nil
    var showsLabel = true

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Group {
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image).resizable()
                    } else {
                        Image(imageName).resizable()
                    }
                }
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
    static let meetupCard = Color(light: 0xDEF17B, dark: 0x39412B)
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
    static let safetyTint = Color(light: 0xFFF4C9, dark: 0x514A2B)
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

enum SnootsMetrics {
    static let buttonRadius: CGFloat = 20
    static let cardRadius: CGFloat = 28
    static let inputRadius: CGFloat = 18
    static let profileImageRadius: CGFloat = 24
}

extension View {
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
