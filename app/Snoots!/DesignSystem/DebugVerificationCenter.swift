#if DEBUG
import SwiftUI

/// Local-only acceptance harness. It never writes a match or message to a remote account.
struct DebugVerificationCenter: View {
    @Environment(\.dismiss) private var dismiss
    let store: SnootsStore
    let openMatch: () -> Void
    let openMatchForm: () -> Void
    let openChatList: () -> Void
    let openChatRoom: () -> Void
    let openDailyTask: () -> Void
    let openMeetups: () -> Void
    let openPostComposer: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("這裡只模擬本機畫面與狀態，不代表雙帳號或後端已驗收。", systemImage: "exclamationmark.shield")
                        .foregroundStyle(.secondary)
                }

                Section("F03｜配對前表單") {
                    Button("開啟真實表單，測試返回與背景中斷") {
                        store.matchVerificationBypassesSetup = false
                        dismiss()
                        openMatchForm()
                    }
                }

                Section("F04｜候選卡與資料狀態") {
                    Picker("畫面情境", selection: Binding(
                        get: { store.matchVerificationScenario },
                        set: { store.matchVerificationScenario = $0 }
                    )) {
                        Text("兩位示範候選").tag(MatchVerificationScenario.cards)
                        Text("載入中").tag(MatchVerificationScenario.loading)
                        Text("沒有候選").tag(MatchVerificationScenario.empty)
                        Text("載入失敗").tag(MatchVerificationScenario.failure)
                    }
                    Button("在配對頁查看此情境") {
                        let scenario = store.matchVerificationScenario
                        store.resetMatchVerification()
                        store.matchVerificationBypassesSetup = true
                        store.matchVerificationScenario = scenario
                        dismiss()
                        openMatch()
                    }
                }

                Section("F05–F06｜雙方互選與聊天室") {
                    Picker("示範對象", selection: Binding(
                        get: { store.matchVerificationCandidateIndex ?? 0 },
                        set: { store.beginMatchVerification(candidateIndex: $0) }
                    )) {
                        ForEach(store.demoPlaydateCandidates.indices, id: \.self) { index in
                            Text(store.demoPlaydateCandidates[index].name).tag(index)
                        }
                    }

                    if !store.isMatchVerificationActive {
                        Button("開始模擬互選") { store.beginMatchVerification(candidateIndex: 0) }
                    } else {
                        Button(store.matchVerificationSelfInterested ? "豆花已選想認識" : "模擬：豆花選想認識") {
                            store.recordMatchVerificationInterest(fromSelf: true)
                        }
                        .disabled(store.matchVerificationSelfInterested)

                        Button(store.matchVerificationOtherInterested ? "對方已選想認識" : "模擬：對方選想認識") {
                            store.recordMatchVerificationInterest(fromSelf: false)
                        }
                        .disabled(store.matchVerificationOtherInterested)

                        if store.isMatched && store.hasMatchChat {
                            Label("雙方互選成功，模擬聊天室已建立", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Button("現在進入聊天室") { dismiss(); openChatRoom() }
                        } else {
                            Label("尚未雙方互選；新配對列表不會出現聊天室", systemImage: "clock")
                                .foregroundStyle(.secondary)
                        }
                        Button("查看聊天室列表") { dismiss(); openChatList() }
                        Button("重設這輪模擬", role: .destructive) { store.resetMatchVerification() }
                    }
                }

                Section("F07｜每日任務") {
                    Text("在任務頁模擬下個 06:00、五張不同版型、單方等待、雙方揭曉與進度上限。")
                        .foregroundStyle(.secondary)
                    Button("開啟每日任務模擬") {
                        if !store.isMatchVerificationActive {
                            store.beginMatchVerification(candidateIndex: 0)
                        }
                        dismiss()
                        openDailyTask()
                    }
                }

                Section("F09–F10｜社群") {
                    Text("首頁已區分豆花示範區與最新本機貼文。發文、留言與刪除都只作用於本機測試資料。")
                        .foregroundStyle(.secondary)
                    Button("開啟發文畫面") {
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(350))
                            openPostComposer()
                        }
                    }
                }

                Section("F12、F14、F16｜狗聚") {
                    Text("在狗聚頁可檢查瀏覽／我的三分類、參加者名額和不顯示飼主暱稱的審核畫面。審核需用示範發起人活動產生待審核申請。")
                        .foregroundStyle(.secondary)
                    Button("開啟狗聚頁") { dismiss(); openMeetups() }
                }

                Section("F25｜活動後好友") {
                    Text("先在狗聚建立「現場流程示範」，完成活動與共同回憶；於共同回憶模擬收到暖心卡，再從首頁愛心接受好友邀請並檢查個人聊天室。這與配對聊天室目前仍是兩套模擬資料。")
                        .foregroundStyle(.secondary)
                    Button("前往狗聚示範入口") { dismiss(); openMeetups() }
                }

                Section("仍需真實服務驗收") {
                    Text("雙帳號同步與同一聊天室沿用、貼文與照片上傳及刪除、社群通知、每日 06:00 排程、狗聚名額並發及審核資料權限，不能由本機模擬證明。F28 的公開政策網址也須由產品方提供。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("畫面驗證入口")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
#endif
