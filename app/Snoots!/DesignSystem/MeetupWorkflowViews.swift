import MapKit
import SwiftUI

struct MeetupHubView: View {
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    @State private var tab = 0
    @State private var creating = false
    @State private var invite = ""
    @State private var invitationID: UUID?
    @State private var inviteError: String?

    private var filtered: [MeetupRecord] {
        repository.meetups.filter { tab == 0 ? $0.isHost(account.userID) : !$0.isHost(account.userID) && $0.myStatus != nil }
    }
    var body: some View {
        List {
            MeetupServiceStatus()
            Section {
                Picker("我的狗聚", selection: $tab) {
                    Text("已發起").tag(0); Text("已報名").tag(1)
                }.pickerStyle(.segmented)
                NavigationLink { MeetupBrowseView() } label: { Label("瀏覽狗聚", systemImage: "magnifyingglass") }
                Button { creating = true } label: { Label("發起狗聚", systemImage: "plus.circle") }
            }
            Section("邀請加入") {
                TextField("貼上邀請連結或輸入邀請碼", text: $invite)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("查看邀請的狗聚") { resolveInvite() }.disabled(invite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let inviteError { Text(inviteError).foregroundStyle(.red) }
            }
            Section(tab == 0 ? "已發起" : "已報名") {
                if filtered.isEmpty && !repository.isLoading {
                    ContentUnavailableView(tab == 0 ? "尚未發起狗聚" : "尚未報名狗聚", systemImage: "calendar", description: Text("可以瀏覽其他狗聚，或發起自己的活動。"))
                }
                ForEach(filtered) { event in
                    NavigationLink { MeetupDetailScreen(eventID: event.id) } label: { MeetupSummaryRow(event: event) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            #if DEBUG
            if account.usesPreviewAccount {
                Button("建立現場流程示範（我是發起人）") { Task {
                    var form = MeetupFormData()
                    form.title = "示範｜現場與暖心回饋"; form.location = "示範公園集合點"
                    form.purpose = "測試簽到、結束狗聚、辨識與回饋。非真實活動。"
                    form.start = .now.addingTimeInterval(60); form.deadline = .now.addingTimeInterval(30)
                    if await repository.command("create", eventID: form.id, payload: form.payload, account: account) { invitationID = form.id }
                } }.font(.footnote).padding().frame(minHeight: 44).background(.bar).disabled(repository.isSubmitting)
            }
            #endif
        }
        .navigationTitle("我的狗聚")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await repository.refresh(account: account)
            consumeInvitation()
        }
        .refreshable { await repository.refresh(account: account) }
        .sheet(isPresented: $creating) { NavigationStack { MeetupEditorScreen() } }
        .navigationDestination(item: $invitationID) { MeetupDetailScreen(eventID: $0) }
        .onChange(of: repository.pendingInvitation) { _, _ in consumeInvitation() }
    }

    private func consumeInvitation() {
        guard let code = repository.pendingInvitation, !repository.isLoading else { return }
        invite = code
        repository.pendingInvitation = nil
        resolveInvite()
    }

    private func resolveInvite() {
        let input = invite.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = URLComponents(string: input)
        let code = components?.queryItems?.first(where: { $0.name == "code" })?.value ?? input
        if let event = repository.meetups.first(where: { $0.inviteCode.caseInsensitiveCompare(code) == .orderedSame }) {
            invitationID = event.id; inviteError = nil
        } else { inviteError = "邀請已失效、活動不在本次測試範圍，或目前資料尚未載入。請重新載入後確認邀請碼。" }
    }
}

struct MeetupServiceStatus: View {
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    var body: some View {
        if account.usesPreviewAccount {
            Section { Label("模擬資料｜僅供畫面流程測試，不會通知真實使用者", systemImage: "testtube.2").font(.footnote).foregroundStyle(.secondary) }
        }
        if repository.isLoading { ProgressView("正在載入狗聚…") }
        if let error = repository.error {
            Section {
                Text(error).foregroundStyle(.red)
                Button("重新載入") { Task { await repository.refresh(account: account) } }
            }
        }
    }
}

struct MeetupSummaryRow: View {
    let event: MeetupRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image("MeetupHeroDogs").resizable().scaledToFill().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title).font(.headline)
                    Text(MeetupRules.dateText(Date(timeIntervalSince1970: event.startAt))).font(.subheadline)
                    Text(event.location).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text(MeetupRules.statusTitle(event.status == "active" ? event.myStatus ?? "active" : event.status))
                    .font(.caption.weight(.semibold)).padding(6).background(.quaternary, in: Capsule())
                Text("\(event.members.filter { $0.status == "approved" }.count)／\(event.capacity) 位").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if event.unread > 0 { Text("\(event.unread)").font(.caption.bold()).foregroundStyle(.white).padding(7).background(.black, in: Circle()) }
                if event.muted { Image(systemName: "bell.slash").accessibilityLabel("已靜音") }
            }
        }.padding(.vertical, 6)
    }
}

struct MeetupBrowseView: View {
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    var body: some View {
        List {
            MeetupServiceStatus()
            if repository.meetups.filter({ $0.status == "active" }).isEmpty && !repository.isLoading {
                ContentUnavailableView("目前沒有可瀏覽的狗聚", systemImage: "calendar", description: Text("請稍後重新整理，或回到我的狗聚發起活動。"))
            }
            ForEach(repository.meetups.filter { $0.status == "active" }) { event in
                NavigationLink { MeetupDetailScreen(eventID: event.id) } label: { MeetupSummaryRow(event: event) }
            }
        }
        .navigationTitle("瀏覽狗聚").navigationBarTitleDisplayMode(.inline)
        .refreshable { await repository.refresh(account: account) }
    }
}

struct MeetupDetailScreen: View {
    let eventID: UUID
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    @State private var editing = false
    @State private var applying = false
    @State private var confirmingEnd = false
    @State private var endRequestID = UUID()
    @State private var cancellationReason = ""
    @State private var reportReason = ""
    @State private var showReport = false
    @State private var result: String?
    var body: some View {
        List {
            MeetupServiceStatus()
            if let event = repository.event(eventID) {
                Section {
                    Image("MeetupHeroDogs").resizable().scaledToFill().frame(height: 170).clipped().listRowInsets(EdgeInsets())
                    MeetupSummaryRow(event: event)
                    Text("發起人：\(event.hostName)")
                    Text("報名截止：\(MeetupRules.dateText(Date(timeIntervalSince1970: event.deadline)))")
                    Text(event.purpose)
                    LabeledContent("相處步調", value: event.pace)
                    if !event.allowedSizes.isEmpty { Text("場地體型條件：\(event.allowedSizes.map(sizeLabel).joined(separator: "、"))") }
                    if !event.venueRules.isEmpty { Text("場地規定：\(event.venueRules)") }
                    if let url = navigationLink(event) { Link("開啟地圖導航", destination: url).frame(minHeight: 44) }
                    if let expiry = event.expiry { Text("群組與共同回憶保留至：\(MeetupRules.dateText(expiry))（台灣時間）").font(.footnote).foregroundStyle(.secondary) }
                }
                if event.status == "active", !event.isHost(account.userID), event.myStatus != "approved", event.myStatus != "pending" {
                    Section {
                        if let block = event.applicationBlock(size: account.dog?.size) { Text(block).foregroundStyle(.secondary) }
                        else { Button("報名參加") { applying = true }.frame(minHeight: 44) }
                    }
                }
                if event.myStatus == "pending" { Section { Label("報名已送出，等待發起人審核", systemImage: "hourglass") } }
                if event.myStatus == "rejected" { Section { Text("此次申請未獲核准。") } }
                if event.hasAccess() {
                    Section("活動入口") {
                        NavigationLink("群組聊天室") { MeetupConversationScreen(eventID: eventID) }
                        NavigationLink("行前準備與安全守則") { MeetupPreparationScreen(eventID: eventID) }
                        if event.status == "active" { NavigationLink("現場儀表板與簽到") { OnsiteDashboardScreen(eventID: eventID) } }
                        if event.status == "ended" { NavigationLink("共同回憶與暖心回饋") { EventMemoriesScreen(eventID: eventID) } }
                    }
                    if event.isHost(account.userID), event.status == "active" {
                        Section("發起人管理") {
                            Button("編輯狗聚與公告") { editing = true }
                            NavigationLink("審核報名申請") { MeetupReviewScreen(eventID: eventID) }
                            if event.startedAt == nil {
                            TextField("取消原因（取消活動時必填）", text: $cancellationReason, axis: .vertical)
                            Button("取消尚未舉行的狗聚", role: .destructive) { confirmingEnd = true }
                                .disabled(event.endApplication != nil)
                            }
                        }
                    }
                    if let request = event.endApplication {
                        Section("取消申請（尚未舉行）") {
                            Text(request.manualReview == true ? "等待後台審核；僅一位其他核准者的申請，24 小時未審核自動通過。" : "需兩位不同的其他核准參與者同意，目前 \(request.confirmedBy.count)／2 位。")
                            if let reason = request.reason { Text("取消原因：\(reason)") }
                            Text("有效至 \(MeetupRules.dateText(Date(timeIntervalSince1970: request.expiresAt)))（台灣時間）")
                            if request.manualReview != true, !event.isHost(account.userID), let user = account.userID, !request.confirmedBy.contains(user) {
                                Button("我同意取消這場狗聚", role: .destructive) { confirmingEnd = true }
                            }
                        }
                    }
                    if !event.isHost(account.userID) { Section { Button("檢舉這場狗聚", role: .destructive) { showReport = true } } }
                    MeetupPreviewControls(eventID: eventID)
                } else if event.status == "archived" {
                    Section { Text("保留期限已結束，群組與共同回憶已封存。既有個人聊天室仍可使用。") }
                }
                if account.usesPreviewAccount, event.myStatus == "pending" {
                    Section("模擬操作") { Button("模擬發起人核准我") { repository.simulate("approveMe", eventID: eventID) } }
                }
                Section { ShareLink(item: URL(string: "snoots://meetup?code=\(event.inviteCode)")!) { Label("分享狗聚邀請", systemImage: "square.and.arrow.up") }; Text("邀請碼：\(event.inviteCode)").font(.footnote).textSelection(.enabled) }
            } else if !repository.isLoading { ContentUnavailableView("找不到可存取的狗聚", systemImage: "lock", description: Text("請重新載入或確認目前活動資格。")) }
        }
        .navigationTitle(repository.event(eventID)?.title ?? "狗聚詳情").navigationBarTitleDisplayMode(.inline)
        .task { await repository.refresh(account: account, selected: eventID) }
        .refreshable { await repository.refresh(account: account, selected: eventID) }
        .sheet(isPresented: $editing) { NavigationStack { MeetupEditorScreen(eventID: eventID) } }
        .sheet(isPresented: $applying) { NavigationStack { MeetupApplicationScreen(eventID: eventID) } }
        .confirmationDialog("確認申請／同意取消尚未舉行的狗聚？", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("確認", role: .destructive) {
                guard let event = repository.event(eventID) else { return }
                Task {
                    let isHost = event.isHost(account.userID)
                    let id = isHost ? endRequestID : event.endApplication?.id ?? UUID()
                    if await repository.command(isHost ? "requestEnd" : "approveEnd", eventID: eventID, payload: ["requestID": id.uuidString, "reason": cancellationReason], account: account) {
                        if isHost { endRequestID = UUID() }
                        result = isHost ? "已送出取消操作，請以活動與申請狀態為準。" : "已記錄你的同意。"
                    }
                }
            }
        } message: { Text("本操作僅供尚未舉行的活動；已開始請到現場儀表板直接結束。取消後群組唯讀保留 14 天，不開放共同回憶。") }
        .alert("檢舉狗聚", isPresented: $showReport) {
            TextField("請描述具體情況", text: $reportReason)
            Button("送出") { Task {
                if await repository.command("report", eventID: eventID, payload: ["reason": reportReason], account: account) { result = account.usesPreviewAccount ? "已模擬檢舉；沒有送出真實案件。" : "檢舉已送交系統。" }
            } }
            Button("取消", role: .cancel) {}
        } message: { Text("至少 5 位不同參與者檢舉後交後台審查，不會自動結束活動。") }
        .alert("操作結果", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) { Button("知道了") { result = nil } } message: { Text(result ?? "") }
        .disabled(repository.isSubmitting)
    }
}

struct MeetupEditorScreen: View {
    var eventID: UUID?
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var form = MeetupFormData()
    @State private var validation: String?
    var body: some View {
        Form {
            Section("預設封面") { Image("MeetupHeroDogs").resizable().scaledToFit().frame(maxHeight: 160) }
            Section("活動資訊") {
                TextField("狗聚名稱", text: $form.title)
                DatePicker("活動開始", selection: $form.start)
                DatePicker("報名截止", selection: $form.deadline)
                TextField("集合地點", text: $form.location)
                TextField("導航網址（選填）", text: $form.navigationURL).textInputAutocapitalization(.never).keyboardType(.URL)
                TextField("活動主旨", text: $form.purpose, axis: .vertical).lineLimit(3...6)
                Picker("相處步調", selection: $form.pace) {
                    ForEach(["先保持距離平行散步", "遠處觀察後逐步靠近", "雙方放鬆時短暫打招呼"], id: \.self) { Text($0).tag($0) }
                }
                Stepper("名額 \(form.capacity) 位（含發起人）", value: $form.capacity, in: 2...30)
            }
            Section("明確場地條件") {
                Text("未限制體型時，保持以下選項皆未選取。年齡、絕育及陌生狗反應交由發起人審核參考。")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(["small", "medium", "large"], id: \.self) { size in
                    Toggle(sizeLabel(size), isOn: Binding(get: { form.allowedSizes.contains(size) }, set: { selected in
                        form.allowedSizes.removeAll { $0 == size }; if selected { form.allowedSizes.append(size) }
                    }))
                }
                TextField("場地補充守則（選填）", text: $form.venueRules, axis: .vertical).lineLimit(3...6)
                TextField("額外攜帶用品（選填）", text: $form.extraEquipment, axis: .vertical)
            }
            Section("行前公告") { TextField("公告內容（選填）", text: $form.announcement, axis: .vertical).lineLimit(3...6) }
            if let text = validation ?? repository.error { Section { Text(text).foregroundStyle(.red) } }
            if repository.isSubmitting { ProgressView("正在儲存…") }
        }
        .navigationTitle(eventID == nil ? "發起狗聚" : "編輯狗聚").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(repository.isSubmitting) }
            ToolbarItem(placement: .confirmationAction) { Button("儲存") { save() }.disabled(repository.isSubmitting) }
        }
        .onAppear { if let eventID, let event = repository.event(eventID) { form = MeetupFormData(meetup: event) } }
        .interactiveDismissDisabled(repository.isSubmitting)
        .environment(\.timeZone, TimeZone(identifier: "Asia/Taipei")!)
    }
    private func save() {
        validation = form.validation; guard validation == nil else { return }
        Task { if await repository.command(eventID == nil ? "create" : "edit", eventID: form.id, payload: form.payload, account: account) { dismiss() } }
    }
}

struct MeetupApplicationScreen: View {
    let eventID: UUID
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var fields: Set<String> = ["basic", "sex", "age", "reaction"]
    @State private var consent = false
    @State private var requestID = UUID()
    var body: some View {
        Form {
            Section {
                Text("以下資料取自你的狗狗檔案，僅供這場發起人審核。選擇分享項目並同意後直接帶入，不需重填。")
                Text("私人聯絡資訊、未同意揭露的健康資訊與本人社交數值不會帶入。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("確認分享內容") {
                field("basic", title: "狗狗基本資料", value: [account.dog?.name, account.dog?.breed, account.dog.map { sizeLabel($0.size) }].compactMap { $0 }.joined(separator: " · "))
                field("sex", title: "性別與絕育", value: account.dog.map { "\($0.sex == "male" ? "公" : "母") · \($0.isNeutered ? "已絕育" : "未絕育")" } ?? "尚未填寫")
                field("age", title: "年齡", value: account.matchingProfile?.birthDate.map { "\(Calendar.current.dateComponents([.year], from: $0, to: .now).year ?? 0) 歲" } ?? "尚未填寫")
                field("reaction", title: "陌生狗反應", value: reactionLabel(account.dog?.socialStyle ?? ""))
                Toggle("我同意將勾選資料提供給本場發起人審核", isOn: $consent)
            }
            if let error = repository.error { Text(error).foregroundStyle(.red) }
            if repository.isSubmitting { ProgressView("正在送出報名…") }
            Button("送出報名") {
                Task {
                    if await repository.command("apply", eventID: eventID,
                        payload: ["fields": Array(fields).sorted(), "consent": consent, "requestID": requestID.uuidString], account: account) { dismiss() }
                }
            }.disabled(repository.isSubmitting || (!fields.isEmpty && !consent))
        }
        .navigationTitle("報名參加").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(repository.isSubmitting) } }
        .interactiveDismissDisabled(repository.isSubmitting)
    }
    private func field(_ id: String, title: String, value: String) -> some View {
        Toggle(isOn: Binding(get: { fields.contains(id) }, set: { selected in
            if selected { fields.insert(id) } else { fields.remove(id) }; consent = false
        })) { VStack(alignment: .leading) { Text(title); Text(value).font(.subheadline).foregroundStyle(.secondary) } }
    }
}

struct MeetupReviewScreen: View {
    let eventID: UUID
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    var body: some View {
        List {
            MeetupServiceStatus()
            if let event = repository.event(eventID), event.isHost(account.userID), event.hasAccess() {
                let applicants = event.members.filter { $0.status == "pending" }
                if applicants.isEmpty { ContentUnavailableView("沒有待審核申請", systemImage: "person.crop.circle.badge.checkmark") }
                ForEach(applicants) { member in
                    Section(member.nickname) {
                        MeetupReviewPhoto(dog: member.dog)
                        Text(member.dog.name ?? "未同意分享狗狗名稱")
                        Text(member.dog.summary.isEmpty ? "未分享額外資料" : member.dog.summary)
                        if let reaction = member.dog.reaction { Text(reactionLabel(reaction)) }
                        Button("核准") { review(member, approved: true) }
                        Button("拒絕", role: .destructive) { review(member, approved: false) }
                    }
                }
            } else { ContentUnavailableView("無審核權限", systemImage: "lock") }
        }
        .navigationTitle("報名審核").navigationBarTitleDisplayMode(.inline)
        .refreshable { await repository.refresh(account: account, selected: eventID) }
        .disabled(repository.isSubmitting)
    }
    private func review(_ member: MeetupMemberRecord, approved: Bool) {
        guard let requestID = member.requestID else { return }
        Task { await repository.command("review", eventID: eventID, payload: ["userID": member.userID.uuidString, "requestID": requestID.uuidString, "status": approved ? "approved" : "rejected"], account: account) }
    }
}

struct MeetupPreparationScreen: View {
    let eventID: UUID
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    var body: some View {
        List {
            MeetupServiceStatus()
            if let event = repository.event(eventID), event.hasAccess() {
                Section("集合資訊") {
                    Text(event.title)
                    Text(MeetupRules.dateText(Date(timeIntervalSince1970: event.startAt)))
                    Text(event.location); Text(event.purpose); Text(event.pace)
                    if !event.announcement.isEmpty { Text("行前公告：\(event.announcement)") }
                    if let url = navigationLink(event) { Link("開啟地圖導航", destination: url) }
                    confirmButton("info", title: "我已確認集合資訊", event: event)
                }
                Section("攜帶用品") {
                    Text(MeetupRules.equipment)
                    if !event.extraEquipment.isEmpty { Text(event.extraEquipment) }
                    Text("確認代表知道需要準備哪些用品，不代表完成現場檢查。無需上傳照片。")
                        .font(.footnote).foregroundStyle(.secondary)
                    confirmButton("equipment", title: "我已確認準備清單", event: event)
                }
                Section("安全守則") {
                    Text(MeetupRules.safety)
                    if !event.venueRules.isEmpty { Text("場地補充守則\n\(event.venueRules)") }
                    if !event.allowedSizes.isEmpty { Text("場地體型條件：\(event.allowedSizes.map(sizeLabel).joined(separator: "、"))") }
                    Text("這是行為承諾，不是安全認證或免責保證。簽到前須完成本場目前版本的確認。")
                        .font(.footnote).foregroundStyle(.secondary)
                    confirmButton("rules", title: "我已閱讀並同意遵守", event: event)
                }
            } else { ContentUnavailableView("尚未取得活動資格", systemImage: "lock") }
        }
        .navigationTitle("行前準備").navigationBarTitleDisplayMode(.inline)
        .task { await repository.refresh(account: account, selected: eventID) }
    }
    private func confirmButton(_ section: String, title: String, event: MeetupRecord) -> some View {
        Button {
            Task { await repository.command("confirm", eventID: eventID, payload: ["section": section, "version": event.confirmationVersion(section)], account: account) }
        } label: { Label(event.hasConfirmed(section) ? "已確認" : title, systemImage: event.hasConfirmed(section) ? "checkmark.circle.fill" : "circle") }
        .frame(minHeight: 44).disabled(repository.isSubmitting || event.hasConfirmed(section))
    }
}

struct MeetupGroupListSection: View {
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("你的狗聚群組").font(.title2.bold())
            if account.usesPreviewAccount { Text("模擬群組｜畫面測試資料").font(.footnote).foregroundStyle(.secondary) }
            if repository.isLoading { ProgressView("正在載入…") }
            if let error = repository.error { Text(error).foregroundStyle(.red); Button("重試") { Task { await repository.refresh(account: account) } } }
            if repository.meetups.filter({ $0.hasAccess() }).isEmpty && !repository.isLoading { ContentUnavailableView("尚無狗聚群組", systemImage: "bubble.left.and.bubble.right", description: Text("報名獲核准後，群組會出現在這裡。")) }
            ForEach(repository.meetups.filter { $0.hasAccess() }) { event in
                NavigationLink { MeetupConversationScreen(eventID: event.id) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        MeetupSummaryRow(event: event)
                        Text(event.lastMessage ?? "開始和狗聚夥伴交流").font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }.padding(16).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
            }
        }.task { await repository.refresh(account: account) }
    }
}

struct MeetupConversationScreen: View {
    let eventID: UUID
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = ""
    @State private var messageID = UUID()
    @State private var failedDraft: String?
    @State private var showLeave = false
    var body: some View {
        VStack(spacing: 0) {
            if let event = repository.event(eventID), event.hasAccess() {
                if let expiry = event.expiry { Text("群組保留至 \(MeetupRules.dateText(expiry))（台灣時間）").font(.footnote).padding(12) }
                NavigationLink { MeetupPreparationScreen(eventID: eventID) } label: { Label("行前準備與安全守則", systemImage: "checkmark.shield").frame(maxWidth: .infinity, minHeight: 44) }
                if !event.announcement.isEmpty { Text("公告：\(event.announcement)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.quaternary) }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if event.messages.isEmpty { ContentUnavailableView("開始群組交流", systemImage: "bubble.left.and.bubble.right", description: Text("可以傳送文字，和狗聚夥伴確認細節。")) }
                            ForEach(event.messages) { message in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(message.senderName).font(.caption).foregroundStyle(.secondary)
                                    Text(message.text).font(.body).textSelection(.enabled)
                                    Text(Date(timeIntervalSince1970: message.createdAt), format: .dateTime.hour().minute()).font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .background(message.senderID == account.userID ? Color.green.opacity(0.13) : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                                .frame(maxWidth: .infinity, alignment: message.senderID == account.userID ? .trailing : .leading)
                                .id(message.id)
                            }
                        }.padding(16)
                    }.onChange(of: event.messages.count) { _, _ in if let id = event.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
                }
                if let error = repository.error {
                    VStack { Text(error).font(.footnote).foregroundStyle(.red); Button("重新載入") { Task { await repository.refresh(account: account, selected: eventID) } } }.padding(8)
                }
                if failedDraft != nil { Button("重試傳送上一則訊息") { send(retry: true) }.disabled(repository.isSubmitting).padding(8) }
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("輸入訊息", text: $draft, axis: .vertical).lineLimit(1...5).textFieldStyle(.roundedBorder)
                        .disabled(failedDraft != nil)
                    Button { send(retry: false) } label: {
                        if repository.isSubmitting { ProgressView() } else { Image(systemName: "arrow.up.circle.fill").font(.title) }
                    }.frame(width: 44, height: 44).accessibilityLabel("傳送訊息")
                        .disabled(repository.isSubmitting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || failedDraft != nil)
                }.padding(12).background(.bar).disabled(event.status == "cancelled")
                if event.status == "cancelled" { Text("活動已取消，群組唯讀保留 14 天。") .font(.footnote).padding(8) }
                if account.usesPreviewAccount, event.status != "cancelled" { Button("模擬參與者回覆") { repository.simulate("reply", eventID: eventID) }.font(.footnote).padding(8) }
            } else { ContentUnavailableView("群組存取已失效", systemImage: "lock", description: Text("活動資格變更或 14 天期限已結束。個人聊天室不受影響。")) }
        }
        .navigationTitle(repository.event(eventID)?.title ?? "狗聚群組").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink("活動詳情") { MeetupDetailScreen(eventID: eventID) }
                    NavigationLink("群組成員") { MeetupMembersScreen(eventID: eventID) }
                    if let event = repository.event(eventID) {
                        Button(event.muted ? "取消靜音" : "靜音") { Task { await repository.command("mute", eventID: eventID, payload: ["muted": !event.muted], account: account) } }
                        if !event.isHost(account.userID) { Button("離開群組", role: .destructive) { showLeave = true } }
                    }
                } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }.accessibilityLabel("群組選單")
            }
        }
        .confirmationDialog("離開群組將取消本場活動資格", isPresented: $showLeave, titleVisibility: .visible) {
            Button("退出活動並離開群組", role: .destructive) { Task {
                if await repository.command("leave", eventID: eventID, account: account) { dismiss() }
            } }
        } message: { Text("再次加入須重新報名並經發起人審核。") }
        .task {
            await repository.refresh(account: account, selected: eventID)
            while !Task.isCancelled {
                if scenePhase == .active {
                    if repository.event(eventID)?.hasAccess() == true, !repository.isSubmitting {
                        await repository.command("read", eventID: eventID, account: account)
                    }
                    await repository.refresh(account: account, selected: eventID, silent: true)
                }
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }
    private func send(retry: Bool) {
        let text = retry ? failedDraft ?? "" : draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard text.count <= 2000 else { repository.error = "每則訊息最多 2000 字，請縮短後再傳送。"; return }
        if !retry { messageID = UUID() }
        Task {
            if await repository.command("send", eventID: eventID, payload: ["messageID": messageID.uuidString, "text": text], account: account) {
                draft = ""; failedDraft = nil
            } else { failedDraft = text }
        }
    }
}

struct MeetupMembersScreen: View {
    let eventID: UUID
    @Environment(MeetupRepository.self) private var repository
    var body: some View {
        List {
            if let event = repository.event(eventID), event.hasAccess() {
                ForEach(event.members.filter { $0.status == "approved" }) { member in
                    VStack(alignment: .leading) { Text(member.dog.name ?? member.nickname).font(.headline); Text(member.userID == event.hostID ? "發起人" : "參與者").font(.subheadline).foregroundStyle(.secondary) }
                }
            } else { ContentUnavailableView("無成員存取權", systemImage: "lock") }
        }.navigationTitle("群組成員")
    }
}

private struct MeetupReviewPhoto: View {
    let dog: MeetupSharedDog
    @Environment(SnootsAccountSession.self) private var account
    @State private var photo: UIImage?
    @State private var failed = false
    var body: some View {
        Group {
            if let photo { Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 180).accessibilityLabel("報名者同意分享的狗狗照片") }
            else if account.usesPreviewAccount, let name = dog.imageName { Image(name).resizable().scaledToFit().frame(maxHeight: 180) }
            else if dog.photoPath != nil {
                if failed { Button("照片載入失敗，點此重試") { Task { await load() } } }
                else { ProgressView("載入同意分享的照片…") }
            }
        }.task(id: dog.photoPath) { await load() }
    }
    private func load() async {
        guard !account.usesPreviewAccount, let path = dog.photoPath,
              let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        failed = false
        do {
            let data = try await account.authenticatedData("storage/v1/object/authenticated/dog-photos/\(encoded)", method: "GET")
            photo = UIImage(data: data); failed = photo == nil
        } catch { failed = true }
    }
}

private struct MeetupPreviewControls: View {
    let eventID: UUID
    @Environment(MeetupRepository.self) private var repository
    @Environment(SnootsAccountSession.self) private var account
    var body: some View {
        #if DEBUG
        if account.usesPreviewAccount, let event = repository.event(eventID), event.isHost(account.userID) {
            Section("模擬流程操作") {
                Button("加入兩筆示範報名申請") { repository.simulate("applicants", eventID: eventID) }
                if event.endApplication != nil { Button("模擬兩位核准參與者同意取消") { repository.simulate("twoVotes", eventID: eventID) } }
                Text("這裡測試尚未舉行的取消申請。已開始的狗聚請至現場儀表板直接結束；模擬資料不計入正式驗收。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        #endif
    }
}

private func sizeLabel(_ value: String) -> String {
    switch value { case "small": "小型犬"; case "medium": "中型犬"; case "large": "大型犬"; default: value }
}
private func reactionLabel(_ value: String) -> String {
    switch value {
    case "friendly": "主動友好"
    case "observe_then_interact": "先觀察，再互動"
    case "fearful_approach": "害怕，但會嘗試靠近"
    case "fearful_avoid": "害怕並躲開"
    case "bark_or_growl": "吠叫或低吠"
    default: value
    }
}
private func navigationLink(_ event: MeetupRecord) -> URL? {
    if let url = URL(string: event.navigationURL), url.scheme == "https" { return url }
    var c = URLComponents(string: "https://maps.apple.com/")
    c?.queryItems = [URLQueryItem(name: "q", value: event.location)]
    return c?.url
}
