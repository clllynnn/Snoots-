import Foundation
import Observation

@MainActor
@Observable
final class MeetupRepository {
    private(set) var meetups: [MeetupRecord] = []
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    var error: String?
    var pendingInvitation: String?
    private var loadedUser: UUID?
    private var preview: MeetupPreviewWorld?
    private var generation = 0
    private var mutationVersion = 0

    func event(_ id: UUID) -> MeetupRecord? { meetups.first { $0.id == id } }
    func reset() {
        generation += 1
        loadedUser = nil; meetups = []; error = nil; preview = nil
        isLoading = false; isSubmitting = false
    }
    func refresh(account: SnootsAccountSession, selected: UUID? = nil, silent: Bool = false) async {
        guard !isSubmitting else { return }
        guard account.userID != nil else { reset(); return }
        if loadedUser != account.userID { reset(); loadedUser = account.userID }
        let currentGeneration = generation
        let currentMutation = mutationVersion
        if !silent { isLoading = true; error = nil }
        defer { if currentGeneration == generation { isLoading = false } }
        do {
            let snapshot: MeetupSnapshot
            if account.usesPreviewAccount {
                if preview == nil { preview = MeetupPreviewWorld(account: account) }
                snapshot = MeetupSnapshot(meetups: preview?.visibleEvents(selected: selected) ?? [], selectedID: selected)
            } else {
                let data = try await account.authenticatedData("rest/v1/rpc/meetup_snapshot", method: "POST",
                    body: JSONSerialization.data(withJSONObject: ["p_selected": selected?.uuidString as Any? ?? NSNull()]))
                snapshot = try JSONDecoder().decode(MeetupSnapshot.self, from: data)
            }
            guard currentGeneration == generation, currentMutation == mutationVersion, account.userID == loadedUser else { return }
            meetups = snapshot.meetups
            if !silent { error = nil }
        } catch {
            guard currentGeneration == generation, currentMutation == mutationVersion else { return }
            self.error = Self.errorText(error)
        }
    }

    @discardableResult
    func command(_ action: String, eventID: UUID, payload: [String: Any] = [:], account: SnootsAccountSession) async -> Bool {
        guard !isSubmitting, let user = account.userID else { return false }
        isSubmitting = true; error = nil
        mutationVersion += 1
        let currentGeneration = generation
        defer { if currentGeneration == generation { isSubmitting = false } }
        do {
            let snapshot: MeetupSnapshot
            if account.usesPreviewAccount {
                if preview == nil { preview = MeetupPreviewWorld(account: account) }
                guard let preview else { return false }
                try preview.command(action, eventID: eventID, payload: payload, user: user)
                snapshot = MeetupSnapshot(meetups: preview.visibleEvents(selected: eventID), selectedID: eventID)
            } else {
                let body: [String: Any] = ["p_action": action, "p_meetup_id": eventID.uuidString, "p_payload": payload]
                let data = try await account.authenticatedData("rest/v1/rpc/meetup_command", method: "POST",
                    body: JSONSerialization.data(withJSONObject: body))
                snapshot = try JSONDecoder().decode(MeetupSnapshot.self, from: data)
            }
            guard currentGeneration == generation, user == account.userID else { return false }
            meetups = snapshot.meetups
            return true
        } catch {
            if currentGeneration == generation { self.error = Self.errorText(error) }
            return false
        }
    }

    private static func errorText(_ error: Error) -> String {
        if error is URLError { return "目前無法連線，請檢查網路後重試。" }
        if error is DecodingError { return "狗聚資料格式尚未就緒，請確認後端已套用狗聚資料表。" }
        return error.localizedDescription
    }
}

struct MeetupPreviewError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Deliberately confined to Debug accounts. These are screen-test fixtures, not real participants.
@MainActor
final class MeetupPreviewWorld {
    private(set) var events: [MeetupRecord] = []
    private var user: UUID
    private var nickname: String
    private var ownDog: MeetupSharedDog
    static let peers = [UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
                        UUID(uuidString: "00000000-0000-0000-0000-000000000012")!]

    init(account: SnootsAccountSession) {
        user = account.userID ?? UUID(); nickname = account.owner?.nickname ?? "測試者"
        let d = account.dog
        ownDog = MeetupSharedDog(name: d?.name, breed: d?.breed, size: d?.size, sex: d?.sex,
            neutered: d?.isNeutered, age: "依本人建檔", reaction: d?.socialStyle, imageName: "Tofu")
        var f = MeetupFormData(); f.title = "示範｜公園慢慢散步"; f.location = "大安森林公園東門"
        f.purpose = "保持距離，讓毛孩依自己的步調認識新朋友。"
        var sample = makeEvent(f, host: Self.peers[0], hostName: "David")
        sample.members = [MeetupMemberRecord(userID: Self.peers[0], nickname: "David", status: "approved",
            dog: MeetupSharedDog(name: "超超", breed: "博美", imageName: "ChaoChao1"))]
        sample.myStatus = nil
        events = [sample]
    }

    func visibleEvents(selected: UUID?) -> [MeetupRecord] {
        events.map { event in
            var result = event
            if !result.hasAccess() { result.messages = []; result.endApplication = nil }
            if result.id != selected { result.messages = [] }
            if let end = result.endedAt, Date.now.timeIntervalSince1970 >= end + MeetupRules.retention { result.status = "archived" }
            return result
        }
    }

    private func makeEvent(_ f: MeetupFormData, host: UUID, hostName: String) -> MeetupRecord {
        MeetupRecord(id: f.id, hostID: host, hostName: hostName, title: f.title,
            startAt: f.start.timeIntervalSince1970, deadline: f.deadline.timeIntervalSince1970,
            location: f.location, navigationURL: f.navigationURL, purpose: f.purpose, pace: f.pace,
            capacity: f.capacity, allowedSizes: f.allowedSizes, venueRules: f.venueRules,
            extraEquipment: f.extraEquipment, announcement: f.announcement, status: "active", endedAt: nil,
            inviteCode: String(f.id.uuidString.prefix(8)), version: 1, infoVersion: 1,
            equipmentVersion: 1, rulesVersion: 1, myStatus: host == user ? "approved" : nil,
            muted: false, unread: 0, confirmations: [:], members: [], messages: [], endApplication: nil)
    }

    func command(_ action: String, eventID: UUID, payload: [String: Any], user: UUID) throws {
        func fail(_ text: String) throws { throw MeetupPreviewError(message: text) }
        if action == "create" {
            if events.contains(where: { $0.id == eventID }) { return }
            var f = MeetupFormData(); f.id = eventID; fill(&f, payload)
            if let validation = f.validation { try fail(validation) }
            var e = makeEvent(f, host: user, hostName: nickname)
            e.members = [MeetupMemberRecord(userID: user, nickname: nickname, status: "approved", dog: ownDog)]
            events.append(e); return
        }
        guard let index = events.firstIndex(where: { $0.id == eventID }) else { try fail("找不到這場狗聚。"); return }
        var e = events[index]
        switch action {
        case "apply":
            if let block = e.applicationBlock(size: ownDog.size) { try fail(block) }
            if e.myStatus == "approved" || e.myStatus == "pending" { return }
            let fields = payload["fields"] as? [String] ?? []
            if !fields.isEmpty, payload["consent"] as? Bool != true { try fail("請先同意帶入資料。") }
            var shared = MeetupSharedDog()
            if fields.contains("basic") { shared.name = ownDog.name; shared.breed = ownDog.breed; shared.size = ownDog.size }
            if fields.contains("sex") { shared.sex = ownDog.sex; shared.neutered = ownDog.neutered }
            if fields.contains("age") { shared.age = ownDog.age }
            if fields.contains("reaction") { shared.reaction = ownDog.reaction }
            e.myStatus = "pending"
            e.members.removeAll { $0.userID == user }
            e.members.append(MeetupMemberRecord(userID: user, nickname: nickname, status: "pending", dog: shared,
                requestID: (payload["requestID"] as? String).flatMap(UUID.init(uuidString:))))
        case "edit":
            guard e.hostID == user, e.status == "active", payload["version"] as? Int == e.version else { try fail("活動已更新或無編輯權限。"); return }
            var f = MeetupFormData(meetup: e); fill(&f, payload)
            if let validation = f.validation { try fail(validation) }
            if f.capacity < e.members.filter({ $0.status == "approved" }).count { try fail("名額不能低於核准人數。") }
            let previous = e
            e = makeEvent(f, host: user, hostName: e.hostName)
            e.members = previous.members; e.messages = previous.messages; e.confirmations = previous.confirmations
            e.inviteCode = previous.inviteCode; e.version = previous.version + 1; e.endApplication = previous.endApplication
            e.infoVersion = previous.infoVersion + (f.title != previous.title || f.start.timeIntervalSince1970 != previous.startAt || f.location != previous.location || f.purpose != previous.purpose || f.pace != previous.pace || f.navigationURL != previous.navigationURL || f.announcement != previous.announcement ? 1 : 0)
            e.rulesVersion = previous.rulesVersion + (f.venueRules != previous.venueRules || f.allowedSizes != previous.allowedSizes ? 1 : 0)
            e.equipmentVersion = previous.equipmentVersion + (f.extraEquipment != previous.extraEquipment ? 1 : 0)
        case "review":
            guard e.hostID == user, let target = (payload["userID"] as? String).flatMap(UUID.init(uuidString:)),
                  let mi = e.members.firstIndex(where: { $0.userID == target && $0.status == "pending" }) else { try fail("申請已變更。"); return }
            let status = payload["status"] as? String ?? "rejected"
            if status == "approved", e.members.filter({ $0.status == "approved" }).count >= e.capacity { try fail("已額滿。") }
            e.members[mi].status = status
        default:
            guard e.hasAccess() else { try fail("活動資格或群組存取已失效。"); return }
            switch action {
            case "confirm":
                let section = payload["section"] as? String ?? "rules"
                guard payload["version"] as? Int == e.confirmationVersion(section) else { try fail("內容已更新，請重新閱讀。"); return }
                e.confirmations[section] = e.confirmationVersion(section)
            case "mute": e.muted = payload["muted"] as? Bool ?? false
            case "read": e.unread = 0
            case "send":
                let text = (payload["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, text.count <= 2000, let id = (payload["messageID"] as? String).flatMap(UUID.init(uuidString:)) else { try fail("訊息不可空白或超過 2000 字。"); return }
                if !e.messages.contains(where: { $0.id == id }) { e.messages.append(MeetupTextMessage(id: id, senderID: user, senderName: nickname, text: text, createdAt: Date.now.timeIntervalSince1970)); e.lastMessage = text }
            case "leave":
                guard e.hostID != user else { try fail("發起人請提出結束申請。"); return }
                e.myStatus = "left"; e.members.removeAll { $0.userID == user }
            case "requestEnd":
                guard e.hostID == user, e.status == "active", e.startedAt == nil else { try fail("已開始的狗聚請從儀表板直接結束。"); return }
                guard !(payload["reason"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { try fail("請填寫取消原因。"); return }
                if e.members.filter({ $0.status == "approved" && $0.userID != user }).isEmpty {
                    e.status = "cancelled"; e.endedAt = Date.now.timeIntervalSince1970
                    for i in e.members.indices where e.members[i].status == "pending" { e.members[i].status = "rejected" }
                    break
                }
                if e.endApplication == nil || e.endApplication!.expiresAt <= Date.now.timeIntervalSince1970 {
                    e.endApplication = MeetupEndApplication(id: UUID(), expiresAt: Date.now.timeIntervalSince1970 + MeetupRules.endRequestLifetime, confirmedBy: [])
                }
            case "approveEnd":
                guard e.hostID != user, var request = e.endApplication, request.expiresAt > Date.now.timeIntervalSince1970 else { try fail("結束申請已失效。"); return }
                if !request.confirmedBy.contains(user) { request.confirmedBy.append(user) }
                e.endApplication = request
                if request.confirmedBy.count >= 2 { e.status = "cancelled"; e.endedAt = Date.now.timeIntervalSince1970; e.endApplication = nil }
            case "report": break // Preview does not send a real report.
            default: try fail("不支援的操作。")
            }
        }
        events[index] = e
    }

    /// Explicit screen-test controls; never compiled into the production UI.
    func simulate(_ action: String, eventID: UUID) {
        guard let i = events.firstIndex(where: { $0.id == eventID }) else { return }
        if action == "onsiteStart" {
            events[i].startedAt = events[i].startedAt ?? Date.now.timeIntervalSince1970
        } else if action == "onsiteEnd" {
            if events[i].endedAt == nil { end(&events[i]) }
        } else if action == "approveMe" {
            events[i].myStatus = "approved"
            if let mi = events[i].members.firstIndex(where: { $0.userID == user }) { events[i].members[mi].status = "approved" }
        } else if action == "applicants" {
            for (n, id) in Self.peers.enumerated() where !events[i].members.contains(where: { $0.userID == id }) {
                events[i].members.append(MeetupMemberRecord(userID: id, nickname: n == 0 ? "David" : "Lynn", status: "pending", dog: MeetupSharedDog(name: n == 0 ? "超超" : "布丁", breed: "博美"), requestID: UUID()))
            }
        } else if action == "twoVotes", events[i].endApplication != nil,
            Self.peers.allSatisfy({ id in events[i].members.contains { $0.userID == id && $0.status == "approved" } }) {
            events[i].status = "cancelled"; events[i].endedAt = Date.now.timeIntervalSince1970; events[i].endApplication = nil
        } else if action == "reply", events[i].hasAccess() {
            events[i].messages.append(MeetupTextMessage(id: UUID(), senderID: Self.peers[0], senderName: "示範參與者", text: "收到，我們會依照自己的步調慢慢認識。", createdAt: Date.now.timeIntervalSince1970))
        }
    }

    private func end(_ event: inout MeetupRecord) {
        event.status = "ended"; event.endedAt = Date.now.timeIntervalSince1970; event.endApplication = nil
        event.messages.append(MeetupTextMessage(id: UUID(), senderID: nil, senderName: "系統", text: "這個群組將於 14 天後關閉，請把握時間聯絡狗友；既有個人聊天室仍可使用。", createdAt: Date.now.timeIntervalSince1970))
    }
    private func fill(_ f: inout MeetupFormData, _ p: [String: Any]) {
        f.title = p["title"] as? String ?? f.title; f.location = p["location"] as? String ?? f.location
        f.start = Date(timeIntervalSince1970: p["startAt"] as? Double ?? f.start.timeIntervalSince1970)
        f.deadline = Date(timeIntervalSince1970: p["deadline"] as? Double ?? f.deadline.timeIntervalSince1970)
        f.purpose = p["purpose"] as? String ?? f.purpose; f.pace = p["pace"] as? String ?? f.pace
        f.navigationURL = p["navigationURL"] as? String ?? f.navigationURL
        f.capacity = p["capacity"] as? Int ?? f.capacity; f.allowedSizes = p["allowedSizes"] as? [String] ?? []
        f.venueRules = p["venueRules"] as? String ?? ""; f.extraEquipment = p["extraEquipment"] as? String ?? ""
        f.announcement = p["announcement"] as? String ?? ""
    }
}

extension MeetupRepository {
    func previewEnd(_ id: UUID) {
        preview?.simulate("onsiteEnd", eventID: id)
        meetups = preview?.visibleEvents(selected: id) ?? meetups
    }
    func simulate(_ action: String, eventID: UUID) {
        preview?.simulate(action, eventID: eventID)
        meetups = preview?.visibleEvents(selected: eventID) ?? meetups
    }
}
