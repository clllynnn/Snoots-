import SwiftUI

struct ContentView: View {
    let store: SnootsStore
    @State private var selectedTab: AppTab = .social
    @State private var presentedSheet: SnootsSheet?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SocialView(store: store)
            }
            .tabItem { Label("Social", systemImage: "bubble.left.and.bubble.right.fill") }
            .tag(AppTab.social)

            NavigationStack {
                PlaydatesView(store: store, presentedSheet: $presentedSheet)
            }
            .tabItem { Label("Playdates", systemImage: "heart.fill") }
            .tag(AppTab.playdates)

            NavigationStack {
                CareView(store: store)
            }
            .tabItem { Label("Care", systemImage: "cross.case.fill") }
            .tag(AppTab.care)

            NavigationStack {
                PlacesView(store: store, presentedSheet: $presentedSheet)
            }
            .tabItem { Label("Places", systemImage: "fork.knife") }
            .tag(AppTab.places)
        }
        .tint(SnootsPalette.pink)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .place(let placeID):
                if let place = store.place(id: placeID) {
                    PlaceDetailSheet(place: place, store: store)
                }
            case .match:
                MatchSheet(candidate: store.playdate, store: store)
            }
        }
    }
}

private enum AppTab: Hashable {
    case social, playdates, care, places
}

struct SocialView: View {
    let store: SnootsStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Snoots!")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(SnootsPalette.ink)
                        Text("Taipei pet parents, checked in.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "bell.badge.fill")
                        .font(.title3)
                        .foregroundStyle(SnootsPalette.pink)
                        .padding(11)
                        .background(SnootsPalette.softPink, in: Circle())
                }

                TrustSummaryCard(profile: store.myProfile)

                HStack {
                    Text("From your community")
                        .font(.title3.bold())
                    Spacer()
                    Text("Nearby")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SnootsPalette.pink)
                }

                ForEach(store.socialPosts) { post in
                    switch post.kind {
                    case .photo:
                        PhotoPostCard(post: post)
                    case .discussion:
                        DiscussionCard(post: post)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(SnootsPalette.canvas)
        .navigationBarHidden(true)
    }
}

private struct TrustSummaryCard: View {
    let profile: PetParentProfile

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(SnootsPalette.lilac)
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("Trust profile \(profile.trustScore)")
                    .font(.headline)
                Text("ID, vet record & behavior card verified")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(SnootsPalette.ink.opacity(0.55))
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SnootsPalette.lilac.opacity(0.35), lineWidth: 1.5)
        }
    }
}

private struct PhotoPostCard: View {
    let post: SocialPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PostAuthorRow(post: post)
            PetPortrait(name: post.petName, tone: post.tone, symbol: "dog.fill")
                .frame(height: 220)
            Text(post.body)
                .font(.body)
                .foregroundStyle(SnootsPalette.ink)
            DisclosureChips(labels: post.declarations, color: SnootsPalette.lilac)
            HStack(spacing: 18) {
                Label("\(post.likes)", systemImage: "heart")
                Label("\(post.comments)", systemImage: "bubble.right")
                Spacer()
                Image(systemName: "paperplane")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DiscussionCard: View {
    let post: SocialPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Community question", systemImage: "text.bubble.fill")
                    .font(.caption.bold())
                    .foregroundStyle(SnootsPalette.deepLilac)
                Spacer()
                Text(post.timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(post.body)
                .font(.title3.bold())
                .foregroundStyle(SnootsPalette.ink)
            DisclosureChips(labels: post.declarations, color: SnootsPalette.softPink)
            HStack {
                Label("\(post.comments) trusted replies", systemImage: "checkmark.message.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SnootsPalette.pink)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(SnootsPalette.pink)
            }
        }
        .padding(16)
        .background(SnootsPalette.paleLilac, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct PostAuthorRow: View {
    let post: SocialPost

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(post.tone.color.opacity(0.28))
                .frame(width: 38, height: 38)
                .overlay {
                    Text(post.owner.prefix(1))
                        .font(.headline.bold())
                        .foregroundStyle(SnootsPalette.ink)
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.owner)
                        .font(.subheadline.bold())
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(SnootsPalette.lilac)
                }
                Text("with \(post.petName) · \(post.timeAgo)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "ellipsis")
                .foregroundStyle(.secondary)
        }
    }
}

struct PlaydatesView: View {
    let store: SnootsStore
    @Binding var presentedSheet: SnootsSheet?
    @State private var isPassed = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Playdates")
                        .font(.largeTitle.bold())
                    Text("Accountability before chemistry.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("2 km", systemImage: "location.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(SnootsPalette.softPink, in: Capsule())
            }

            if store.isMatched {
                MatchedBanner(candidate: store.playdate)
            } else if isPassed {
                ContentUnavailableView("More checked matches nearby", systemImage: "pawprint.fill", description: Text("Tap Revisit to view Mochi again."))
                Button("Revisit Mochi") { isPassed = false }
                    .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.lilac))
            } else {
                MatchProfileCard(candidate: store.playdate)
                HStack(spacing: 14) {
                    Button {
                        isPassed = true
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 58, height: 58)
                    }
                    .buttonStyle(CircleActionStyle(color: .white, icon: SnootsPalette.pink))

                    Button {
                        presentedSheet = .match
                    } label: {
                        Image(systemName: "heart.fill")
                            .frame(width: 70, height: 70)
                    }
                    .buttonStyle(CircleActionStyle(color: SnootsPalette.pink, icon: .white))

                    Button { } label: {
                        Image(systemName: "bookmark.fill")
                            .frame(width: 58, height: 58)
                    }
                    .buttonStyle(CircleActionStyle(color: .white, icon: SnootsPalette.lilac))
                }
                Text("Pass · propose a leashed hello · save for later")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .background(SnootsPalette.canvas)
        .navigationBarHidden(true)
    }
}

private struct MatchProfileCard: View {
    let candidate: PlaydateCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                PetPortrait(name: candidate.name, tone: candidate.tone, symbol: "dog.fill")
                    .frame(height: 270)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(candidate.name), \(candidate.age)")
                        .font(.title.bold())
                    Text("with \(candidate.owner) · \(candidate.distance)")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.42))
            }
            DisclosureChips(labels: candidate.compatibility, color: SnootsPalette.softPink)

            Divider()
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(SnootsPalette.lilac)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Owner accountability")
                        .font(.subheadline.bold())
                    Text(candidate.accountability)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(candidate.intro)
                .font(.subheadline)
                .foregroundStyle(SnootsPalette.ink)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: SnootsPalette.ink.opacity(0.08), radius: 14, y: 5)
    }
}

private struct MatchedBanner: View {
    let candidate: PlaydateCandidate

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(SnootsPalette.pink)
            Text("It’s a careful match!")
                .font(.title2.bold())
            Text("You and \(candidate.owner) agreed to a quiet, leashed first hello.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Label("Shared behavior cards", systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold())
                .foregroundStyle(SnootsPalette.deepLilac)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct CareView: View {
    let store: SnootsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Care")
                            .font(.largeTitle.bold())
                        Text("Stay with your pet. We’ll keep this simple.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "cross.case.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(SnootsPalette.pink, in: Circle())
                }

                Label("DEMO GUIDANCE ONLY · NOT CLINICAL TRIAGE", systemImage: "info.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(SnootsPalette.alert)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SnootsPalette.alert.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                CareProgressCard(step: store.currentCareStep, index: store.careStepIndex, total: store.careSteps.count)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Critical symptoms noted")
                        .font(.headline)
                    DisclosureChips(labels: store.criticalSymptoms, color: SnootsPalette.softPink)
                }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                ClinicCard(clinic: store.clinic)

                Button(store.careStepIndex == store.careSteps.count - 1 ? "Demo handoff complete" : "Next scripted step") {
                    store.advanceCareStep()
                }
                .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.pink))
                .disabled(store.careStepIndex == store.careSteps.count - 1)

                Text("This prototype demonstrates an in-transit handoff flow. Contact local emergency services or a licensed clinic for real medical decisions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationBarHidden(true)
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
                    .font(.caption.bold())
                    .foregroundStyle(SnootsPalette.deepLilac)
                Spacer()
                Image(systemName: step.symbol)
                    .font(.title2)
                    .foregroundStyle(SnootsPalette.pink)
            }
            Text(step.title)
                .font(.title2.bold())
                .foregroundStyle(SnootsPalette.ink)
            Text(step.instruction)
                .font(.body)
                .foregroundStyle(SnootsPalette.ink.opacity(0.8))
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { item in
                    Capsule()
                        .fill(item <= index ? SnootsPalette.pink : SnootsPalette.softPink)
                        .frame(height: 6)
                }
            }
        }
        .padding(18)
        .background(SnootsPalette.paleLilac, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

private struct ClinicCard: View {
    let clinic: Clinic

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.title)
                    .foregroundStyle(SnootsPalette.lilac)
                VStack(alignment: .leading) {
                    Text("Destination clinic")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(clinic.name)
                        .font(.headline)
                }
                Spacer()
                Text(clinic.eta)
                    .font(.subheadline.bold())
                    .foregroundStyle(SnootsPalette.pink)
            }
            Divider()
            Label(clinic.address, systemImage: "location.fill")
            Label(clinic.handoff, systemImage: "doc.text.fill")
        }
        .font(.subheadline)
        .foregroundStyle(SnootsPalette.ink)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct PlacesView: View {
    let store: SnootsStore
    @Binding var presentedSheet: SnootsSheet?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Places")
                            .font(.largeTitle.bold())
                        Text("No surprises at the door.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .padding(10)
                        .background(.white, in: Circle())
                }

                NeighborhoodMapCard(places: store.places)

                Text("Verified around Da’an")
                    .font(.title3.bold())

                ForEach(store.places) { place in
                    PlaceRow(place: place, isSaved: store.isSaved(place)) {
                        presentedSheet = .place(place.id)
                    } onToggleSave: {
                        store.toggleSaved(place)
                    }
                }
            }
            .padding(18)
        }
        .background(SnootsPalette.canvas)
        .navigationBarHidden(true)
    }
}

private struct NeighborhoodMapCard: View {
    let places: [Place]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(SnootsPalette.map)
            Path { path in
                path.move(to: CGPoint(x: 10, y: 40))
                path.addCurve(to: CGPoint(x: 320, y: 180), control1: CGPoint(x: 90, y: 100), control2: CGPoint(x: 220, y: 80))
                path.move(to: CGPoint(x: 40, y: 180))
                path.addCurve(to: CGPoint(x: 330, y: 30), control1: CGPoint(x: 160, y: 130), control2: CGPoint(x: 210, y: 60))
            }
            .stroke(.white.opacity(0.8), lineWidth: 8)
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                Label("\(index + 1)", systemImage: "pawprint.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(9)
                    .background(index == 0 ? SnootsPalette.pink : SnootsPalette.lilac, in: Capsule())
                    .offset(x: index == 0 ? -90 : (index == 1 ? 62 : 92), y: index == 0 ? -32 : (index == 1 ? 42 : -64))
            }
            VStack {
                Spacer()
                HStack {
                    Label("Live rules", systemImage: "checkmark.seal.fill")
                    Spacer()
                    Text("Da’an")
                }
                .font(.caption.bold())
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .padding(12)
        }
        .frame(height: 190)
    }
}

private struct PlaceRow: View {
    let place: Place
    let isSaved: Bool
    let onOpen: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(place.tone.color.opacity(0.35))
                    Image(systemName: place.symbol)
                        .font(.title2)
                        .foregroundStyle(SnootsPalette.ink)
                }
                .frame(width: 68, height: 76)

                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundStyle(SnootsPalette.ink)
                    Text(place.category + " · " + place.walk)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DisclosureChips(labels: place.rules.map(\.shortLabel), color: SnootsPalette.softPink)
                    Text("Verified \(place.verified)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SnootsPalette.deepLilac)
                }
                Spacer(minLength: 0)
                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isSaved ? SnootsPalette.pink : SnootsPalette.ink)
                        .padding(5)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
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
                    PetPortrait(name: place.name, tone: place.tone, symbol: place.symbol)
                        .frame(height: 190)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(place.name)
                            .font(.title.bold())
                        Text(place.category + " · " + place.walk)
                            .foregroundStyle(.secondary)
                    }
                    Text("Before you go")
                        .font(.title3.bold())
                    ForEach(place.rules) { rule in
                        HStack(spacing: 12) {
                            Image(systemName: rule.symbol)
                                .frame(width: 26)
                                .foregroundStyle(SnootsPalette.pink)
                            Text(rule.label)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        .padding(14)
                        .background(SnootsPalette.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    Label("Rules confirmed \(place.verified)", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(SnootsPalette.deepLilac)
                    Button(store.isSaved(place) ? "Saved for later" : "Save place") {
                        store.toggleSaved(place)
                    }
                    .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.pink))
                }
                .padding(18)
            }
            .navigationTitle("Place details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MatchSheet: View {
    let candidate: PlaydateCandidate
    let store: SnootsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(SnootsPalette.softPink)
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(SnootsPalette.pink)
            }
            .frame(width: 112, height: 112)
            Text("Propose a safe hello?")
                .font(.title.bold())
            Text("You’ll both see each other’s verified behavior cards before the match is confirmed.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 26)
            Button("Match with \(candidate.name)") {
                store.isMatched = true
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle(color: SnootsPalette.pink))
            Button("Not yet") { dismiss() }
                .font(.subheadline.bold())
                .foregroundStyle(SnootsPalette.ink)
            Spacer()
        }
        .padding(22)
    }
}

private struct PetPortrait: View {
    let name: String
    let tone: PetTone
    let symbol: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(tone.color.opacity(0.45))
            Circle()
                .fill(.white.opacity(0.55))
                .frame(width: 150, height: 150)
                .offset(x: 80, y: -50)
            Image(systemName: symbol)
                .font(.system(size: 92, weight: .medium))
                .foregroundStyle(SnootsPalette.ink)
                .offset(y: 8)
            Text(name.uppercased())
                .font(.caption2.bold())
                .tracking(1.8)
                .foregroundStyle(SnootsPalette.ink.opacity(0.55))
                .padding(9)
                .background(.white.opacity(0.62), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
        }
        .clipped()
    }
}

private struct DisclosureChips: View {
    let labels: [String]
    let color: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SnootsPalette.ink)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(color, in: Capsule())
                }
            }
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color.opacity(configuration.isPressed ? 0.72 : 1), in: Capsule())
    }
}

private struct CircleActionStyle: ButtonStyle {
    let color: Color
    let icon: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.weight(.bold))
            .foregroundStyle(icon)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1), in: Circle())
            .overlay { Circle().stroke(SnootsPalette.ink.opacity(0.08), lineWidth: 1) }
            .shadow(color: SnootsPalette.ink.opacity(0.08), radius: 8, y: 3)
    }
}

#Preview {
    ContentView(store: SnootsStore())
}
