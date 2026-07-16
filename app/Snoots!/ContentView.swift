import MapKit
import SwiftUI

struct ContentView: View {
    let store: SnootsStore
    @State private var selectedTab: AppTab = .match
    @State private var presentedSheet: SnootsSheet?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { PlaydatesView(store: store, presentedSheet: $presentedSheet) }
                .tabItem { Label("Match", systemImage: "heart.fill").font(.snootsUI(11, weight: .medium)) }
                .tag(AppTab.match)

            NavigationStack { MapsView(store: store, presentedSheet: $presentedSheet) }
                .tabItem { Label("Maps", systemImage: "map.fill").font(.snootsUI(11, weight: .medium)) }
                .tag(AppTab.maps)

            NavigationStack { FeedView(store: store) }
                .tabItem { Label("Feed", systemImage: "bubble.left.and.bubble.right.fill").font(.snootsUI(11, weight: .medium)) }
                .tag(AppTab.feed)

            NavigationStack { ProfileView(store: store, presentedSheet: $presentedSheet) }
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill").font(.snootsUI(11, weight: .medium)) }
                .tag(AppTab.profile)
        }
        .tint(SnootsPalette.lime)
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

private enum AppTab: Hashable {
    case match, maps, feed, profile
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
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "bell.badge.fill")
                        .font(.title3)
                        .foregroundStyle(SnootsPalette.pink)
                        .frame(width: 44, height: 44)
                        .background(SnootsPalette.softPink, in: Circle())
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
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(SnootsPalette.ink.opacity(0.55))
        }
        .padding(14)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(SnootsPalette.lime, lineWidth: 2) }
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
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
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
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
                    .foregroundStyle(.secondary)
            }
            Text(post.body)
                .font(.snootsCardTitle())
            DeclarationChips(labels: post.declarations, tint: SnootsPalette.butter)
            Label("\(post.comments) trusted replies", systemImage: "checkmark.message.fill")
                .font(.snootsUI(14, weight: .semibold))
                .foregroundStyle(SnootsPalette.pink)
        }
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(SnootsPalette.lilac.opacity(0.35), lineWidth: 1) }
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
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
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
                    HStack(spacing: 14) {
                        Button { isPassed = true } label: {
                            Image(systemName: "xmark").frame(width: 58, height: 58)
                        }
                        .buttonStyle(CircleActionStyle(fill: SnootsPalette.surface, icon: SnootsPalette.pink))
                        .accessibilityLabel("Pass on Mochi")

                        Button { presentedSheet = .match } label: {
                            Image(systemName: "heart.fill").frame(width: 70, height: 70)
                        }
                        .buttonStyle(CircleActionStyle(fill: SnootsPalette.pink, icon: .white))
                        .accessibilityLabel("Propose a match with Mochi")

                        Button { } label: {
                            Image(systemName: "bookmark.fill").frame(width: 58, height: 58)
                        }
                        .buttonStyle(CircleActionStyle(fill: SnootsPalette.surface, icon: SnootsPalette.deepLilac))
                        .accessibilityLabel("Save Mochi")
                    }
                    .frame(maxWidth: .infinity)
                    Text("Pass · propose a leashed hello · save for later")
                        .font(.snootsMetadata())
                        .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 14) {
            PhotoTile(imageName: candidate.imageName, label: "Available now")
                .frame(height: 292)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(candidate.name), \(candidate.age)")
                    .font(.snootsScreenTitle())
                Text("with \(candidate.owner) · \(candidate.distance)")
                    .font(.snootsMetadata())
                    .foregroundStyle(.secondary)
            }
            DeclarationChips(labels: candidate.compatibility, tint: SnootsPalette.softPink)
            Divider()
            Label(candidate.accountability, systemImage: "checkmark.shield.fill")
                .font(.snootsMetadata())
                .foregroundStyle(SnootsPalette.deepLilac)
            Text(candidate.intro)
                .font(.snootsBody())
        }
        .padding(12)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
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
                .foregroundStyle(.secondary)
            Label("Shared behavior cards", systemImage: "checkmark.seal.fill")
                .font(.snootsUI(15, weight: .semibold))
                .foregroundStyle(SnootsPalette.deepLilac)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "cross.case.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(SnootsPalette.careBlue, in: Circle())
                }

                Label("DEMO GUIDANCE ONLY · NOT CLINICAL TRIAGE", systemImage: "info.circle.fill")
                    .font(.snootsChip())
                    .foregroundStyle(SnootsPalette.alert)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SnootsPalette.alert.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                CareProgressCard(step: store.currentCareStep, index: store.careStepIndex, total: store.careSteps.count)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Critical symptoms noted").font(.snootsCardTitle())
                    DeclarationChips(labels: store.criticalSymptoms, tint: SnootsPalette.softPink)
                }
                .padding(16)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                ClinicCard(clinic: store.clinic)

                Button(store.careStepIndex == store.careSteps.count - 1 ? "Demo handoff complete" : "Next scripted step") {
                    store.advanceCareStep()
                }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.careBlue))
                .disabled(store.careStepIndex == store.careSteps.count - 1)

                Text("This prototype demonstrates an in-transit handoff flow. Contact local emergency services or a licensed clinic for real medical decisions.")
                    .font(.snootsMetadata())
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(SnootsPalette.careBlue)
                Spacer()
                Image(systemName: step.symbol)
                    .font(.title2)
                    .foregroundStyle(SnootsPalette.careBlue)
            }
            Text(step.title).font(.snootsCardTitle())
            Text(step.instruction).font(.snootsBody())
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { item in
                    Capsule().fill(item <= index ? SnootsPalette.careBlue : SnootsPalette.softPink).frame(height: 6)
                }
            }
        }
        .padding(18)
        .background(SnootsPalette.careTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    Text("Destination clinic").font(.snootsMetadata()).foregroundStyle(.secondary)
                    Text(clinic.name).font(.snootsCardTitle())
                }
                Spacer()
                Text(clinic.eta).font(.snootsUI(15, weight: .semibold)).foregroundStyle(SnootsPalette.careBlue)
            }
            Divider()
            Label(clinic.address, systemImage: "location.fill")
            Label(clinic.handoff, systemImage: "doc.text.fill")
        }
        .font(.snootsUI(14))
        .padding(16)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                        Text("No surprises at the door.").font(.snootsBody()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(SnootsPalette.surface, in: Circle())
                }

                NeighborhoodMapCard(places: visibleMapPlaces, isResolving: store.mapPlaces.isResolvingLocations)
                EmergencyMapCard(clinic: store.clinic) { presentedSheet = .emergency }

                Picker("Place type", selection: $selectedCategory) {
                    Text("All").tag(MapPlace.Category?.none)
                    ForEach(MapPlace.Category.allCases) { category in
                        Label(category.title, systemImage: category.symbol).tag(Optional(category))
                    }
                }
                .pickerStyle(.segmented)

                Text("Maps database · \(visibleMapPlaces.count) places").font(.snootsSection())
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

private struct EmergencyMapCard: View {
    let clinic: Clinic
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "cross.case.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(SnootsPalette.careBlue, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Emergency guidance")
                        .font(.snootsCardTitle())
                    Text("\(clinic.name) · \(clinic.eta)")
                        .font(.snootsMetadata())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Open now")
                    .font(.snootsChip())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(SnootsPalette.lime, in: Capsule())
            }
            Button("Get emergency help", action: onOpen)
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.careBlue))
        }
        .padding(16)
        .background(SnootsPalette.careTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                            .tint(markerColor(for: place.category))
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            VStack {
                Spacer()
                HStack {
                    Label(isResolving ? "Locating places…" : "\(places.filter { $0.coordinate != nil }.count) mapped", systemImage: "mappin.and.ellipse")
                    Spacer()
                    Text("Taipei")
                }
                .font(.snootsChip())
                .padding(12)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(12)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func markerColor(for category: MapPlace.Category) -> Color {
        switch category {
        case .restaurant: SnootsPalette.pink
        case .park: SnootsPalette.deepLilac
        case .hospital: SnootsPalette.careBlue
        }
    }
}

private struct DatabasePlaceRow: View {
    let place: MapPlace
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: place.category.symbol)
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 40, height: 40)
                .background(categoryColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(place.name).font(.snootsCardTitle())
                Text(place.category.title).font(.snootsMetadata()).foregroundStyle(categoryColor)
                if !place.subtitle.isEmpty {
                    Text(place.subtitle).font(.snootsMetadata()).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let appleMapsURL = place.appleMapsURL {
                Button {
                    openURL(appleMapsURL)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.title3)
                        .foregroundStyle(SnootsPalette.ink)
                        .frame(width: 36, height: 36)
                        .background(SnootsPalette.softPink, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(place.name) in Apple Maps")
            }
        }
        .padding(14)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    private var categoryColor: Color {
        switch place.category {
        case .restaurant: SnootsPalette.pink
        case .park: SnootsPalette.deepLilac
        case .hospital: SnootsPalette.careBlue
        }
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
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.name).font(.snootsCardTitle()).foregroundStyle(SnootsPalette.ink)
                        Text("\(place.category) · \(place.walk)").font(.snootsMetadata()).foregroundStyle(.secondary)
                        DeclarationChips(labels: Array(place.rules.prefix(3)).map(\.shortLabel), tint: SnootsPalette.butter)
                        Text("Verified \(place.verified)").font(.snootsMetadata()).foregroundStyle(SnootsPalette.deepLilac)
                    }
                }
            }
            .buttonStyle(.plain)
            Button(action: onToggleSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isSaved ? SnootsPalette.pink : SnootsPalette.ink)
                    .frame(width: 36, height: 36)
                    .background(SnootsPalette.softPink, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "Remove \(place.name) from saved places" : "Save \(place.name)")
        }
        .padding(12)
        .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
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
                        Text("\(place.category) · \(place.walk)").font(.snootsBody()).foregroundStyle(.secondary)
                    }
                    Text("Before you go").font(.snootsSection())
                    ForEach(place.rules) { rule in
                        Label(rule.label, systemImage: rule.symbol)
                            .font(.snootsUI(15, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(SnootsPalette.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.font(.snootsUI(15, weight: .semibold)) } }
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
                        Text("Your dog’s trusted details.").font(.snootsBody()).foregroundStyle(.secondary)
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
                        Text("with \(store.pet.name)").font(.snootsBody()).foregroundStyle(.secondary)
                        Label(store.profile.neighborhood, systemImage: "location.fill")
                            .font(.snootsMetadata())
                            .foregroundStyle(SnootsPalette.deepLilac)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                TrustSummaryCard(profile: store.profile)

                VStack(alignment: .leading, spacing: 12) {
                    Text("\(store.pet.name)’s play card").font(.snootsSection())
                    Text(store.pet.summary).font(.snootsBody()).foregroundStyle(.secondary)
                    DeclarationChips(labels: store.pet.traits, tint: SnootsPalette.butter)
                    Label(store.pet.healthStatus, systemImage: "checkmark.shield.fill")
                        .font(.snootsUI(14, weight: .semibold))
                        .foregroundStyle(SnootsPalette.deepLilac)
                }
                .padding(16)
                .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

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
                            .background(SnootsPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .foregroundStyle(.secondary)
                .padding(.horizontal, 26)
            Button("Match with \(candidate.name)") {
                store.isMatched = true
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.pink))
            Button("Not yet") { dismiss() }
                .font(.snootsUI(15, weight: .semibold))
                .foregroundStyle(SnootsPalette.ink)
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            .font(.snootsUI(17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: Capsule())
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
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}

private enum SnootsPalette {
    static let canvas = Color(hex: 0xFFFFFC)
    static let surface = Color.white
    static let ink = Color(hex: 0x14141A)
    static let pink = Color(hex: 0xFF4085)
    static let softPink = Color(hex: 0xFFE3F0)
    static let lilac = Color(hex: 0xB885FF)
    static let deepLilac = Color(hex: 0x4A2E7A)
    static let sky = Color(hex: 0x52ADFF)
    static let careBlue = Color(hex: 0x146EE0)
    static let careTint = Color(hex: 0xE3F0FF)
    static let lime = Color(hex: 0xC7FF3D)
    static let butter = Color(hex: 0xFFE891)
    static let alert = Color(hex: 0xB31C40)
}

private extension Color {
    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private extension Font {
    static func snootsDisplay(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("Nunito", size: size, relativeTo: .largeTitle).weight(weight)
    }

    static func snootsScreenTitle() -> Font { snootsDisplay(34, weight: .bold) }
    static func snootsSection() -> Font { snootsDisplay(20, weight: .bold) }
    static func snootsCardTitle() -> Font { snootsDisplay(18, weight: .bold) }
    static func snootsUI(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size, relativeTo: size >= 15 ? .body : .caption).weight(weight)
    }

    static func snootsBody() -> Font { snootsUI(16) }
    static func snootsMetadata() -> Font { snootsUI(12, weight: .medium) }
    static func snootsChip() -> Font { snootsUI(12, weight: .medium) }
}
