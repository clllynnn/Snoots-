import SwiftUI

struct ExperienceStatus: View {
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    var eventID: UUID? = nil
    var body: some View {
        if account.usesPreviewAccount { Label("模擬流程｜非真實簽到、成員或通知", systemImage: "testtube.2").font(.footnote).foregroundStyle(.secondary) }
        if experience.isLoading { ProgressView("正在載入…") }
        if experience.isSubmitting { ProgressView("正在儲存，請稍候…") }
        if let error = experience.error {
            Text(error).foregroundStyle(.red)
            Button("重新載入") { Task { await experience.refresh(account: account, meetups: meetups, eventID: eventID) } }.frame(minHeight: 44)
        }
    }
}

struct OnsiteDashboardScreen: View {
    let eventID: UUID
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmEnd = false
    @State private var confirmStart = false
    @State private var copied = false
    var body: some View {
        List {
            ExperienceStatus(eventID: eventID)
            if let event = meetups.event(eventID), let onsite = experience.snapshot.onsite, onsite.eventID == eventID {
                Section(event.title) {
                    Text(event.location)
                    Label(onsite.startedAt == nil ? "尚未開始" : (onsite.endedAt == nil ? "活動進行中" : "狗聚已結束"), systemImage: "calendar")
                    Text("核准 \(onsite.approvedCount) 位（含發起人）；\(onsite.checkedInCount) 位其他成員已簽到")
                    if onsite.status == "active" {
                        if event.isHost(account.userID), onsite.startedAt == nil, onsite.approvedCount < 5, !onsite.underfilledConfirmed,
                           experience.serverNow >= event.startAt {
                            Text("尚未達一般 5 人成團門檻。請先決定是否照常舉辦；未決定前不能簽到。")
                            Button("確認照常舉辦") { perform("hostDecision") }
                            Text("若不舉辦，請返回狗聚詳情處理取消申請。不得以直接結束取代取消。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        NavigationLink("現場簽到／接待") { NearbyCheckinScreen(eventID: eventID) }
                        NavigationLink("查看並確認安全守則") { MeetupPreparationScreen(eventID: eventID) }
                        if event.isHost(account.userID), onsite.startedAt == nil {
                            Button("開始狗聚") { confirmStart = true }.disabled(onsite.checkedInCount < 3)
                            Text("至少三位其他核准成員完成簽到後，才可開始。未按開始前仍屬尚未實際舉行。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("同場成員") {
                    ForEach(onsite.members) { member in
                        HStack {
                            PrivateExperiencePhoto(bucket: "dog-photos", path: member.photoPath).frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading) {
                                Text(member.name).font(.headline)
                                Text(member.status).foregroundStyle(.secondary)
                                if let reaction = member.reaction { Text(reactionText(reaction)).font(.footnote) }
                            }
                        }
                    }
                }
                if onsite.status == "active", onsite.startedAt != nil {
                    if let me = onsite.members.first(where: { $0.id == account.userID }), me.checkedInAt != nil {
                        Section {
                            Button(me.away ? "返回現場" : "暫離現場") { perform("away", ["away": !me.away]) }
                            Text("暫離只更新現場狀態，保留報名資格與群組聊天室。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Section("狗狗社交反應速查") { BodyLanguageGuide() }
                    Section("優雅退場助手") {
                        Text(exitText)
                        Button(copied ? "已複製文字" : "複製退場訊息") { UIPasteboard.general.string = exitText; copied = true }
                        if event.isHost(account.userID) { Button("結束狗聚", role: .destructive) { confirmEnd = true } }
                    }
                }
                if experience.snapshot.memoryAllowed {
                    Section {
                        NavigationLink("共同回憶與暖心回饋") { EventMemoriesScreen(eventID: eventID) }
                        Text("群組與共同回憶保留 14 天。請及早聯繫想保持聯絡的狗友；個人聊天室不受影響。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                #if DEBUG
                if account.usesPreviewAccount, onsite.startedAt == nil, event.isHost(account.userID) {
                    Section("僅模擬流程") {
                        Button("加入三位已簽到的示範成員") { perform("simulateAttendees") }
                    }
                }
                #endif
            } else if !experience.isLoading {
                ContentUnavailableView("目前無法開啟現場儀表板", systemImage: "lock", description: Text("請確認已核准、活動仍可存取，並重新載入。"))
            }
        }
        .navigationTitle("現場儀表板").navigationBarTitleDisplayMode(.inline)
        .disabled(experience.isSubmitting)
        .task { await reload() }
        .task(id: scenePhase) {
            while !Task.isCancelled, scenePhase == .active {
                try? await Task.sleep(for: .seconds(5)); guard !Task.isCancelled else { return }
                await experience.refresh(account: account, meetups: meetups, eventID: eventID, silent: true)
            }
        }
        .refreshable { await reload() }
        .confirmationDialog("確認開始狗聚？", isPresented: $confirmStart, titleVisibility: .visible) {
            Button("確認開始") { perform("start") }
        } message: { Text("成功儲存後才會標記為已實際舉行，之後可直接結束。") }
        .confirmationDialog("確認結束這場狗聚？", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("確認結束", role: .destructive) { perform("end") }
        } message: { Text("這是已舉行活動的結束，不需要成員審核。結束時間不可重設，群組與共同回憶保留 14 天。") }
    }
    private var exitText: String { "\(account.dog?.name ?? "我家狗狗")今天看起來有點累了，我們今天先散步到這邊，謝謝今天的陪伴！" }
    private func perform(_ action: String, _ payload: [String: Any] = [:]) {
        Task { await experience.command(action, eventID: eventID, payload: payload, account: account, meetups: meetups) }
    }
    private func reload() async {
        await meetups.refresh(account: account, selected: eventID)
        await experience.refresh(account: account, meetups: meetups, eventID: eventID)
    }
    private func reactionText(_ value: String) -> String {
        ["friendly": "主動友好", "observe_then_interact": "先觀察，再互動", "fearful_approach": "害怕，但會嘗試靠近", "fearful_avoid": "害怕並躲開", "bark_or_growl": "吠叫或低吠"][value] ?? value
    }
}

private struct BodyLanguageGuide: View {
    var body: some View {
        Text("觀察全身、距離與互動節奏；單一訊號不能保證安全，也不代表固定人格。不要刻意製造刺激來測試狗狗。")
            .font(.footnote).foregroundStyle(.secondary)
        DisclosureGroup { Text("耳朵自然、身體柔軟，能轉移注意、自在探索或互相忽略。持續看全身與對方反應，維持牽繩管理，不強迫接觸。") } label: { Label("綠燈｜放鬆，持續觀察", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
        DisclosureGroup { Text("撇頭、舔嘴、打哈欠、躲避、僵住等可能表示壓力；也可能受其他情境影響。出現不安就暫停、增加距離，不必等到累積固定個數。") } label: { Label("黃燈｜暫停，給予空間", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
        DisclosureGroup { Text("持續低吼、露齒、衝撞、硬盯或無法控制牽繩時，冷靜停止互動並離開。不要責罵警告訊號；距離以雙方恢復放鬆為準，沒有固定公尺數能保證安全。") } label: { Label("紅燈｜停止互動，立即退場", systemImage: "hand.raised.fill").foregroundStyle(.red) }
        Text("速查卡不會計分，也不是行為診斷。必要時尋求獸醫或合格行為專業協助。")
            .font(.footnote).foregroundStyle(.secondary)
    }
}

struct NearbyCheckinScreen: View {
    let eventID: UUID
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var nearby = NearbyCheckinService()
    @State private var consent = false
    @State private var receiving = false
    @State private var receptionToken: UUID?
    @State private var receptionRun = UUID()
    @State private var manualMember: OnsiteMember?
    var body: some View {
        List {
            ExperienceStatus(eventID: eventID)
            Section {
                Text(nearby.status)
                Text("發起人保持接待畫面開啟；參加者進入可連線範圍並開始搜尋後，由系統驗證及儲存簽到。這不是 NFC 或精確距離感應。")
                Button(isHost ? "開始接待簽到" : "開始尋找發起人") { consent = true }.disabled(nearby.isRunning || receiving)
                if nearby.isRunning || receiving { Button("停止") { stop() } }
                Button("開啟系統設定") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                if let me = experience.snapshot.onsite?.members.first(where: { $0.id == account.userID }), me.checkedInAt != nil {
                    Label("已完成簽到", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            NavigationLink("查看並確認安全守則") { MeetupPreparationScreen(eventID: eventID) }
            if isHost {
                Section("手動備案｜請核對本人與狗狗") {
                    ForEach(experience.snapshot.onsite?.members ?? []) { member in
                        HStack {
                            PrivateExperiencePhoto(bucket: "dog-photos", path: member.photoPath).frame(width: 52, height: 52).clipShape(Circle())
                            VStack(alignment: .leading) { Text(member.name); Text(member.status).font(.footnote).foregroundStyle(.secondary) }
                            Spacer()
                            if member.checkedInAt == nil { Button("簽到") { manualMember = member }.frame(minHeight: 44) }
                        }
                    }
                    Text("手動簽到仍檢查核准資格、安全守則與活動狀態；無網路時不能宣告成功。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else { Text("搜尋不到、拒絕權限或連線失敗時，請發起人核對狗狗資料後手動簽到。") }
        }
        .navigationTitle(isHost ? "簽到接待" : "現場簽到").navigationBarTitleDisplayMode(.inline)
        .task { await experience.refresh(account: account, meetups: meetups, eventID: eventID) }
        .task(id: receiving) {
            guard receiving else { return }
            let run = receptionRun
            while receiving, !Task.isCancelled, scenePhase == .active {
                do {
                    let ticket = try await experience.reception(eventID: eventID, account: account)
                    guard receiving, !Task.isCancelled, scenePhase == .active, receptionRun == run else {
                        await experience.stopReception(eventID: eventID, token: ticket.token, account: account)
                        return
                    }
                    receptionToken = ticket.token
                    try nearby.host(ticket)
                    await experience.refresh(account: account, meetups: meetups, eventID: eventID, silent: true)
                } catch { experience.error = error.localizedDescription; stop(); return }
                try? await Task.sleep(for: .seconds(20))
            }
        }
        .onDisappear { stop() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
        .confirmationDialog("允許尋找本場簽到裝置？", isPresented: $consent, titleVisibility: .visible) {
            Button("繼續") { begin() }
        } message: { Text("將使用本機網路與附近可連線裝置，不公開你的姓名或聯絡資料。僅在此畫面與 App 前景執行；需網路完成後端驗證。") }
        .confirmationDialog("確認本人與狗狗已在現場？", isPresented: Binding(get: { manualMember != nil }, set: { if !$0 { manualMember = nil } }), titleVisibility: .visible) {
            if let member = manualMember { Button("為 \(member.name) 簽到") { Task {
                await experience.command("manualCheckin", eventID: eventID, payload: ["targetID": member.id.uuidString], account: account, meetups: meetups)
                manualMember = nil
            } } }
        } message: { Text("只有成功儲存後才算完成，系統會記錄操作人與時間。") }
    }
    private var isHost: Bool { meetups.event(eventID)?.isHost(account.userID) ?? false }
    private func begin() {
        if account.usesPreviewAccount {
            experience.error = "模擬模式不啟用真實附近連線。請在儀表板使用示範成員，或由模擬發起人手動簽到。"; return
        }
        if isHost { receptionRun = UUID(); receiving = true }
        else { nearby.search(eventID: eventID) { ticket in
            guard scenePhase == .active, nearby.isRunning else { return false }
            return await experience.command("checkin", eventID: eventID, payload: ["token": ticket.token.uuidString], account: account, meetups: meetups)
        } }
    }
    private func stop() {
        receiving = false; receptionRun = UUID(); nearby.stop()
        let token = receptionToken; receptionToken = nil
        if isHost, let token { Task { await experience.stopReception(eventID: eventID, token: token, account: account) } }
    }
}

struct PrivateExperiencePhoto: View {
    let bucket: String
    let path: String?
    @Environment(SnootsAccountSession.self) private var account
    @State private var data: Data?
    @State private var failed = false
    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: failed ? "photo.badge.exclamationmark" : "pawprint.fill").resizable().scaledToFit().padding(12).foregroundStyle(.secondary).background(.quaternary) }
        }
        .clipped()
        .task(id: "\(account.userID?.uuidString ?? "")-\(path ?? "")") {
            data = nil; failed = false
            guard let path else { return }
            if account.usesPreviewAccount {
                let asset = path.hasPrefix("preview/") ? String(path.dropFirst(8)) : ""
                data = UIImage(named: asset)?.jpegData(compressionQuality: 0.8) ?? account.dogPhotoData
                return
            }
            do { data = try await account.authenticatedData("storage/v1/object/authenticated/\(bucket)/\(path)") }
            catch { failed = true }
        }
        .accessibilityLabel(failed ? "照片無法載入" : "狗狗照片")
    }
}
