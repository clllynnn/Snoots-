import MapKit
import SwiftUI

struct ContentView: View {
    let store: SnootsStore
    @State private var selectedTab: AppTab = .match
    @State private var presentedSheet: SnootsSheet?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { PlaydatesView(store: store, presentedSheet: $presentedSheet) }
                .tabItem { Label(AppTab.match.title, systemImage: AppTab.match.symbol) }
                .tag(AppTab.match)

            NavigationStack { MapsView(store: store, presentedSheet: $presentedSheet) }
                .tabItem { Label(AppTab.maps.title, systemImage: AppTab.maps.symbol) }
                .tag(AppTab.maps)

            NavigationStack { FeedView(store: store) }
                .tabItem { Label(AppTab.feed.title, systemImage: AppTab.feed.symbol) }
                .tag(AppTab.feed)

            NavigationStack { ProfileView(store: store, presentedSheet: $presentedSheet) }
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.symbol) }
                .tag(AppTab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SnootsBottomNavigation(selectedTab: $selectedTab)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .match:
                MatchSheet(candidate: store.playdate, store: store)
            case .emergency:
                NavigationStack { CareView(store: store) }
            case .place(let placeID):
                if let place = store.place(id: placeID) {
                    PlaceDetailSheet(place: place, store: store)
                }
            }
        }
    }
}

struct FeedView: View {
    let store: SnootsStore
    @State private var selectedSection: FeedSection = .feed

    private var visiblePosts: [SocialPost] {
        store.socialPosts.filter { selectedSection == .feed ? $0.kind == .photo : $0.kind == .discussion }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Feed")
                            .font(.snootsScreenTitle())
                        Text("Your Taipei dog community.")
                            .font(.snootsUI(15))
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "bell.badge.fill")
                        .font(.title3)
                        .foregroundStyle(SnootsPalette.ink)
                        .frame(width: 44, height: 44)
                        .background(SnootsPalette.primary, in: Circle())
                        .accessibilityLabel("Notifications")
                }

                TrustSummaryCard(profile: store.profile)

                Picker("Community section", selection: $selectedSection) {
                    ForEach(FeedSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text(selectedSection.heading)
                        .font(.snootsSection())
                    Spacer()
                    Label("Nearby", systemImage: "location.fill")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.deepLilac)
                }

                ForEach(visiblePosts) { post in
                    switch post.kind {
                    case .photo:
                        PhotoPostCard(post: post)
                    case .discussion:
                        DiscussionCard(post: post)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private enum FeedSection: String, CaseIterable, Identifiable {
    case feed, forum

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var heading: String { self == .feed ? "From your community" : "Questions for the community" }
}

private struct TrustSummaryCard: View {
    let profile: ParentProfile

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(SnootsPalette.ink)
                .frame(width: 48, height: 48)
                .background(SnootsPalette.lime, in: Circle())
                .accessibilityLabel("Verified trust profile")
            VStack(alignment: .leading, spacing: 3) {
                Text("Trust profile \(profile.trustScore)")
                    .font(.snootsCardTitle())
                Text("ID, vet record and behavior card verified")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(SnootsPalette.ink.opacity(0.55))
        }
        .padding(14)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous).stroke(SnootsPalette.lime, lineWidth: 2) }
        .snootsCardShadow()
    }
}

private struct PhotoPostCard: View {
    let post: SocialPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PostAuthorRow(post: post)
            if let photoName = post.photoName {
                PhotoTile(imageName: photoName, label: post.petName)
                    .frame(height: 220)
            }
            Text(post.body)
                .font(.snootsBody())
            DeclarationChips(labels: post.declarations, tint: SnootsPalette.softPink)
            HStack(spacing: 18) {
                Label("\(post.likes)", systemImage: "heart")
                Label("\(post.comments)", systemImage: "bubble.right")
                Spacer()
                Image(systemName: "paperplane")
                    .accessibilityLabel("Share post")
            }
            .font(.snootsUI(14, weight: .medium))
            .foregroundStyle(SnootsPalette.secondaryText)
        }
        .padding(14)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

private struct DiscussionCard: View {
    let post: SocialPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Community question", systemImage: "text.bubble.fill")
                    .font(.snootsChip())
                    .foregroundStyle(SnootsPalette.deepLilac)
                Spacer()
                Text(post.timeAgo)
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            Text(post.body)
                .font(.snootsCardTitle())
            DeclarationChips(labels: post.declarations, tint: SnootsPalette.butter)
            Label("\(post.comments) trusted replies", systemImage: "checkmark.message.fill")
                .font(.snootsUI(14, weight: .semibold))
                .foregroundStyle(SnootsPalette.pink)
        }
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous).stroke(SnootsPalette.lavender.opacity(0.35), lineWidth: 1) }
    }
}

private struct PostAuthorRow: View {
    let post: SocialPost

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(SnootsPalette.ink)
                .frame(width: 38, height: 38)
                .background(SnootsPalette.butter, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.owner).font(.snootsUI(14, weight: .semibold))
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(SnootsPalette.lilac)
                        .accessibilityLabel("Verified parent")
                }
                Text("with \(post.petName) · \(post.timeAgo)")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            Spacer()
            Image(systemName: "ellipsis")
                .foregroundStyle(SnootsPalette.secondaryText)
                .accessibilityLabel("Post options")
        }
    }
}

struct PlaydatesView: View {
    let store: SnootsStore
    @Binding var presentedSheet: SnootsSheet?
    @State private var isPassed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Match").font(.snootsScreenTitle())
                        Text("Compatibility before chemistry.")
                            .font(.snootsBody())
                            .foregroundStyle(SnootsPalette.secondaryText)
                    }
                    Spacer()
                    Label("2 km", systemImage: "location.fill")
                        .font(.snootsChip())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(SnootsPalette.lime, in: Capsule())
                }

                if store.isMatched {
                    MatchedBanner(candidate: store.playdate)
                } else if isPassed {
                    ContentUnavailableView("More checked matches nearby", systemImage: "pawprint.fill", description: Text("Mochi is still available for a leashed hello."))
                    Button("Revisit Mochi") { isPassed = false }
                        .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.pink))
                } else {
                    MatchProfileCard(candidate: store.playdate)
                    HStack(spacing: 24) {
                        Button { isPassed = true } label: {
                            Image(systemName: "xmark").frame(width: 58, height: 58)
                        }
                        .buttonStyle(CircleActionStyle(fill: SnootsPalette.primary, icon: SnootsPalette.ink))
                        .accessibilityLabel("Pass on Mochi")

                        Button { presentedSheet = .match } label: {
                            Image(systemName: "heart.fill").frame(width: 58, height: 58)
                        }
                        .buttonStyle(CircleActionStyle(fill: SnootsPalette.lavender, icon: .white))
                        .accessibilityLabel("Propose a match with Mochi")
                    }
                    .frame(maxWidth: .infinity)
                    Text("Pass · propose a leashed hello")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct MatchProfileCard: View {
    let candidate: PlaydateCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhotoTile(imageName: candidate.imageName, label: "Available now")
                .frame(height: 292)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(candidate.name), \(candidate.age)")
                        .font(.snootsScreenTitle())
                    Text("with \(candidate.owner) · \(candidate.distance)")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
                DeclarationChips(labels: candidate.compatibility, tint: SnootsPalette.primaryTint)
                Divider().overlay(SnootsPalette.divider)
                Label(candidate.accountability, systemImage: "checkmark.shield.fill")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.lavender)
                Text(candidate.intro)
                    .font(.snootsBody())
            }
            .padding(16)
        }
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

private struct MatchedBanner: View {
    let candidate: PlaydateCandidate

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(SnootsPalette.pink)
            Text("It’s a careful match!").font(.snootsScreenTitle())
            Text("You and \(candidate.owner) agreed to a quiet, leashed first hello.")
                .font(.snootsBody())
                .multilineTextAlignment(.center)
                .foregroundStyle(SnootsPalette.secondaryText)
            Label("Shared behavior cards", systemImage: "checkmark.seal.fill")
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Emergency guidance").font(.snootsScreenTitle())
                        Text("Stay with your pet. Keep it simple.")
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

                Label("DEMO GUIDANCE ONLY · NOT CLINICAL TRIAGE", systemImage: "info.circle.fill")
                    .font(.snootsChip())
                    .foregroundStyle(SnootsPalette.alert)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .background(SnootsPalette.alert.opacity(0.09), in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))

                CareProgressCard(step: store.currentCareStep, index: store.careStepIndex, total: store.careSteps.count)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Critical symptoms noted").font(.snootsCardTitle())
                    DeclarationChips(labels: store.criticalSymptoms, tint: SnootsPalette.softPink)
                }
                .padding(16)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                ClinicCard(clinic: store.clinic)

                Button(store.careStepIndex == store.careSteps.count - 1 ? "Demo handoff complete" : "Next scripted step") {
                    store.advanceCareStep()
                }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.careBlue))
                .disabled(store.careStepIndex == store.careSteps.count - 1)

                Text("This prototype demonstrates an in-transit handoff flow. Contact local emergency services or a licensed clinic for real medical decisions.")
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct CareProgressCard: View {
    let step: CareStep
    let index: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("IN TRANSIT · STEP \(index + 1) OF \(total)")
                    .font(.snootsChip())
                    .foregroundStyle(.white.opacity(0.86))
                Spacer()
                Image(systemName: step.symbol)
                    .font(.title2)
                    .foregroundStyle(SnootsPalette.lime)
            }
            Text(step.title).font(.snootsCardTitle())
            Text(step.instruction).font(.snootsBody())
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { item in
                    Capsule().fill(item <= index ? SnootsPalette.lime : .white.opacity(0.28)).frame(height: 6)
                }
            }
        }
        .padding(18)
        .foregroundStyle(.white)
        .background(SnootsPalette.lavender, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

private struct ClinicCard: View {
    let clinic: Clinic

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.title)
                    .foregroundStyle(SnootsPalette.careBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Destination clinic").font(.snootsMetadata()).foregroundStyle(SnootsPalette.secondaryText)
                    Text(clinic.name).font(.snootsCardTitle())
                }
                Spacer()
                Text(clinic.eta).font(.snootsUI(15, weight: .semibold)).foregroundStyle(SnootsPalette.careBlue)
            }
            Divider().overlay(SnootsPalette.divider)
            Label(clinic.address, systemImage: "location.fill")
            Label(clinic.handoff, systemImage: "doc.text.fill")
        }
        .font(.snootsUI(14))
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

struct MapsView: View {
    let store: SnootsStore
    @Binding var presentedSheet: SnootsSheet?
    @State private var selectedCategory: MapPlace.Category?

    private var visibleMapPlaces: [MapPlace] {
        store.mapPlaces.places.filter { selectedCategory == nil || $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maps").font(.snootsScreenTitle())
                        Text("Dog-friendly places, with the details that matter.")
                            .font(.snootsBody())
                            .foregroundStyle(SnootsPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                NeighborhoodMapCard(places: visibleMapPlaces, isResolving: store.mapPlaces.isResolvingLocations)
                EmergencyMapCard(clinic: store.clinic) { presentedSheet = .emergency }

                PlaceCategoryFilter(selectedCategory: $selectedCategory)

                HStack(alignment: .firstTextBaseline) {
                    Text("Nearby places").font(.snootsSection())
                    Spacer()
                    Label("\(visibleMapPlaces.count) found", systemImage: "mappin.and.ellipse")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                        .accessibilityLabel("\(visibleMapPlaces.count) nearby places found")
                }
                if let errorMessage = store.mapPlaces.errorMessage {
                    ContentUnavailableView("Maps database unavailable", systemImage: "externaldrive.badge.exclamationmark", description: Text(errorMessage))
                } else {
                    ForEach(visibleMapPlaces) { place in
                        DatabasePlaceRow(place: place)
                    }
                }

                Text("Featured nearby").font(.snootsSection())

                ForEach(store.places) { place in
                    PlaceRow(place: place, isSaved: store.isSaved(place), onOpen: { presentedSheet = .place(place.id) }, onToggleSave: { store.toggleSaved(place) })
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.mapPlaces.resolveLocationsIfNeeded()
        }
    }
}

private struct PlaceCategoryFilter: View {
    @Binding var selectedCategory: MapPlace.Category?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filter places").font(.snootsSection())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    PlaceFilterButton(
                        title: "All",
                        symbol: "square.grid.2x2.fill",
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(MapPlace.Category.allCases) { category in
                        PlaceFilterButton(
                            title: category.title,
                            symbol: category.symbol,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter nearby places")
    }
}

private struct PlaceFilterButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.snootsUI(15, weight: .semibold))
                .foregroundStyle(SnootsPalette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(
                    isSelected ? SnootsPalette.primary : SnootsPalette.surface,
                    in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous)
                        .stroke(isSelected ? SnootsPalette.ink : SnootsPalette.primary, lineWidth: isSelected ? 2 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Shows only \(title.lowercased()) places")
    }
}

private struct EmergencyMapCard: View {
    let clinic: Clinic
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "cross.case.fill")
                    .font(.title2)
                    .foregroundStyle(SnootsPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(SnootsPalette.primary, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Emergency guidance")
                        .font(.snootsCardTitle())
                    Text("\(clinic.name) · \(clinic.eta)")
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                }
                Spacer()
                Text("Open now")
                    .font(.snootsChip())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(SnootsPalette.primary, in: Capsule())
            }
            Button("Find emergency care", action: onOpen)
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.primary))
        }
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous)
                .stroke(SnootsPalette.primary, lineWidth: 2)
        }
        .snootsCardShadow()
    }
}

private struct NeighborhoodMapCard: View {
    let places: [MapPlace]
    let isResolving: Bool
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654),
            span: MKCoordinateSpan(latitudeDelta: 0.16, longitudeDelta: 0.16)
        )
    )

    var body: some View {
        ZStack {
            Map(position: $position) {
                ForEach(places) { place in
                    if let coordinate = place.coordinate {
                        Marker(place.name, systemImage: place.category.symbol, coordinate: coordinate)
                            .tint(SnootsPalette.lavender)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Map of nearby dog-friendly places in Taipei")
            .accessibilityValue(isResolving ? "Locating places" : "\(places.filter { $0.coordinate != nil }.count) places mapped")
            VStack {
                Spacer()
                HStack {
                    Label(isResolving ? "Locating places…" : "\(places.filter { $0.coordinate != nil }.count) mapped", systemImage: "mappin.and.ellipse")
                    Spacer()
                    Text("Taipei")
                }
                .font(.snootsChip())
                .padding(12)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
            }
            .padding(12)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

private struct DatabasePlaceRow: View {
    let place: MapPlace
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: place.category.symbol)
                .font(.title3)
                .foregroundStyle(SnootsPalette.ink)
                .frame(width: 40, height: 40)
                .background(SnootsPalette.primaryTint, in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(place.name).font(.snootsCardTitle())
                Label(place.category.title, systemImage: place.category.symbol)
                    .font(.snootsMetadata())
                    .foregroundStyle(SnootsPalette.secondaryText)
                if !place.subtitle.isEmpty {
                    Text(place.subtitle)
                        .font(.snootsMetadata())
                        .foregroundStyle(SnootsPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let appleMapsURL = place.appleMapsURL {
                Button {
                    openURL(appleMapsURL)
                } label: {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.bold))
                        .foregroundStyle(SnootsPalette.ink)
                        .frame(width: 44, height: 44)
                        .background(SnootsPalette.primary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Get directions to \(place.name) in Apple Maps")
                .accessibilityHint("Opens Apple Maps")
            }
        }
        .padding(14)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }

}

private struct PlaceRow: View {
    let place: Place
    let isSaved: Bool
    let onOpen: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 12) {
                    Image(place.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 82, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.profileImageRadius, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.name).font(.snootsCardTitle()).foregroundStyle(SnootsPalette.ink)
                        Text("\(place.category) · \(place.walk)").font(.snootsMetadata()).foregroundStyle(SnootsPalette.secondaryText)
                        DeclarationChips(labels: Array(place.rules.prefix(3)).map(\.shortLabel), tint: SnootsPalette.butter)
                        Text("Verified \(place.verified)").font(.snootsMetadata()).foregroundStyle(SnootsPalette.deepLilac)
                    }
                }
            }
            .buttonStyle(.plain)
            Button(action: onToggleSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(SnootsPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(SnootsPalette.primaryTint, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "Remove \(place.name) from saved places" : "Save \(place.name)")
        }
        .padding(12)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))
        .snootsCardShadow()
    }
}

struct PlaceDetailSheet: View {
    let place: Place
    let store: SnootsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PhotoTile(imageName: place.imageName, label: "Rules verified")
                        .frame(height: 210)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name).font(.snootsScreenTitle())
                        Text("\(place.category) · \(place.walk)").font(.snootsBody()).foregroundStyle(SnootsPalette.secondaryText)
                    }
                    Text("Before you go").font(.snootsSection())
                    ForEach(place.rules) { rule in
                        Label(rule.label, systemImage: rule.symbol)
                            .font(.snootsUI(15, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(SnootsPalette.canvas, in: RoundedRectangle(cornerRadius: SnootsMetrics.inputRadius, style: .continuous))
                    }
                    Label("Rules confirmed \(place.verified)", systemImage: "checkmark.seal.fill")
                        .font(.snootsUI(14, weight: .semibold))
                        .foregroundStyle(SnootsPalette.deepLilac)
                    Button(store.isSaved(place) ? "Saved for later" : "Save place") { store.toggleSaved(place) }
                        .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.pink))
                }
                .padding(18)
            }
            .navigationTitle("Place details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.snootsUI(15, weight: .semibold))
                }
            }
        }
    }
}

struct ProfileView: View {
    let store: SnootsStore
    @Binding var presentedSheet: SnootsSheet?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Profile").font(.snootsScreenTitle())
                        Text("Your dog’s trusted details.").font(.snootsBody()).foregroundStyle(SnootsPalette.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(SnootsPalette.surface, in: Circle())
                        .accessibilityLabel("Profile settings")
                }

                HStack(spacing: 14) {
                    PhotoTile(imageName: store.pet.imageName, label: store.pet.name)
                        .frame(width: 104, height: 104)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.profile.name).font(.snootsScreenTitle())
                        Text("with \(store.pet.name)").font(.snootsBody()).foregroundStyle(SnootsPalette.secondaryText)
                        Label(store.profile.neighborhood, systemImage: "location.fill")
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.deepLilac)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                TrustSummaryCard(profile: store.profile)

                VStack(alignment: .leading, spacing: 12) {
                    Text("\(store.pet.name)’s play card").font(.snootsSection())
                    Text(store.pet.summary).font(.snootsBody()).foregroundStyle(SnootsPalette.secondaryText)
                    DeclarationChips(labels: store.pet.traits, tint: SnootsPalette.butter)
                    Label(store.pet.healthStatus, systemImage: "checkmark.shield.fill")
                        .font(.snootsUI(14, weight: .semibold))
                        .foregroundStyle(SnootsPalette.deepLilac)
                }
                .padding(16)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: SnootsMetrics.cardRadius, style: .continuous))

                if !store.savedPlaces.isEmpty {
                    Text("Saved places").font(.snootsSection())
                    ForEach(store.savedPlaces) { place in
                        Button { presentedSheet = .place(place.id) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.name).font(.snootsCardTitle())
                                    Text("\(place.category) · \(place.walk)").font(.snootsMetadata())
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
                    }
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct MatchSheet: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(SnootsPalette.pink)
                .frame(width: 112, height: 112)
                .background(SnootsPalette.softPink, in: Circle())
            Text("Propose a safe hello?").font(.snootsScreenTitle())
            Text("You’ll both see verified behavior cards before the match is confirmed.")
                .font(.snootsBody())
                .multilineTextAlignment(.center)
                .foregroundStyle(SnootsPalette.secondaryText)
                .padding(.horizontal, 26)
            Button("Match with \(candidate.name)") {
                store.isMatched = true
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.pink))
            Button("Not yet") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
            Spacer()
        }
        .padding(22)
    }
}

private struct PhotoTile: View {
    let imageName: String
    let label: String

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
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
        .clipShape(RoundedRectangle(cornerRadius: SnootsMetrics.profileImageRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo of \(label)")
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

private struct CircleActionStyle: ButtonStyle {
    let fill: Color
    let icon: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .foregroundStyle(icon)
            .background(fill.opacity(configuration.isPressed ? 0.75 : 1), in: Circle())
            .overlay(Circle().stroke(SnootsPalette.ink, lineWidth: 2))
            .shadow(color: .black.opacity(0.08), radius: 20, y: 6)
    }
}

enum SnootsPalette {
    static let background = Color(hex: 0xF7F7F4)
    static let card = Color.white
    static let ink = Color(hex: 0x222222)
    static let inactive = Color(hex: 0x888888)
    static let secondaryText = Color(hex: 0x666666)
    static let placeholder = Color(hex: 0xA3A3A3)
    static let divider = Color(hex: 0xECECEC)
    static let primary = Color(hex: 0xD8FF45)
    static let primaryTint = primary.opacity(0.32)
    static let lavender = Color(hex: 0xB88EFF)
    static let lavenderTint = lavender.opacity(0.22)

    static let canvas = background
    static let surface = card
    static let lime = primary
    static let pink = primary
    static let softPink = primaryTint
    static let lilac = lavender
    static let deepLilac = ink
    static let sky = lavender
    static let careBlue = primary
    static let careTint = lavenderTint
    static let butter = primaryTint
    static let alert = ink
}

private extension Color {
    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
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

    static func snootsScreenTitle() -> Font { snootsHeading(34) }
    static func snootsSection() -> Font { snootsHeading(20) }
    static func snootsCardTitle() -> Font { snootsHeading(18) }
    static func snootsUI(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func snootsBody() -> Font { snootsUI(16) }
    static func snootsMetadata() -> Font { snootsUI(12, weight: .medium) }
    static func snootsChip() -> Font { snootsUI(12, weight: .medium) }
    static func snootsButton(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}
