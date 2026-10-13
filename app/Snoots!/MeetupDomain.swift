import Foundation

enum MeetupRules {
    static let retention: TimeInterval = 14 * 24 * 60 * 60
    static let endRequestLifetime: TimeInterval = 48 * 60 * 60
    static let safety = """
    依活動與場地規定使用牽繩，保持飼主可控的距離。
    接近、觸摸或餵食別人的狗狗前，先取得飼主同意。
    不強迫狗狗打招呼、玩耍或分享食物與玩具。
    尊重需要距離、慢慢接近或不互動的界線。
    發現不安或衝突時，先停止互動並拉開距離，可使用現場速查卡及暫離功能。
    當天狀態不適合參加時不勉強出席，透過群組告知發起人。
    """
    static let equipment = "合適的牽繩與胸背／項圈、飲水、水碗、拾便袋。"
    static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }
    static func canAccess(status: String, endedAt: Double?, now: Date = .now) -> Bool {
        status == "active" || (["ended", "cancelled"].contains(status) && endedAt.map { now.timeIntervalSince1970 < $0 + retention } == true)
    }
    static func statusTitle(_ status: String) -> String {
        switch status {
        case "pending": "待審核"
        case "approved": "已核准"
        case "rejected": "未核准"
        case "left": "已退出"
        case "ended": "已結束"
        case "cancelled": "已取消"
        case "archived": "已封存"
        default: "可報名"
        }
    }
}

struct MeetupSharedDog: Codable, Equatable {
    var name: String?
    var breed: String?
    var size: String?
    var sex: String?
    var neutered: Bool?
    var age: String?
    var reaction: String?
    var photoPath: String?
    var imageName: String?
    var summary: String {
        [breed, size.map { ["small": "小型犬", "medium": "中型犬", "large": "大型犬"][$0] ?? $0 }, age, sex.map { $0 == "male" ? "公" : "母" }, neutered.map { $0 ? "已絕育" : "未絕育" }]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

struct MeetupMemberRecord: Codable, Identifiable {
    var id: UUID { userID }
    var userID: UUID
    var nickname: String
    var status: String
    var dog: MeetupSharedDog
    var requestID: UUID?
}

struct MeetupTextMessage: Codable, Identifiable {
    var id: UUID
    var senderID: UUID?
    var senderName: String
    var text: String
    var createdAt: Double
}

struct MeetupEndApplication: Codable {
    var id: UUID
    var expiresAt: Double
    var confirmedBy: [UUID]
    var manualReview: Bool? = nil
    var reason: String? = nil
}

struct MeetupRecord: Codable, Identifiable {
    var id: UUID
    var hostID: UUID
    var hostName: String
    var title: String
    var startAt: Double
    var deadline: Double
    var location: String
    var navigationURL: String
    var purpose: String
    var pace: String
    var capacity: Int
    var allowedSizes: [String]
    var venueRules: String
    var extraEquipment: String
    var announcement: String
    var status: String
    var endedAt: Double?
    var inviteCode: String
    var version: Int
    var infoVersion: Int
    var equipmentVersion: Int
    var rulesVersion: Int
    var myStatus: String?
    var muted: Bool
    var unread: Int
    var lastMessage: String?
    var confirmations: [String: Int]
    var members: [MeetupMemberRecord]
    var messages: [MeetupTextMessage]
    var endApplication: MeetupEndApplication?
    var startedAt: Double? = nil

    var expiry: Date? { endedAt.map { Date(timeIntervalSince1970: $0 + MeetupRules.retention) } }
    func isHost(_ user: UUID?) -> Bool { user == hostID }
    func hasAccess(now: Date = .now) -> Bool {
        myStatus == "approved" && MeetupRules.canAccess(status: status, endedAt: endedAt, now: now)
    }
    func confirmationVersion(_ section: String) -> Int {
        switch section { case "info": infoVersion; case "equipment": equipmentVersion; default: rulesVersion }
    }
    func hasConfirmed(_ section: String) -> Bool { confirmations[section] == confirmationVersion(section) }
    func applicationBlock(size: String?, now: Date = .now) -> String? {
        if status != "active" { return "這場狗聚已結束或取消。" }
        if now.timeIntervalSince1970 >= deadline { return "這場狗聚已截止報名。" }
        if members.filter({ $0.status == "approved" }).count >= capacity { return "這場狗聚已額滿。" }
        if !allowedSizes.isEmpty, let size, !allowedSizes.contains(size) { return "狗狗體型不符合這場的場地條件。" }
        return nil
    }
}

struct MeetupSnapshot: Codable {
    var meetups: [MeetupRecord]
    var selectedID: UUID?
}

struct MeetupFormData {
    var id = UUID()
    var title = ""
    var start = Date.now.addingTimeInterval(7 * 24 * 60 * 60)
    var deadline = Date.now.addingTimeInterval(6 * 24 * 60 * 60)
    var location = ""
    var navigationURL = ""
    var purpose = ""
    var pace = "先保持距離平行散步"
    var capacity = 8
    var allowedSizes: [String] = []
    var venueRules = ""
    var extraEquipment = ""
    var announcement = ""
    var version = 0

    init(meetup: MeetupRecord? = nil) {
        guard let m = meetup else { return }
        id = m.id; title = m.title; start = Date(timeIntervalSince1970: m.startAt)
        deadline = Date(timeIntervalSince1970: m.deadline); location = m.location
        navigationURL = m.navigationURL; purpose = m.purpose; pace = m.pace
        capacity = m.capacity; allowedSizes = m.allowedSizes; venueRules = m.venueRules
        extraEquipment = m.extraEquipment; announcement = m.announcement; version = m.version
    }

    var validation: String? {
        if [title, location, purpose, pace].contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return "請填寫名稱、地點、活動說明及相處步調。" }
        if title.count > 80 || location.count > 200 || purpose.count > 2000 || venueRules.count > 2000 || extraEquipment.count > 1000 || announcement.count > 2000 { return "填寫內容超出長度限制。" }
        if deadline > start { return "報名截止時間不能晚於活動開始。" }
        if start <= .now { return "活動開始時間必須在未來。" }
        if !navigationURL.isEmpty, URL(string: navigationURL)?.scheme != "https" { return "導航網址請使用有效的 HTTPS 連結。" }
        return nil
    }
    var payload: [String: Any] {
        ["title": title, "startAt": start.timeIntervalSince1970, "deadline": deadline.timeIntervalSince1970,
         "location": location, "navigationURL": navigationURL, "purpose": purpose, "pace": pace,
         "capacity": capacity, "allowedSizes": allowedSizes, "venueRules": venueRules,
         "extraEquipment": extraEquipment, "announcement": announcement, "version": version]
    }
}
