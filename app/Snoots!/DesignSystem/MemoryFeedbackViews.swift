import PhotosUI
import SwiftUI

struct EventMemoriesScreen: View {
    let eventID: UUID
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    @State private var identifying: MemoryTarget?
    @State private var showHint = false
    var body: some View {
        List {
            ExperienceStatus(eventID: eventID)
            if experience.snapshot.memoryAllowed {
                Section("今天認識了哪些新朋友？") {
                    Text("認出同場的狗狗，分享今天的觀察。需要保持距離也是值得尊重的界線，不是好壞評分。")
                    if experience.snapshot.targets.isEmpty { ContentUnavailableView("目前沒有可辨識的狗狗", systemImage: "pawprint", description: Text("只顯示同場實際簽到且未封鎖的成員。")) }
                    ForEach(experience.snapshot.targets) { target in
                        VStack(alignment: .leading, spacing: 10) {
                            PrivateExperiencePhoto(bucket: "dog-photos", path: target.photoPath)
                                .frame(height: 180).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 16))
                            Text(target.recognized ? "認親成功！\(target.name ?? "狗朋友")" : "品種提示：\(target.breed)").font(.headline)
                            if target.recognized {
                                NavigationLink(target.cardSent ? "查看／修改本次私人觀察" : "填寫觀察與暖心回饋") { DogFeedbackScreen(eventID: eventID, targetID: target.id) }
                            } else { Button("試著認出牠") { showHint = false; identifying = target }.frame(minHeight: 44) }
                        }.padding(.vertical, 8)
                    }
                }
                NavigationLink("查看收到與寄出的暖心卡") { WarmHeartCenter() }
                #if DEBUG
                if account.usesPreviewAccount { Section("僅模擬流程") { Button("模擬收到暖心卡與觀察") { Task { await experience.command("simulateReceived", eventID: eventID, account: account, meetups: meetups) } } } }
                #endif
            } else if !experience.isLoading {
                ContentUnavailableView("共同回憶目前不可存取", systemImage: "lock", description: Text("須是已舉行並結束的狗聚之有效成員；保留 14 天。未舉行即取消不會開放。"))
            }
        }
        .navigationTitle("共同回憶").navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
        .task(id: scenePhase) {
            while !Task.isCancelled, scenePhase == .active {
                try? await Task.sleep(for: .seconds(10)); guard !Task.isCancelled else { return }
                await experience.refresh(account: account, meetups: meetups, eventID: eventID, silent: true)
            }
        }
        .sheet(item: $identifying) { target in
            NavigationStack {
                List {
                    PrivateExperiencePhoto(bucket: "dog-photos", path: target.photoPath).frame(height: 220).clipped()
                    Text("這隻 \(target.breed) 叫什麼名字？").font(.headline)
                    ForEach(experience.snapshot.nameChoices, id: \.self) { name in
                        Button(name) { Task {
                            if await experience.command("recognize", eventID: eventID, payload: ["targetID": target.id.uuidString, "answer": name], account: account, meetups: meetups) { identifying = nil }
                        } }.frame(minHeight: 44)
                    }
                    if let error = experience.error { Text(error).foregroundStyle(.red) }
                    Button("查看小提示") { showHint = true }
                    if showHint { Text("想想今天哪隻 \(target.breed) 有這個毛色與樣貌。不記得也沒關係，下次再認識！") }
                    Button("先跳過") { identifying = nil }
                }.navigationTitle("狗狗辨識").navigationBarTitleDisplayMode(.inline)
                    .disabled(experience.isSubmitting)
            }
        }
    }
    private func refresh() async { await experience.refresh(account: account, meetups: meetups, eventID: eventID) }
}

struct DogFeedbackScreen: View {
    let eventID: UUID
    let targetID: UUID
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [String: ObservationAnswer] = [:]
    @State private var bodyText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoPath: String?
    @State private var photoBusy = false
    @State private var photoError: String?
    @State private var confirmingSend = false
    @State private var confirmingDiscard = false
    @State private var confirmingRetract = false
    @State private var requestID = UUID()
    @State private var notice: String?
    private var target: MemoryTarget? { experience.snapshot.targets.first { $0.id == targetID } }
    private var warmLabels: [String] { SocialDimension.allCases.flatMap { answers[$0.rawValue]?.state == "relaxed" ? answers[$0.rawValue]?.labels ?? [] : [] } }
    private var hasWarmContent: Bool { !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !warmLabels.isEmpty || photoPath != nil }
    var body: some View {
        Form {
            ExperienceStatus(eventID: eventID)
            if experience.snapshot.memoryAllowed, let target, target.recognized {
                Section {
                    Text("你認出了 \(target.name ?? "狗朋友")！").font(.headline)
                    Text("僅記錄自然發生的互動；沒有觀察就選「未觀察」，不要刻意觸碰或製造刺激。私人觀察只用於對方本人可見的觀察紀錄。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(SocialDimension.allCases) { dimension in
                    Section(dimension.title) {
                        Picker("今天的觀察", selection: stateBinding(dimension)) {
                            Text("未觀察／略過").tag("unobserved")
                            Text("放鬆自在").tag("relaxed")
                            Text("需要空間／協助").tag("support")
                        }
                        ForEach(dimension.labels(answers[dimension.rawValue]?.state ?? "unobserved"), id: \.self) { label in
                            Button { toggle(label, dimension) } label: {
                                HStack { Text(label); Spacer(); Image(systemName: answers[dimension.rawValue]?.labels.contains(label) == true ? "checkmark.circle.fill" : "circle") }
                            }.foregroundStyle(.primary).frame(minHeight: 44)
                        }
                        if answers[dimension.rawValue]?.state == "support" { Text("私人觀察，不會顯示在暖心卡上。") .font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                if !target.cardSent {
                    Section("暖心卡｜選填") {
                        TextField("給 \(target.name ?? "狗朋友") 與飼主的一句話", text: $bodyText, axis: .vertical).lineLimit(3...6)
                        Text("\(bodyText.count)／1000 字").font(.footnote).foregroundStyle(.secondary)
                        if !warmLabels.isEmpty { Text("分享的正向標籤：\(warmLabels.joined(separator: "、"))") }
                        PhotosPicker(selection: $photoItem, matching: .images) { Label("選擇今天的照片（選填）", systemImage: "photo") }.frame(minHeight: 44)
                        if photoBusy { ProgressView("處理並上傳照片…") }
                        if let photoData, let image = UIImage(data: photoData) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220) }
                        if photoPath != nil { Label(account.usesPreviewAccount ? "模擬照片已準備" : "照片上傳成功", systemImage: "checkmark.circle") }
                        if let photoError { Text(photoError).foregroundStyle(.red); Button("重試上傳") { Task { await uploadPhoto() } } }
                        if photoItem != nil { Button("移除照片") { photoItem = nil; photoData = nil; photoPath = nil; photoError = nil } }
                    }
                } else { Section { Text("暖心卡已送出，內容不能更正。此處只修改本次私人觀察，不會改寫已寄出的卡片。撤回卡片請前往「愛心 → 已寄出」。") } }
                Section {
                    Button("儲存私人觀察") { save(send: false) }
                    if !target.cardSent {
                        Button("發送暖心回饋卡") { confirmingSend = true }
                            .disabled(!hasWarmContent || photoBusy || photoError != nil || bodyText.count > 1000)
                    }
                    if !target.answers.isEmpty { Button("撤回本次觀察", role: .destructive) { confirmingRetract = true } }
                }
            } else if !experience.isLoading { Text("此回饋入口已失效，請返回共同回憶。未成功儲存的內容不算提交。") }
        }
        .navigationTitle("觀察與暖心回饋").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("返回") { confirmingDiscard = true } } }
        .disabled(experience.isSubmitting)
        .onAppear { if answers.isEmpty { answers = target?.answers ?? [:] } }
        .onChange(of: photoItem) { _, _ in Task { await uploadPhoto() } }
        .confirmationDialog("確認送出暖心卡？", isPresented: $confirmingSend, titleVisibility: .visible) {
            Button("確認送出") { save(send: true) }
        } message: { Text("對方可立即查看；成功送出後不能更正，24 小時內可撤回。撤回會一併撤回本次觀察。這不會自動加好友。") }
        .confirmationDialog("離開並捨棄未提交內容？", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("捨棄並返回", role: .destructive) { dismiss() }
        } message: { Text("未提交草稿不保存，已儲存的觀察不受影響。") }
        .confirmationDialog("撤回本次私人觀察？", isPresented: $confirmingRetract, titleVisibility: .visible) {
            Button("撤回觀察", role: .destructive) { Task {
                if await experience.command("retractObservation", eventID: eventID, payload: ["targetID": targetID.uuidString], account: account, meetups: meetups) { dismiss() }
            } }
        } message: { Text("對方的觀察累積會重新計算，已寄出的暖心卡內容不變。") }
        .alert("已完成", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button("好") { dismiss() } } message: { Text(notice ?? "") }
    }
    private func stateBinding(_ d: SocialDimension) -> Binding<String> {
        Binding(get: { answers[d.rawValue]?.state ?? "unobserved" }, set: { answers[d.rawValue] = ObservationAnswer(state: $0, labels: []) })
    }
    private func toggle(_ label: String, _ d: SocialDimension) {
        var answer = answers[d.rawValue] ?? ObservationAnswer()
        if answer.labels.contains(label) { answer.labels.removeAll { $0 == label } }
        else if answer.labels.count < 2 { answer.labels.append(label) }
        answers[d.rawValue] = answer
    }
    private func save(send: Bool) {
        var payload: [String: Any] = ["targetID": targetID.uuidString, "answers": answers.mapValues(\.payload)]
        if send { payload["id"] = requestID.uuidString; payload["body"] = bodyText; payload["tags"] = warmLabels; payload["photoPath"] = photoPath }
        Task {
            if await experience.command(send ? "sendCard" : "observation", eventID: eventID, payload: payload, account: account, meetups: meetups) {
                notice = send ? "暖心卡與觀察已儲存。" : "私人觀察已儲存，不會寄出空白暖心卡。"
            }
        }
    }
    private func uploadPhoto() async {
        guard let item = photoItem else { return }
        photoBusy = true; photoError = nil; photoPath = nil
        defer { photoBusy = false }
        do {
            guard let bytes = try await item.loadTransferable(type: Data.self), bytes.count <= 30_000_000,
                  let image = UIImage(data: bytes), let jpeg = image.jpegData(compressionQuality: 0.65), jpeg.count <= 10_000_000 else {
                throw MeetupPreviewError(message: "照片無法讀取或太大，請選擇較小的照片。")
            }
            photoData = jpeg
            let path = try await account.uploadExperiencePhoto(jpeg)
            guard photoItem == item else { return }
            photoPath = path
        } catch { photoError = error.localizedDescription }
    }
}

struct WarmHeartCenter: View {
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    @State private var category = 0
    @State private var showsDemoPostNotifications = false
    @State private var readDemoNotificationIDs: Set<Int> = []
    var body: some View {
        List {
            ExperienceStatus()
            Picker("通知分類", selection: $category) { Text("互動").tag(0); Text("收到").tag(1); Text("已寄出").tag(2); Text("好友邀請").tag(3) }.pickerStyle(.segmented)
            if category == 0 {
                #if DEBUG
                if account.usesPreviewAccount {
                    Section {
                        Button(showsDemoPostNotifications ? "清除示範通知" : "載入兩則示範通知") {
                            showsDemoPostNotifications.toggle()
                            readDemoNotificationIDs.removeAll()
                        }
                        Text("僅驗證通知列表、已讀／未讀版面；不是伺服器事件，不會通知真實使用者。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if showsDemoPostNotifications {
                        Section("貼文互動｜模擬") {
                            ForEach(0..<2, id: \.self) { id in
                                Button {
                                    readDemoNotificationIDs.insert(id)
                                } label: {
                                    HStack {
                                        Label(id == 0 ? "示範：有人按讚你的貼文" : "示範：有人留言你的貼文", systemImage: id == 0 ? "heart.fill" : "bubble.right.fill")
                                        Spacer()
                                        if !readDemoNotificationIDs.contains(id) {
                                            Text("未讀").font(.caption.bold())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                #endif
                if !showsDemoPostNotifications {
                    ContentUnavailableView("目前沒有貼文互動通知", systemImage: "heart", description: Text("正式貼文通知資料服務尚待串接；示範通知可由 Debug 模擬帳號載入。"))
                }
            } else if category == 3 {
                if experience.snapshot.invites.isEmpty { Text("目前沒有好友邀請。未接受的邀請於送出後 30 天自動收回；不影響暖心卡及觀察。") }
                ForEach(experience.snapshot.invites) { invite in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(invite.recipientID == account.userID ? "\(invite.senderName) 希望與你成為狗友" : "已向 \(invite.recipientName) 寄出邀請")
                        if invite.accepted { Label("已成為狗友", systemImage: "checkmark.circle") }
                        else {
                            Text("有效至 \(dateText(invite.createdAt + 30 * 86_400))").font(.footnote).foregroundStyle(.secondary)
                            if invite.recipientID == account.userID {
                                Button("接受") { perform("acceptInvite", invite.id) }
                            }
                            #if DEBUG
                            if account.usesPreviewAccount, invite.senderID == account.userID { Button("模擬對方接受") { perform("simulateAccept", invite.id) } }
                            #endif
                        }
                    }.padding(.vertical, 6)
                }
            } else {
                let cards = experience.snapshot.cards.filter { category == 1 ? $0.recipientID == account.userID : $0.senderID == account.userID }
                if cards.isEmpty { ContentUnavailableView(category == 1 ? "尚未收到暖心卡" : "尚未寄出暖心卡", systemImage: "envelope") }
                ForEach(cards) { card in
                    NavigationLink { WarmCardDetail(cardID: card.id) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(category == 1 ? "來自 \(card.senderName)" : "寄給 \(card.recipientName)").font(.headline)
                            if card.retractedAt != nil { Text("暖心卡與本次觀察已撤回").foregroundStyle(.secondary) }
                            else { Text("一張今天相遇的暖心回饋") }
                            HStack {
                                Text(dateText(card.sentAt)).font(.footnote).foregroundStyle(.secondary)
                                if (category == 1 && card.viewedAt == nil) || (category == 1 && card.withdrawalUnread) { Text("未讀").font(.caption.bold()).foregroundStyle(.purple) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("愛心通知").navigationBarTitleDisplayMode(.inline)
        .task { await experience.refresh(account: account, meetups: meetups) }
        .refreshable { await experience.refresh(account: account, meetups: meetups) }
    }
    private func perform(_ action: String, _ id: UUID) { Task { await experience.command(action, payload: ["id": id.uuidString], account: account, meetups: meetups) } }
}

struct WarmCardDetail: View {
    let cardID: UUID
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmRetraction = false
    @State private var readSaved = false
    private var card: WarmCard? { experience.snapshot.cards.first { $0.id == cardID } }
    var body: some View {
        List {
            ExperienceStatus()
            if let card {
                Section {
                    Text("\(card.senderName) → \(card.recipientName)").font(.title2.bold())
                    if card.retractedAt != nil {
                        Text("寄件者已撤回暖心卡及本次觀察。好友邀請、已成立的好友關係與聊天室不受影響。")
                    } else if card.senderID == account.userID || readSaved {
                        if let path = card.photoPath { PrivateExperiencePhoto(bucket: "warm-photos", path: path).frame(height: 240).clipped() }
                        if !card.body.isEmpty { Text(card.body) }
                        if !card.tags.isEmpty { Text(card.tags.joined(separator: " · ")).font(.headline) }
                        Text("送出時間：\(dateText(card.sentAt))").font(.footnote).foregroundStyle(.secondary)
                        if card.senderID == account.userID {
                            Text("內容不可更正；可於 \(dateText(card.sentAt + 86_400)) 前撤回。")
                            Button("撤回卡片與觀察", role: .destructive) { confirmRetraction = true }.disabled(!card.canRetract(now: experience.serverNow))
                        } else {
                            Button(card.acknowledged ? "已確認" : "確認收到") { perform("acknowledge") }.disabled(card.acknowledged)
                            let alreadyInvited = experience.snapshot.invites.contains { $0.senderID == account.userID && $0.recipientID == card.senderID }
                            let friends = experience.snapshot.friends.contains { $0.userID == card.senderID }
                            Button(friends ? "已成為狗友" : (alreadyInvited ? "已寄出好友邀請" : "回覆（加好友）")) { perform("invite") }.disabled(alreadyInvited || friends)
                            Text("加好友會另送邀請，對方接受後才開啟個人聊天室。只確認卡片也完全可以。")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } else { ProgressView("正在開啟卡片…"); Button("重試開啟") { Task { await openCard() } } }
                }
            } else { ContentUnavailableView("卡片目前不可查看", systemImage: "envelope", description: Text("可能已撤回、被封鎖或尚未載入。")) }
        }
        .navigationTitle("暖心卡").navigationBarTitleDisplayMode(.inline)
        .task { await openCard() }
        .task(id: scenePhase) {
            while !Task.isCancelled, scenePhase == .active {
                try? await Task.sleep(for: .seconds(5)); guard !Task.isCancelled else { return }
                await experience.refresh(account: account, meetups: meetups, silent: true)
            }
        }
        .confirmationDialog("撤回這張暖心卡？", isPresented: $confirmRetraction, titleVisibility: .visible) {
            Button("確認撤回", role: .destructive) { perform("retractCard") }
        } message: { Text("本次觀察一併撤回並重新計算數值。對方若已查看，會收到撤回通知；尚未查看則直接移除，不留下提示。好友關係不受影響。") }
    }
    private func openCard() async {
        await experience.refresh(account: account, meetups: meetups)
        if card?.recipientID == account.userID {
            readSaved = await experience.command("readCard", payload: ["id": cardID.uuidString], account: account, meetups: meetups)
        }
    }
    private func perform(_ action: String) { Task { await experience.command(action, payload: ["id": cardID.uuidString], account: account, meetups: meetups) } }
}

func dateText(_ timestamp: Double) -> String { MeetupRules.dateText(Date(timeIntervalSince1970: timestamp)) }
