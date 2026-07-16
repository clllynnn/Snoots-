import Foundation
import Observation

@MainActor
@Observable
final class SnootsStore {
    let profile = ParentProfile(name: "Amber", petName: "Nori", trustScore: 92, neighborhood: "Da’an District, Taipei")
    let pet = PetProfile(
        name: "Nori",
        imageName: "Nori",
        summary: "A thoughtful walker who prefers a little space before joining in.",
        traits: ["Slow introductions", "Adult dogs", "Long lead"],
        healthStatus: "Vaccinations and behavior card verified"
    )
    var isMatched = false
    var careStepIndex = 0
    var savedPlaceIDs: Set<String> = []
    let mapPlaces = MapPlacesRepository()

    let socialPosts = [
        SocialPost(owner: "Yuna", petName: "Nori", timeAgo: "12 min", body: "First calm walk at Da’an Forest Park. Nori did beautifully with a long lead and lots of space.", declarations: ["Leash on", "Slow introductions", "Adult dogs"], likes: 48, comments: 8, kind: .photo, photoName: "Nori"),
        SocialPost(owner: "Kai", petName: "Tofu", timeAgo: "28 min", body: "Looking for a quiet 7am walking buddy near Yongkang Street. Who has a dog that enjoys parallel walks?", declarations: ["Verified owner", "No off-leash", "Small group"], likes: 0, comments: 14, kind: .discussion, photoName: nil),
        SocialPost(owner: "Mina", petName: "Pudding", timeAgo: "1 hr", body: "Pudding’s first cafe patio nap. Thank you for respecting her no-touch vest!", declarations: ["No touch", "Stroller friendly", "Sensory break"], likes: 73, comments: 12, kind: .photo, photoName: "Pudding")
    ]

    let playdate = PlaydateCandidate(
        name: "Mochi",
        age: "2 y",
        owner: "Elena",
        distance: "1.2 km away",
        imageName: "Mochi",
        compatibility: ["Gentle greeter", "Leashed intro", "Similar size"],
        accountability: "Identity verified · Vaccines shared · Leash-first terms accepted",
        intro: "Playful after a slow hello. Elena prefers a 20-minute parallel walk before any free play."
    )

    let criticalSymptoms = ["Repeated vomiting", "Very quiet", "Possible toxin"]
    let careSteps = [
        CareStep(title: "Keep the ride calm", instruction: "Use a secure carrier or harness. Keep the space quiet and avoid food or medication unless a licensed clinician tells you otherwise.", symbol: "car.fill"),
        CareStep(title: "Prepare the handoff", instruction: "Have the time symptoms started, possible exposure, and a short video ready to share when you arrive.", symbol: "doc.text.fill"),
        CareStep(title: "Arrive and repeat the facts", instruction: "At reception, state the symptoms and possible toxin exposure clearly. The clinic will take over the real assessment.", symbol: "building.2.fill")
    ]
    let clinic = Clinic(name: "Da’an Night Animal Clinic", eta: "8 min", address: "104 Fuxing S. Rd., Da’an District", handoff: "Symptom and exposure summary ready")

    let places = [
        Place(id: "companion", name: "Companion Cafe", category: "Cafe", walk: "4 min walk", imageName: "CompanionCafe", rules: [.stroller, .indoorLeash, .under15kg, .seatCover], verified: "today, 18:40"),
        Place(id: "terrace", name: "Terrace Table", category: "Bistro", walk: "7 min walk", imageName: "TerraceTable", rules: [.outdoorOnly, .under15kg, .waterBowl], verified: "Jul 14"),
        Place(id: "pages", name: "Paws & Pages", category: "Book bar", walk: "11 min walk", imageName: "Pudding", rules: [.stroller, .indoorLeash, .quietHours], verified: "Jul 12")
    ]

    var currentCareStep: CareStep { careSteps[careStepIndex] }
    var savedPlaces: [Place] { places.filter { savedPlaceIDs.contains($0.id) } }

    func advanceCareStep() {
        careStepIndex = min(careStepIndex + 1, careSteps.count - 1)
    }

    func place(id: String) -> Place? { places.first { $0.id == id } }
    func isSaved(_ place: Place) -> Bool { savedPlaceIDs.contains(place.id) }

    func toggleSaved(_ place: Place) {
        if savedPlaceIDs.contains(place.id) {
            savedPlaceIDs.remove(place.id)
        } else {
            savedPlaceIDs.insert(place.id)
        }
    }
}

enum SnootsSheet: Identifiable {
    case place(String)
    case match
    case emergency

    var id: String {
        switch self {
        case .place(let placeID): "place-\(placeID)"
        case .match: "match"
        case .emergency: "emergency"
        }
    }
}

struct ParentProfile {
    let name: String
    let petName: String
    let trustScore: Int
    let neighborhood: String
}

struct PetProfile {
    let name: String
    let imageName: String
    let summary: String
    let traits: [String]
    let healthStatus: String
}

struct SocialPost: Identifiable {
    enum Kind { case photo, discussion }

    let id = UUID()
    let owner: String
    let petName: String
    let timeAgo: String
    let body: String
    let declarations: [String]
    let likes: Int
    let comments: Int
    let kind: Kind
    let photoName: String?
}

struct PlaydateCandidate {
    let name: String
    let age: String
    let owner: String
    let distance: String
    let imageName: String
    let compatibility: [String]
    let accountability: String
    let intro: String
}

struct CareStep: Identifiable {
    let id = UUID()
    let title: String
    let instruction: String
    let symbol: String
}

struct Clinic {
    let name: String
    let eta: String
    let address: String
    let handoff: String
}

struct Place: Identifiable {
    let id: String
    let name: String
    let category: String
    let walk: String
    let imageName: String
    let rules: [PlaceRule]
    let verified: String
}

enum PlaceRule: String, Identifiable {
    case stroller, indoorLeash, under15kg, seatCover, outdoorOnly, waterBowl, quietHours

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .stroller: "Stroller OK"
        case .indoorLeash: "Leash inside"
        case .under15kg: "Under 15 kg"
        case .seatCover: "Seat cover"
        case .outdoorOnly: "Patio only"
        case .waterBowl: "Water bowls"
        case .quietHours: "Quiet hours"
        }
    }

    var label: String {
        switch self {
        case .stroller: "Strollers welcome at the entry"
        case .indoorLeash: "Leash required indoors"
        case .under15kg: "Dogs under 15 kg only"
        case .seatCover: "Bring a seat cover for bench seating"
        case .outdoorOnly: "Dogs are welcome on the outdoor patio only"
        case .waterBowl: "Water bowls available on request"
        case .quietHours: "Quiet hours after 7pm"
        }
    }

    var symbol: String {
        switch self {
        case .stroller: "stroller.fill"
        case .indoorLeash: "link"
        case .under15kg: "scalemass.fill"
        case .seatCover: "chair.lounge.fill"
        case .outdoorOnly: "sun.max.fill"
        case .waterBowl: "drop.fill"
        case .quietHours: "moon.stars.fill"
        }
    }
}
