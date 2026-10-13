import Foundation

enum SocialDimension: String, CaseIterable, Identifiable, Codable {
    case humans, dogs, environment, handling, focus
    var id: String { rawValue }
    var title: String {
        switch self {
        case .humans: "對人親和度"
        case .dogs: "同類社交性"
        case .environment: "環境適應與穩定"
        case .handling: "觸碰與互動耐受"
        case .focus: "興奮度與專注力"
        }
    }
    func labels(_ state: String) -> [String] {
        guard state != "unobserved" else { return [] }
        let relaxed = state == "relaxed"
        switch self {
        case .humans: return relaxed ? ["願意打招呼", "與陌生人相處自在"] : ["先觀察陌生人", "需要保留距離"]
        case .dogs: return relaxed ? ["禮貌相遇", "平行散步自在"] : ["保持安全距離", "需要慢慢熟悉"]
        case .environment: return relaxed ? ["自在探索環境", "遇干擾後恢復步調"] : ["需要安靜路線", "需要更多適應時間"]
        case .handling: return relaxed ? ["接受飼主輕觸", "配戴裝備順利"] : ["觸碰時需要時間", "操作時需要暫停"]
        case .focus: return relaxed ? ["玩耍節奏舒適", "能回應飼主引導"] : ["需要放慢節奏", "需要暫停互動"]
        }
    }
}
struct ObservationAnswer: Codable, Equatable {
    var state = "unobserved"
    var labels: [String] = []
    var payload: [String: Any] { ["state": state, "labels": labels] }
}
struct OnsiteMember: Codable, Identifiable {
    var id: UUID
    var name: String
    var breed: String
    var photoPath: String?
    var checkedInAt: Double?
    var method: String?
    var away: Bool
    var reaction: String?
    var status: String { checkedInAt == nil ? "未簽到" : (away ? "暫離中" : "已在場") }
}
struct OnsiteState: Codable {
    var eventID: UUID
    var startedAt: Double?
    var endedAt: Double?
    var underfilledConfirmed: Bool
    var hostID: UUID
    var status: String
    var approvedCount: Int
    var checkedInCount: Int
    var members: [OnsiteMember]
}
struct MemoryTarget: Codable, Identifiable {
    var id: UUID
    var name: String?
    var breed: String
    var photoPath: String?
    var recognized: Bool
    var answers: [String: ObservationAnswer]
    var cardSent: Bool
}
struct WarmCard: Codable, Identifiable {
    var id: UUID
    var eventID: UUID
    var senderID: UUID
    var recipientID: UUID
    var senderName: String
    var recipientName: String
    var body: String
    var tags: [String]
    var photoPath: String?
    var sentAt: Double
    var viewedAt: Double?
    var acknowledged: Bool
    var retractedAt: Double?
    var withdrawalUnread: Bool
    func canRetract(now: Double) -> Bool { retractedAt == nil && now < sentAt + 86_400 }
}
struct DogFriendInvite: Codable, Identifiable {
    var id: UUID
    var senderID: UUID
    var recipientID: UUID
    var senderName: String
    var recipientName: String
    var createdAt: Double
    var accepted: Bool
}
struct DogDirectMessage: Codable, Identifiable {
    var id: UUID
    var senderID: UUID
    var text: String
    var createdAt: Double
}
struct DogFriend: Codable, Identifiable {
    var id: UUID
    var userID: UUID
    var name: String
    var nickname: String
    var photoPath: String?
    var unread: Int
    var messages: [DogDirectMessage]
}
struct SocialObservation: Codable, Identifiable {
    var eventID: UUID
    var eventName: String
    var sourceName: String
    var answers: [String: ObservationAnswer]
    var updatedAt: Double
    var id: String { "\(eventID)-\(sourceName)-\(updatedAt)" }
}
struct DogBlockedUser: Codable, Identifiable { var id: UUID; var name: String }
struct DogPrivateDetails: Codable {
    var vetName = ""
    var vetPhone = ""
    var socialPreference = ""
    var payload: [String: Any] { ["vetName": vetName, "vetPhone": vetPhone, "socialPreference": socialPreference] }
}
struct ExperienceSnapshot: Codable {
    var serverTime = Date.now.timeIntervalSince1970
    var onsite: OnsiteState?
    var memoryAllowed = false
    var targets: [MemoryTarget] = []
    var nameChoices: [String] = []
    var cards: [WarmCard] = []
    var invites: [DogFriendInvite] = []
    var friends: [DogFriend] = []
    var observations: [SocialObservation] = []
    var blocks: [DogBlockedUser] = []
    var privateDetails = DogPrivateDetails()
    func eventCount(_ dimension: SocialDimension) -> Int {
        Set(observations.filter { ["relaxed", "support"].contains($0.answers[dimension.rawValue]?.state ?? "") }.map(\.eventID)).count
    }
}
struct ReceptionTicket: Codable {
    var token: UUID
    var eventID: UUID
}
