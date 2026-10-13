import AuthenticationServices
import PhotosUI
import SwiftUI

struct OwnProfileScreen: View {
    let store: SnootsStore
    @Environment(SnootsAccountSession.self) private var account
    var body: some View {
        List {
            Section {
                if let bytes = account.dogPhotoData, let image = UIImage(data: bytes) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).frame(maxWidth: .infinity) }
                Text(account.dog?.name ?? "我的狗狗").font(.title2.bold())
                Text("\(account.dog?.breed ?? "") · \(account.dog?.sex == "male" ? "公" : "母")\(account.dog?.isNeutered == true ? "（已絕育）" : "")")
                Text("飼主暱稱：\(account.owner?.nickname ?? "")")
                Label("透過 Apple 登入", systemImage: "apple.logo")
                if account.usesPreviewAccount { Text("目前為本機模擬帳號").font(.footnote).foregroundStyle(.secondary) }
            }
            Section("本人資料") {
                NavigationLink("編輯飼主與狗狗基本資料") { OwnProfileEditor(store: store) }
                NavigationLink("編輯配對前資料") { BeforeMatchingView(store: store) }
                NavigationLink("私密安全資料") { PrivateSafetyDetailsScreen() }
                NavigationLink("社交觀察與偏好（僅本人可見）") { SocialObservationsScreen() }
            }
            Section { NavigationLink("帳號設定") { AccountSettingsScreen() } }
        }
        .navigationTitle("我的檔案").navigationBarTitleDisplayMode(.inline)
    }
}

struct OwnProfileEditor: View {
    let store: SnootsStore
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var name = ""
    @State private var breed = ""
    @State private var size = "small"
    @State private var sex = "male"
    @State private var neutered = false
    @State private var reaction = "observe_then_interact"
    @State private var item: PhotosPickerItem?
    @State private var photo: Data?
    @State private var busy = false
    @State private var photoBusy = false
    @State private var error: String?
    @State private var discard = false
    var body: some View {
        Form {
            Section("照片與基本資料") {
                if let bytes = photo ?? account.dogPhotoData, let image = UIImage(data: bytes) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200) }
                PhotosPicker("更換照片", selection: $item, matching: .images).frame(minHeight: 44)
                TextField("飼主暱稱", text: $nickname)
                TextField("狗狗名字", text: $name)
                TextField("犬種", text: $breed)
                Text("修改犬種後會交由後台補齊對照資料，確認前活動量推薦可能顯示待確認。")
                    .font(.footnote).foregroundStyle(.secondary)
                Picker("體型", selection: $size) { Text("小型犬").tag("small"); Text("中型犬").tag("medium"); Text("大型犬").tag("large") }
                Picker("性別", selection: $sex) { Text("公").tag("male"); Text("母").tag("female") }
                Toggle("已絕育", isOn: $neutered)
                Picker("陌生狗互動反應", selection: $reaction) {
                    Text("主動友好").tag("friendly"); Text("先觀察，再互動").tag("observe_then_interact")
                    Text("害怕，但會嘗試靠近").tag("fearful_approach"); Text("害怕並躲開").tag("fearful_avoid"); Text("吠叫或低吠").tag("bark_or_growl")
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            if busy || photoBusy { ProgressView("正在處理…") }
            Button("儲存變更") { Task { await save() } }.disabled(busy || photoBusy)
        }
        .navigationTitle("編輯檔案").navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("取消") { discard = true }.disabled(busy) } }
        .onAppear {
            nickname = account.owner?.nickname ?? ""; name = account.dog?.name ?? ""; breed = account.dog?.breed ?? ""
            size = account.dog?.size ?? "small"; sex = account.dog?.sex ?? "male"; neutered = account.dog?.isNeutered ?? false
            reaction = account.dog?.socialStyle ?? "observe_then_interact"
        }
        .onChange(of: item) { _, selected in Task {
            guard let selected else { return }; photoBusy = true; defer { photoBusy = false }
            do {
                guard let bytes = try await selected.loadTransferable(type: Data.self), bytes.count <= 30_000_000,
                      let image = UIImage(data: bytes), let jpeg = image.jpegData(compressionQuality: 0.65), jpeg.count <= 10_000_000 else { throw MeetupPreviewError(message: "照片無法讀取或超過大小限制。") }
                photo = jpeg; error = nil
            } catch { self.error = error.localizedDescription }
        } }
        .confirmationDialog("捨棄未儲存的變更？", isPresented: $discard, titleVisibility: .visible) { Button("捨棄並返回", role: .destructive) { dismiss() } }
    }
    private func save() async {
        busy = true; error = nil; defer { busy = false }
        do {
            try await account.updateOwnProfile(nickname: nickname, name: name, breed: breed, size: size, sex: sex, neutered: neutered, reaction: reaction, photo: photo)
            if let owner = account.owner, let dog = account.dog { store.applyRegisteredProfile(owner: owner, dog: dog, photoData: account.dogPhotoData) }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct PrivateSafetyDetailsScreen: View {
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    @State private var details = DogPrivateDetails()
    @State private var saved = false
    var body: some View {
        Form {
            ExperienceStatus()
            Section("只有本人可查看") {
                Text("這些資料不會提供發起人審核、配對對象或其他參加者。建議填寫常用或鄰近獸醫院，不需填私人聯絡人的電話。")
                TextField("獸醫院名稱（選填）", text: $details.vetName)
                TextField("獸醫院電話（選填）", text: $details.vetPhone).keyboardType(.phonePad)
                Text("發生緊急狀況時，請就近尋求獸醫協助；可由獸醫院依適用流程掃描晶片協助聯絡飼主。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button("儲存私密資料") { Task { saved = await experience.command("privateDetails", payload: details.payload, account: account, meetups: meetups) } }.disabled(experience.isSubmitting)
            if saved { Label("已儲存", systemImage: "checkmark.circle") }
        }
        .navigationTitle("私密安全資料").navigationBarTitleDisplayMode(.inline)
        .task { await experience.refresh(account: account, meetups: meetups); details = experience.snapshot.privateDetails }
    }
}

struct SocialObservationsScreen: View {
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    @State private var preference = ""
    var body: some View {
        List {
            ExperienceStatus()
            Section {
                Label("僅本人可見", systemImage: "lock.fill")
                Text("這是參與觀察的累積，不是能力、健康、安全分數或排行榜。放鬆與需要協助的有效觀察都計入；未觀察不計入。")
            }
            ForEach(SocialDimension.allCases) { dimension in
                Section(dimension.title) {
                    let count = experience.snapshot.eventCount(dimension)
                    if count == 0 { Text("尚未有觀察").foregroundStyle(.secondary) }
                    else {
                        let value = min(100, count * 20)
                        ProgressView(value: Double(value), total: 100)
                        Text("觀察累積 \(value)／100 · \(count) 場有效狗聚")
                        Text("每場同一面向只累積一次；多位回饋者不重複加分。到達上限後仍保留新觀察，撤回或更正會重算。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            Section("本人選擇的社交偏好") {
                Picker("偏好", selection: $preference) {
                    Text("暫不設定").tag(""); Text("喜歡社交").tag("喜歡社交"); Text("能自在共處").tag("能自在共處")
                    Text("選擇性社交").tag("選擇性社交"); Text("偏好獨處").tag("偏好獨處")
                }
                Text("由你自行選擇、修改或留白；不根據觀察分數自動分類。")
                Button("儲存偏好") { Task {
                    var details = experience.snapshot.privateDetails; details.socialPreference = preference
                    await experience.command("privateDetails", payload: details.payload, account: account, meetups: meetups)
                } }.disabled(experience.isSubmitting)
            }
            Section("最近觀察") {
                if experience.snapshot.observations.isEmpty { Text("完成狗聚並收到有效回饋後，會顯示來源與日期。") }
                ForEach(experience.snapshot.observations) { observation in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(observation.eventName).font(.headline)
                        Text("來自 \(observation.sourceName) · \(dateText(observation.updatedAt))").font(.footnote).foregroundStyle(.secondary)
                        ForEach(SocialDimension.allCases.filter { observation.answers[$0.rawValue]?.state != "unobserved" && observation.answers[$0.rawValue] != nil }) { dimension in
                            Text("\(dimension.title)：\(observation.answers[dimension.rawValue]?.state == "relaxed" ? "放鬆自在" : "需要空間／協助")")
                            Text(observation.answers[dimension.rawValue]?.labels.joined(separator: "、") ?? "").font(.footnote)
                        }
                    }
                }
            }
        }
        .navigationTitle("社交觀察").navigationBarTitleDisplayMode(.inline)
        .task { await experience.refresh(account: account, meetups: meetups); preference = experience.snapshot.privateDetails.socialPreference }
        .refreshable { await experience.refresh(account: account, meetups: meetups) }
    }
}

struct AccountSettingsScreen: View {
    @Environment(SnootsAccountSession.self) private var account
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @State private var logout = false
    @State private var deletion = false
    @State private var deleting = false
    @State private var error: String?
    var body: some View {
        Form {
            ExperienceStatus()
            Section("登入方式") { Label(account.usesPreviewAccount ? "模擬 Apple 登入" : "透過 Apple 登入", systemImage: "apple.logo") }
            Section("封鎖名單") {
                if experience.snapshot.blocks.isEmpty { Text("目前沒有封鎖的使用者").foregroundStyle(.secondary) }
                ForEach(experience.snapshot.blocks) { blocked in
                    HStack { Text(blocked.name); Spacer(); Button("解除封鎖") { Task {
                        await experience.command("unblock", payload: ["targetID": blocked.id.uuidString], account: account, meetups: meetups)
                    } } }
                }
                Text("解除封鎖不會自動恢復已解除的好友關係或聊天室。") .font(.footnote).foregroundStyle(.secondary)
            }
            Section("隱私與支援") {
                if let policyURL = SnootsPolicy.publicURL { Link("Snoots! 隱私權政策", destination: policyURL) }
                else { Text("Snoots! 公開隱私權政策網址待提供；正式測試前必須補齊。Apple 的隱私權政策不能代替 Snoots! 政策。") }
                Link("聯絡 Snoots!（暫用信箱）", destination: URL(string: "mailto:Snoots@gmail.com")!)
            }
            Section("帳號") {
                Button("登出", role: .destructive) { logout = true }
                Text("只結束這個裝置的登入；已提交的帳號與狗狗資料保留。") .font(.footnote).foregroundStyle(.secondary)
                Button("刪除帳號", role: .destructive) { deletion = true }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("帳號設定").navigationBarTitleDisplayMode(.inline)
        .task { await experience.refresh(account: account, meetups: meetups) }
        .confirmationDialog("確定登出？", isPresented: $logout, titleVisibility: .visible) { Button("登出", role: .destructive) { Task { await account.signOut() } } }
        .sheet(isPresented: $deletion) {
            NavigationStack {
                List {
                    Section("這不是登出，無法復原") {
                        Text("刪除飼主／狗狗資料、照片、本人內容與回饋；撤銷登入與活動資格。你發起但尚未舉行的活動將取消，已舉行的活動會結束。其他成員自己的內容保留，但不保留你的私人資訊。")
                        Text("未結案的安全檢舉可能依法與政策保留最低必要證據至結案。後端清理若未完成，只會顯示受理中，不會宣稱已刪除。")
                        Text("下一步以同一 Apple 帳號驗證並確認刪除。")
                    }
                    if deleting { ProgressView("正在處理刪除…請勿重複操作") }
                    if let error { Text(error).foregroundStyle(.red) }
                    if account.usesPreviewAccount {
                        Button("確認刪除本機模擬帳號", role: .destructive) { Task { await delete(nil) } }.disabled(deleting)
                    } else {
                        SignInWithAppleButton(.continue) { request in request.requestedScopes = [] } onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { error = "Apple 驗證失敗。"; return }
                                Task { await delete(credential) }
                            case .failure(let failure):
                                if (failure as? ASAuthorizationError)?.code != .canceled { error = "驗證未完成，帳號尚未刪除。請重試。" }
                            }
                        }.signInWithAppleButtonStyle(.black).frame(height: 50).disabled(deleting)
                    }
                }
                .navigationTitle("確認刪除帳號").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { deletion = false }.disabled(deleting) } }
                .interactiveDismissDisabled(deleting)
            }
        }
    }
    private func delete(_ credential: ASAuthorizationAppleIDCredential?) async {
        deleting = true; error = nil; defer { deleting = false }
        do { _ = try await account.deleteAccount(credential: credential); deletion = false }
        catch { self.error = error.localizedDescription }
    }
}

struct EventFriendChatLinks: View {
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("活動後認識的狗友").font(.headline)
            ExperienceStatus()
            if experience.snapshot.friends.isEmpty { Text("接受好友邀請後，個人聊天室會出現在這裡。").foregroundStyle(.secondary) }
            ForEach(experience.snapshot.friends) { friend in
                NavigationLink { EventFriendChatScreen(friendshipID: friend.id) } label: {
                    HStack { Text(friend.name); Spacer(); if friend.unread > 0 { Text("\(friend.unread) 則未讀").font(.footnote) }; Image(systemName: "chevron.right") }.frame(minHeight: 44)
                }
            }
        }.task { await experience.refresh(account: account, meetups: meetups) }
    }
}
struct EventFriendChatScreen: View {
    let friendshipID: UUID
    @Environment(ExperienceRepository.self) private var experience
    @Environment(MeetupRepository.self) private var meetups
    @Environment(SnootsAccountSession.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    @State private var text = ""
    @State private var messageID = UUID()
    @State private var failedText: String?
    @State private var blocking = false
    private var friend: DogFriend? { experience.snapshot.friends.first { $0.id == friendshipID } }
    var body: some View {
        VStack(spacing: 0) {
            List {
                ExperienceStatus()
                if let friend {
                    Text("\(friend.name) · 飼主 \(friend.nickname)").font(.headline)
                    if friend.messages.isEmpty { Text("你們已成為狗友，打個招呼吧！") }
                    ForEach(friend.messages) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.senderID == account.userID ? "你" : friend.name).font(.caption).foregroundStyle(.secondary)
                            Text(message.text).textSelection(.enabled)
                            Text(dateText(message.createdAt)).font(.caption2).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: message.senderID == account.userID ? .trailing : .leading)
                    }
                } else { ContentUnavailableView("聊天室已失效", systemImage: "lock", description: Text("請返回列表重新確認好友關係。")) }
            }
            if friend != nil {
                HStack {
                    TextField("輸入訊息", text: $text, axis: .vertical).lineLimit(1...4).disabled(failedText != nil)
                    Button(failedText == nil ? "傳送" : "重試傳送") { Task {
                        let outgoing = failedText ?? text
                        failedText = outgoing
                        if await experience.command("sendMessage", payload: ["id": messageID.uuidString, "friendshipID": friendshipID.uuidString, "body": outgoing], account: account, meetups: meetups) { text = ""; messageID = UUID(); failedText = nil }
                    } }.frame(minHeight: 44).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 2000 || experience.isSubmitting)
                }.padding().background(.regularMaterial)
            }
        }
        .navigationTitle(friend?.name ?? "個人聊天室").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("封鎖", role: .destructive) { blocking = true }.disabled(friend == nil) } }
        .task(id: scenePhase) {
            while !Task.isCancelled, scenePhase == .active {
                await experience.refresh(account: account, meetups: meetups, silent: true)
                if friend != nil { await experience.command("readChat", payload: ["friendshipID": friendshipID.uuidString], account: account, meetups: meetups) }
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .confirmationDialog("封鎖這位狗友？", isPresented: $blocking, titleVisibility: .visible) {
            if let friend { Button("確認封鎖", role: .destructive) { Task { await experience.command("block", payload: ["targetID": friend.userID.uuidString], account: account, meetups: meetups) } } }
        } message: { Text("解除好友關係並移除聊天室，也停止互相查看辨識牆；不通知對方。可在設定解除封鎖，但不自動恢復關係。") }
    }
}
