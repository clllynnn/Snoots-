import Foundation
import Observation

@MainActor @Observable
final class ExperienceRepository {
    private(set) var snapshot = ExperienceSnapshot()
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    var error: String?
    private var user: UUID?
    private var generation = 0
    private var revision = 0
    private var loadedAt = Date.now
    private var preview: ExperiencePreview?
    var serverNow: Double { snapshot.serverTime + Date.now.timeIntervalSince(loadedAt) }

    func reset() {
        generation += 1; revision += 1; user = nil; preview = nil
        snapshot = ExperienceSnapshot(); error = nil; isLoading = false; isSubmitting = false
    }
    func refresh(account: SnootsAccountSession, meetups: MeetupRepository, eventID: UUID? = nil, silent: Bool = false) async {
        guard !isSubmitting else { return }
        if user != account.userID { reset(); user = account.userID }
        guard user != nil else { return }
        let g = generation, r = revision
        if !silent { isLoading = true; error = nil }
        defer { if g == generation { isLoading = false } }
        do {
            let value: ExperienceSnapshot
            if account.usesPreviewAccount {
                if preview == nil { preview = ExperiencePreview() }
                value = preview!.read(account: account, event: eventID.flatMap(meetups.event))
            } else {
                value = try await rpc("experience_snapshot", ["p_event": eventID?.uuidString as Any? ?? NSNull()], account: account)
            }
            guard g == generation, r == revision, user == account.userID else { return }
            snapshot = value; loadedAt = .now
        } catch { if g == generation { self.error = message(error) } }
    }
    @discardableResult
    func command(_ action: String, eventID: UUID? = nil, payload: [String: Any] = [:], account: SnootsAccountSession, meetups: MeetupRepository) async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true; error = nil; revision += 1
        let g = generation, uid = account.userID
        defer { if g == generation { isSubmitting = false } }
        do {
            let value: ExperienceSnapshot
            if account.usesPreviewAccount {
                if preview == nil { preview = ExperiencePreview() }
                value = try preview!.command(action, event: eventID.flatMap(meetups.event), payload: payload, account: account)
                if action == "end", let eventID { meetups.previewEnd(eventID) }
                if action == "start", let eventID { meetups.simulate("onsiteStart", eventID: eventID) }
            } else {
                value = try await rpc("experience_command", ["p_action": action, "p_event": eventID?.uuidString as Any? ?? NSNull(), "p_payload": payload], account: account)
            }
            guard g == generation, uid == account.userID else { return false }
            snapshot = value; loadedAt = .now
            if let eventID, ["end", "start", "hostDecision"].contains(action) {
                await meetups.refresh(account: account, selected: eventID, silent: true)
            }
            return true
        } catch { if g == generation { self.error = message(error) }; return false }
    }
    func reception(eventID: UUID, account: SnootsAccountSession) async throws -> ReceptionTicket {
        guard !account.usesPreviewAccount else { throw MeetupPreviewError(message: "模擬模式不會發布真實簽到服務，請使用模擬簽到。") }
        return try await rpc("experience_command", ["p_action": "reception", "p_event": eventID.uuidString, "p_payload": [:]], account: account)
    }
    func stopReception(eventID: UUID, token: UUID, account: SnootsAccountSession) async {
        guard !account.usesPreviewAccount else { return }
        let _: ExperienceSnapshot? = try? await rpc("experience_command", ["p_action": "stopReception", "p_event": eventID.uuidString, "p_payload": ["token": token.uuidString]], account: account)
    }
    private func rpc<T: Decodable>(_ name: String, _ body: [String: Any], account: SnootsAccountSession) async throws -> T {
        let data = try await account.authenticatedData("rest/v1/rpc/\(name)", method: "POST", body: JSONSerialization.data(withJSONObject: body))
        return try JSONDecoder().decode(T.self, from: data)
    }
    private func message(_ error: Error) -> String {
        if error is URLError { return "目前無法連線；尚未確認成功，請檢查網路後重試。" }
        if error is DecodingError { return "資料格式尚未就緒，請確認已部署 F19–F29 後端版本。" }
        return error.localizedDescription
    }
}

/// Explicit, ephemeral screen fixtures. Never used by real sessions or written to Supabase.
@MainActor private final class ExperiencePreview {
    var data = ExperienceSnapshot()
    var events: [UUID: OnsiteState] = [:]
    var recognized: [UUID: Set<UUID>] = [:]
    var observations: [String: [String: ObservationAnswer]] = [:]
    let peerIDs = (21...23).map { UUID(uuidString: "00000000-0000-0000-0000-0000000000\($0)")! }
    func read(account: SnootsAccountSession, event: MeetupRecord?) -> ExperienceSnapshot {
        data.serverTime = Date.now.timeIntervalSince1970
        data.onsite = nil; data.targets = []; data.nameChoices = []; data.memoryAllowed = false
        if let event, event.hasAccess() {
            if events[event.id] == nil {
                events[event.id] = OnsiteState(eventID: event.id, underfilledConfirmed: false, hostID: event.hostID, status: event.status,
                    approvedCount: event.members.filter { $0.status == "approved" }.count, checkedInCount: 0,
                    members: event.members.filter { $0.status == "approved" }.map {
                        OnsiteMember(id: $0.userID, name: $0.dog.name ?? "示範狗狗", breed: $0.dog.breed ?? "博美", away: false)
                    })
            }
            data.onsite = events[event.id]
            data.memoryAllowed = events[event.id]?.endedAt.map { data.serverTime < $0 + MeetupRules.retention } ?? false
            if data.memoryAllowed, let members = data.onsite?.members {
                data.targets = members.filter { member in member.id != account.userID && member.checkedInAt != nil && !data.blocks.contains(where: { b in b.id == member.id }) }.map { member in
                    let unlocked = recognized[event.id, default: []].contains(member.id)
                    return MemoryTarget(id: member.id, name: unlocked ? member.name : nil, breed: member.breed, photoPath: member.photoPath, recognized: unlocked,
                        answers: observations["\(event.id)-\(member.id)"] ?? [:], cardSent: data.cards.contains { $0.eventID == event.id && $0.recipientID == member.id })
                }
                data.nameChoices = members.filter { $0.id != account.userID && $0.checkedInAt != nil }.map(\.name)
            }
        }
        return data
    }
    func command(_ action: String, event: MeetupRecord?, payload: [String: Any], account: SnootsAccountSession) throws -> ExperienceSnapshot {
        guard let user = account.userID else { throw MeetupPreviewError(message: "請先登入。") }
        _ = read(account: account, event: event)
        let now = Date.now.timeIntervalSince1970
        let target = (payload["targetID"] as? String).flatMap(UUID.init(uuidString:))
        let id = (payload["id"] as? String).flatMap(UUID.init(uuidString:))
        func fail(_ text: String) throws { throw MeetupPreviewError(message: text) }
        if let event, var onsite = events[event.id] {
            switch action {
            case "simulateAttendees":
                for (i, id) in peerIDs.enumerated() where !onsite.members.contains(where: { $0.id == id }) {
                    onsite.members.append(OnsiteMember(id: id, name: ["超超", "麻糬", "小白"][i], breed: "博美", photoPath: "preview/\(["ChaoChao1", "Mochi", "Tofu"][i])", checkedInAt: now, method: "manual", away: false))
                }
                onsite.checkedInCount = onsite.members.filter { $0.id != event.hostID && $0.checkedInAt != nil }.count
                onsite.approvedCount = onsite.members.count; onsite.underfilledConfirmed = true
            case "hostDecision": onsite.underfilledConfirmed = true
            case "manualCheckin", "checkin":
                guard event.hasConfirmed("rules") else { try fail("請先確認安全守則。"); return data }
                let checking = target ?? user
                if let i = onsite.members.firstIndex(where: { $0.id == checking }) { onsite.members[i].checkedInAt = now; onsite.members[i].method = "manual" }
                onsite.checkedInCount = onsite.members.filter { $0.id != event.hostID && $0.checkedInAt != nil }.count
            case "start":
                guard event.hostID == user, onsite.checkedInCount >= 3, event.hasConfirmed("rules") else { try fail("需三位其他核准成員簽到，並確認安全守則。"); return data }
                onsite.startedAt = onsite.startedAt ?? now
                if let i = onsite.members.firstIndex(where: { $0.id == user }) { onsite.members[i].checkedInAt = now }
            case "end":
                guard event.hostID == user, onsite.startedAt != nil else { try fail("只有發起人可結束已開始的狗聚。"); return data }
                onsite.endedAt = onsite.endedAt ?? now; onsite.status = "ended"
            case "away":
                if let i = onsite.members.firstIndex(where: { $0.id == user }) { onsite.members[i].away = payload["away"] as? Bool ?? false }
            case "recognize":
                guard let target, onsite.members.first(where: { $0.id == target })?.name == payload["answer"] as? String else { try fail("再想一下，或先跳過這隻狗狗。"); return data }
                recognized[event.id, default: []].insert(target)
            case "observation", "sendCard":
                guard let target, recognized[event.id, default: []].contains(target), data.memoryAllowed else { try fail("請先完成同場辨識。"); return data }
                let answers = try JSONDecoder().decode([String: ObservationAnswer].self, from: JSONSerialization.data(withJSONObject: payload["answers"] ?? [:]))
                observations["\(event.id)-\(target)"] = answers
                if action == "sendCard", let id, !data.cards.contains(where: { $0.id == id }) {
                    data.cards.append(WarmCard(id: id, eventID: event.id, senderID: user, recipientID: target, senderName: account.dog?.name ?? "我的狗狗",
                        recipientName: onsite.members.first(where: { $0.id == target })?.name ?? "示範狗狗", body: payload["body"] as? String ?? "", tags: payload["tags"] as? [String] ?? [], photoPath: payload["photoPath"] as? String, sentAt: now, acknowledged: false, withdrawalUnread: false))
                }
            case "retractObservation": if let target { observations["\(event.id)-\(target)"] = nil }
            case "simulateReceived":
                guard let peer = onsite.members.first(where: { $0.id != user }) else { return data }
                data.cards.append(WarmCard(id: UUID(), eventID: event.id, senderID: peer.id, recipientID: user, senderName: peer.name,
                    recipientName: account.dog?.name ?? "我的狗狗", body: "謝謝今天一起安靜散步！", tags: ["平行散步自在"], sentAt: now, acknowledged: false, withdrawalUnread: false))
                data.observations.append(SocialObservation(eventID: event.id, eventName: event.title, sourceName: peer.name,
                    answers: ["dogs": ObservationAnswer(state: "relaxed", labels: ["平行散步自在"])], updatedAt: now))
            default: break
            }
            events[event.id] = onsite
        }
        if let i = data.cards.firstIndex(where: { $0.id == id }) {
            switch action {
            case "readCard":
                if data.cards[i].retractedAt != nil { data.cards[i].withdrawalUnread = false }
                else { data.cards[i].viewedAt = data.cards[i].viewedAt ?? now }
            case "acknowledge": data.cards[i].acknowledged = true
            case "retractCard":
                guard data.cards[i].canRetract(now: now) else { try fail("已超過撤回期限。"); return data }
                data.cards[i].retractedAt = now; data.cards[i].withdrawalUnread = data.cards[i].viewedAt != nil
                observations["\(data.cards[i].eventID)-\(data.cards[i].recipientID)"] = nil
            case "invite":
                let c = data.cards[i]
                if !data.invites.contains(where: { $0.senderID == user && $0.recipientID == c.senderID }) {
                    data.invites.append(DogFriendInvite(id: UUID(), senderID: user, recipientID: c.senderID, senderName: c.recipientName, recipientName: c.senderName, createdAt: now, accepted: false))
                }
            default: break
            }
        }
        if action == "simulateAccept", let i = data.invites.firstIndex(where: { $0.id == id }) {
            data.invites[i].accepted = true
            let invite = data.invites[i]
            if !data.friends.contains(where: { $0.userID == invite.recipientID }) {
                data.friends.append(DogFriend(id: UUID(), userID: invite.recipientID, name: invite.recipientName, nickname: "示範飼主", unread: 0, messages: []))
            }
        }
        if action == "sendMessage", let i = data.friends.firstIndex(where: { $0.id.uuidString == payload["friendshipID"] as? String }), let id {
            if !data.friends[i].messages.contains(where: { $0.id == id }) {
                data.friends[i].messages.append(DogDirectMessage(id: id, senderID: user, text: payload["body"] as? String ?? "", createdAt: now))
            }
        }
        if action == "block", let target, let friend = data.friends.first(where: { $0.userID == target }) {
            data.blocks.append(DogBlockedUser(id: target, name: friend.name)); data.friends.removeAll { $0.userID == target }
        }
        if action == "unblock" { data.blocks.removeAll { $0.id == target } }
        if action == "privateDetails" { data.privateDetails = try JSONDecoder().decode(DogPrivateDetails.self, from: JSONSerialization.data(withJSONObject: payload)) }
        return read(account: account, event: event)
    }
}
