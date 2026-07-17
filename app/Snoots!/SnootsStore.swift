import Foundation
import Observation

@MainActor
@Observable
final class SnootsStore {
    var profile = ParentProfile(name: "Amber", petName: "Nori", trustScore: 92, neighborhood: "Da’an District, Taipei")
    var pet = PetProfile(
        name: "Nori",
        imageName: "Nori",
        summary: "A thoughtful walker who prefers a little space before joining in.",
        traits: ["Slow introductions", "Adult dogs", "Long lead"],
        healthStatus: "Vaccinations and behavior card verified"
    )
    let care = PetCareProfile(
        rabies: VaccineRecord(
            vaccinatedOn: "14 Sep 2025",
            validUntil: "14 Sep 2026",
            clinic: "Da’an Animal Hospital",
            manufacturer: "Nobivac Rabies",
            batchNumber: "RAB-250914"
        ),
        otherVaccinationsCount: 2,
        healthNotes: "No allergies or ongoing medication"
    )
    var isMatched = false
    var hasMatchChat = false
    var matchChatMessages: [MatchChatMessage] = []
    var careStepIndex = 0
    var savedPlaceIDs: Set<String> = []
    let mapPlaces = MapPlacesRepository()

    let feedStories = [
        FeedStory(name: "Your story", imageName: "Nori", isCurrentUser: true),
        FeedStory(name: "Yuna", imageName: "Nori"),
        FeedStory(name: "Milo", imageName: "Mochi"),
        FeedStory(name: "Luna", imageName: "Mochi"),
        FeedStory(name: "Kuma", imageName: "Pudding")
    ]

    let socialPosts = [
        SocialPost(owner: "Yuna", petName: "Nori", location: "Da’an Forest Park", timeAgo: "12m", body: "First calm walk at Da’an Forest Park. Nori did beautifully with a long lead and lots of space.", declarations: ["Leash on", "Slow introductions", "Adult dogs"], likes: 48, comments: 8, kind: .photo, photoName: "Nori"),
        SocialPost(owner: "Milo", petName: "Milo", location: "Riverside Park", timeAgo: "1h", body: "Golden-hour zoomies, followed by the best slow sniff along the river.", declarations: ["Leash on", "Friendly hello", "Sunset walk"], likes: 31, comments: 5, kind: .photo, photoName: "Mochi")
    ]

    let playdate = PlaydateCandidate(
        name: "Mochi",
        age: "2 y",
        owner: "Elena",
        distance: "1.2 km away",
        imageName: "Mochi",
        compatibility: ["Slow to warm up", "Leash-first", "Similar size"],
        accountability: "Identity verified · Vaccines shared",
        intro: "Playful after a slow hello. Prefers a 20-minute parallel walk before free play."
    )

    let criticalSymptoms = ["Repeated vomiting", "Very quiet", "Possible toxin"]
    let careSteps = [
        CareStep(title: "Keep the ride calm", instruction: "Use a secure carrier or harness. Keep the space quiet and avoid food or medication unless a licensed clinician tells you otherwise.", symbol: "car.fill"),
        CareStep(title: "Prepare the handoff", instruction: "Have the time symptoms started, possible exposure, and a short video ready to share when you arrive.", symbol: "doc.text.fill"),
        CareStep(title: "Arrive and repeat the facts", instruction: "At reception, state the symptoms and possible toxin exposure clearly. The clinic will take over the real assessment.", symbol: "building.2.fill")
    ]
    let clinic = Clinic(name: "Da’an Night Animal Clinic", eta: "8 min", address: "104 Fuxing S. Rd., Da’an District", handoff: "Symptom and exposure summary ready")

    let places = [
        Place(id: "companion", name: "Companion Cafe", category: "Cafe", nearbyCategory: .places, walk: "4 min walk", walkMinutes: 4, imageName: "CompanionCafe", rules: [.stroller, .indoorLeash, .seatCover], verified: "today, 18:40", dogAccess: .indoorOK, verificationLevel: .venueConfirmed, lastConfirmed: "17 Jul 2026", verificationSource: "Venue confirmed", acceptsLargeDogs: true, isOpenNow: true, latitude: 25.0324, longitude: 121.5446, address: "No. 18, Lane 181, Section 3, Roosevelt Rd.", facilities: [.waterBowl, .wasteBin, .shade, .outdoorSeating], intentKeywords: "indoor cafe rainy day large dog"),
        Place(id: "terrace", name: "Terrace Table", category: "Bistro", nearbyCategory: .places, walk: "7 min walk", walkMinutes: 7, imageName: "TerraceTable", rules: [.outdoorOnly, .waterBowl], verified: "14 Jul", dogAccess: .outdoorOnly, verificationLevel: .communityConfirmed, lastConfirmed: "14 Jul 2026", verificationSource: "Community confirmed", acceptsLargeDogs: true, isOpenNow: true, latitude: 25.0372, longitude: 121.5483, address: "No. 42, Yongkang St., Da’an District", facilities: [.waterBowl, .shade, .outdoorSeating], intentKeywords: "patio outdoor bistro large dog"),
        Place(id: "pages", name: "Paws & Pages", category: "Book bar", nearbyCategory: .places, walk: "11 min walk", walkMinutes: 11, imageName: "Pudding", rules: [.stroller, .indoorLeash, .quietHours], verified: "12 Jul", dogAccess: .carrierRequired, verificationLevel: .needsReconfirmation, lastConfirmed: "12 Jul 2026", verificationSource: "Community report", acceptsLargeDogs: false, isOpenNow: false, latitude: 25.0296, longitude: 121.5358, address: "No. 9, Lane 243, Heping E. Rd.", facilities: [.wasteBin, .shade], intentKeywords: "book bar carrier quiet rainy day"),
        Place(id: "morning-walk", name: "Da’an Morning Social Walk", category: "Leashed group walk", nearbyCategory: .meetups, walk: "6 min walk", walkMinutes: 6, imageName: "Nori", rules: [.indoorLeash], verified: "today, 08:10", dogAccess: .restrictionsApply, verificationLevel: .communityConfirmed, lastConfirmed: "17 Jul 2026", verificationSource: "Host confirmed", acceptsLargeDogs: true, isOpenNow: true, latitude: 25.0311, longitude: 121.5368, address: "Da’an Forest Park, East Gate", facilities: [.waterBowl, .wasteBin, .shade], intentKeywords: "dog meetup group walk large dog leashed"),
        Place(id: "rainy-club", name: "Rainy Day Puppy Club", category: "Indoor dog meetup", nearbyCategory: .meetups, walk: "9 min walk", walkMinutes: 9, imageName: "Mochi", rules: [.indoorLeash, .quietHours], verified: "16 Jul", dogAccess: .indoorOK, verificationLevel: .venueConfirmed, lastConfirmed: "16 Jul 2026", verificationSource: "Host and venue confirmed", acceptsLargeDogs: false, isOpenNow: true, latitude: 25.0415, longitude: 121.5431, address: "No. 15, Lane 201, Guangfu S. Rd.", facilities: [.waterBowl, .parking], intentKeywords: "indoor meetup rainy day small dog"),
        Place(id: "daan-night", name: "Da’an Night Animal Clinic", category: "Emergency veterinary clinic", nearbyCategory: .vets, walk: "8 min walk", walkMinutes: 8, imageName: "CompanionCafe", rules: [.indoorLeash], verified: "17 Jul", dogAccess: .restrictionsApply, verificationLevel: .venueConfirmed, lastConfirmed: "17 Jul 2026", verificationSource: "Clinic confirmed", acceptsLargeDogs: true, isOpenNow: true, latitude: 25.0391, longitude: 121.5438, address: "104 Fuxing S. Rd., Da’an District", facilities: [.parking, .waterBowl], intentKeywords: "emergency vet hospital large dog"),
        Place(id: "xinyi-vet", name: "Xinyi Animal Hospital", category: "Veterinary hospital", nearbyCategory: .vets, walk: "14 min walk", walkMinutes: 14, imageName: "TerraceTable", rules: [.indoorLeash], verified: "10 Jul", dogAccess: .restrictionsApply, verificationLevel: .needsReconfirmation, lastConfirmed: "10 Jul 2026", verificationSource: "Community report", acceptsLargeDogs: true, isOpenNow: false, latitude: 25.0339, longitude: 121.5611, address: "No. 98, Section 5, Xinyi Rd.", facilities: [.parking, .wasteBin], intentKeywords: "vet hospital emergency" )
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

    func updateProfile(ownerName: String, neighborhood: String, petName: String, summary: String, traits: [String]) {
        profile.name = ownerName
        profile.neighborhood = neighborhood
        profile.petName = petName
        pet.name = petName
        pet.summary = summary
        pet.traits = traits
    }

    func createMatchChat() {
        hasMatchChat = true
    }

    func sendMatchChatMessage(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        matchChatMessages.append(MatchChatMessage(text: trimmedText, isOutgoing: true))
    }
}

struct MatchChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isOutgoing: Bool
}

struct ParentProfile {
    var name: String
    var petName: String
    let trustScore: Int
    var neighborhood: String
}

struct PetProfile {
    var name: String
    let imageName: String
    var summary: String
    var traits: [String]
    let healthStatus: String
}

struct SocialPost: Identifiable {
    enum Kind { case photo, discussion }

    let id = UUID()
    let owner: String
    let petName: String
    let location: String
    let timeAgo: String
    let body: String
    let declarations: [String]
    let likes: Int
    let comments: Int
    let kind: Kind
    let photoName: String?

    func localizedTimeAgo(_ language: SnootsLanguage) -> String {
        switch timeAgo {
        case "12m": language.text(timeAgo, "12 分鐘前")
        case "1h": language.text(timeAgo, "1 小時前")
        default: timeAgo
        }
    }

    func localizedBody(_ language: SnootsLanguage) -> String {
        switch owner {
        case "Yuna":
            language.text(body, "第一次在大安森林公園平靜散步。Nori 使用長牽繩並保有足夠空間，表現得很棒。")
        case "Milo":
            language.text(body, "夕陽時的開心奔跑，接著沿著河岸慢慢聞一聞。")
        default:
            body
        }
    }

    func localizedDeclarations(_ language: SnootsLanguage) -> [String] {
        declarations.map { declaration in
            switch declaration {
            case "Leash on": language.text(declaration, "已繫牽繩")
            case "Slow introductions": language.text(declaration, "慢慢認識")
            case "Adult dogs": language.text(declaration, "偏好成犬")
            case "Friendly hello": language.text(declaration, "友善打招呼")
            case "Sunset walk": language.text(declaration, "夕陽散步")
            default: declaration
            }
        }
    }
}

struct FeedStory: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    var isCurrentUser = false
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

    func localizedName(_ language: SnootsLanguage) -> String {
        language.text(name, "大安夜間動物診所")
    }

    func localizedETA(_ language: SnootsLanguage) -> String {
        language.text(eta, "8 分鐘")
    }

    func localizedAddress(_ language: SnootsLanguage) -> String {
        language.text(address, "大安區復興南路 104 號")
    }

    func localizedHandoff(_ language: SnootsLanguage) -> String {
        language.text(handoff, "已準備症狀與可能接觸物摘要")
    }
}

struct Place: Identifiable {
    let id: String
    let name: String
    let category: String
    let nearbyCategory: NearbyCategory
    let walk: String
    let walkMinutes: Int
    let imageName: String
    let rules: [PlaceRule]
    let verified: String
    let dogAccess: DogAccess
    let verificationLevel: VerificationLevel
    let lastConfirmed: String
    let verificationSource: String
    let acceptsLargeDogs: Bool
    let isOpenNow: Bool
    let latitude: Double
    let longitude: Double
    let address: String
    let facilities: [PlaceFacility]
    let intentKeywords: String

    func localizedName(_ language: SnootsLanguage) -> String {
        switch id {
        case "companion": language.text(name, "伴伴咖啡")
        case "terrace": language.text(name, "露台小桌")
        case "pages": language.text(name, "毛孩書頁吧")
        case "morning-walk": language.text(name, "大安晨間狗狗散步")
        case "rainy-club": language.text(name, "雨天幼犬同樂會")
        case "daan-night": language.text(name, "大安夜間動物診所")
        case "xinyi-vet": language.text(name, "信義動物醫院")
        default: name
        }
    }

    func localizedAddress(_ language: SnootsLanguage) -> String {
        switch id {
        case "companion": language.text(address, "中正區羅斯福路三段 181 巷 18 號")
        case "terrace": language.text(address, "大安區永康街 42 號")
        case "pages": language.text(address, "大安區和平東路 243 巷 9 號")
        case "morning-walk": language.text(address, "大安森林公園東門")
        case "rainy-club": language.text(address, "大安區光復南路 201 巷 15 號")
        case "daan-night": language.text(address, "大安區復興南路 104 號")
        case "xinyi-vet": language.text(address, "信義區信義路五段 98 號")
        default: address
        }
    }

    func localizedVerificationSource(_ language: SnootsLanguage) -> String {
        switch verificationSource {
        case "Venue confirmed": language.text(verificationSource, "場地方確認")
        case "Community confirmed": language.text(verificationSource, "社群確認")
        case "Community report": language.text(verificationSource, "社群回報")
        case "Host confirmed": language.text(verificationSource, "主辦方確認")
        case "Host and venue confirmed": language.text(verificationSource, "主辦方與場地方確認")
        case "Clinic confirmed": language.text(verificationSource, "診所確認")
        default: verificationSource
        }
    }

    func localizedLastConfirmed(_ language: SnootsLanguage) -> String {
        switch lastConfirmed {
        case "17 Jul 2026": language.text(lastConfirmed, "2026 年 7 月 17 日")
        case "16 Jul 2026": language.text(lastConfirmed, "2026 年 7 月 16 日")
        case "14 Jul 2026": language.text(lastConfirmed, "2026 年 7 月 14 日")
        case "12 Jul 2026": language.text(lastConfirmed, "2026 年 7 月 12 日")
        case "10 Jul 2026": language.text(lastConfirmed, "2026 年 7 月 10 日")
        default: lastConfirmed
        }
    }

    func localizedCategory(_ language: SnootsLanguage) -> String {
        switch category {
        case "Cafe": language.text("Cafe", "咖啡廳")
        case "Bistro": language.text("Bistro", "餐酒館")
        case "Book bar": language.text("Book bar", "書吧")
        case "Leashed group walk": language.text("Leashed group walk", "牽繩團體散步")
        case "Indoor dog meetup": language.text("Indoor dog meetup", "室內狗聚")
        case "Emergency veterinary clinic": language.text("Emergency veterinary clinic", "急診獸醫診所")
        case "Veterinary hospital": language.text("Veterinary hospital", "動物醫院")
        default: category
        }
    }

    func localizedWalk(_ language: SnootsLanguage) -> String {
        language.text(walk, "步行 \(walkMinutes) 分鐘")
    }

    func sizeRule(_ language: SnootsLanguage) -> String {
        acceptsLargeDogs ? language.text("Large dogs accepted.", "接受大型犬。") : language.text("Small dogs only.", "僅限小型犬。")
    }

    func equipmentRule(_ language: SnootsLanguage) -> String {
        language.text("Leash required.", "需要牽繩。")
    }

    func seatingRule(_ language: SnootsLanguage) -> String {
        language.text("Dogs stay on the floor; no seats or tables.", "狗狗需待在地面，不可上座位或桌面。")
    }

    func timeRule(_ language: SnootsLanguage) -> String {
        dogAccess == .restrictionsApply ? language.text("Please check the visit time with staff.", "請先向現場人員確認可入場時段。") : language.text("No regular time restriction reported.", "目前未回報固定時段限制。")
    }

    func policySummary(_ language: SnootsLanguage) -> String {
        language.text("\(dogAccess.detail(language)) \(sizeRule(language)) \(equipmentRule(language)) Policy confirmed by \(verificationSource.lowercased()) on \(lastConfirmed).", "\(dogAccess.detail(language)) \(sizeRule(language)) \(equipmentRule(language)) 政策由 \(localizedVerificationSource(language)) 於 \(localizedLastConfirmed(language)) 確認。")
    }

    func openingHours(_ language: SnootsLanguage) -> String {
        isOpenNow ? language.text("Open until 21:00", "營業至 21:00") : language.text("Opens at 10:00", "10:00 開始營業")
    }

    func realWorldNotes(_ language: SnootsLanguage) -> [String] {
        acceptsLargeDogs
            ? [language.text("Tight indoor aisles", "室內走道較窄"), language.text("Busy after 2pm", "下午 2 點後較繁忙")]
            : [language.text("Best for smaller dogs", "較適合小型犬"), language.text("Bring a calm-down kit", "建議攜帶安撫用品")]
    }
}

enum DogAccess: String, CaseIterable {
    case indoorOK, outdoorOnly, carrierRequired, restrictionsApply

    func label(_ language: SnootsLanguage) -> String {
        switch self {
        case .indoorOK: language.text("Indoor OK", "可進室內")
        case .outdoorOnly: language.text("Outdoor only", "僅限戶外")
        case .carrierRequired: language.text("Carrier required", "需使用提籠")
        case .restrictionsApply: language.text("Restrictions apply", "須遵守限制")
        }
    }

    func detail(_ language: SnootsLanguage) -> String {
        switch self {
        case .indoorOK: language.text("Indoor access allowed.", "可進入室內。")
        case .outdoorOnly: language.text("Outdoor access only.", "僅限戶外區域。")
        case .carrierRequired: language.text("Indoor access with a carrier required.", "進室內時必須使用提籠。")
        case .restrictionsApply: language.text("Access depends on staff instructions or conditions.", "入場需依現場人員指示或條件辦理。")
        }
    }
}

enum VerificationLevel: String {
    case venueConfirmed, communityConfirmed, needsReconfirmation

    func label(_ language: SnootsLanguage) -> String {
        switch self {
        case .venueConfirmed: language.text("Venue confirmed", "場地方已確認")
        case .communityConfirmed: language.text("Community confirmed", "社群已確認")
        case .needsReconfirmation: language.text("Needs reconfirmation", "需再次確認")
        }
    }
}

enum PlaceFacility: CaseIterable {
    case waterBowl, wasteBin, shade, outdoorSeating, parking

    func label(_ language: SnootsLanguage) -> String {
        switch self {
        case .waterBowl: language.text("Water bowl", "飲水碗")
        case .wasteBin: language.text("Waste bin", "便袋垃圾桶")
        case .shade: language.text("Shade", "遮蔭")
        case .outdoorSeating: language.text("Outdoor seating", "戶外座位")
        case .parking: language.text("Parking", "停車")
        }
    }
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
