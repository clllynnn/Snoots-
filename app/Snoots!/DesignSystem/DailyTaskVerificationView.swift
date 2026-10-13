#if DEBUG
import PhotosUI
import SwiftUI

struct DailyTaskVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    let candidate: PlaydateCandidate
    @State private var taskIndex = -1
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var usesSamplePhoto = false
    @State private var answer = ""
    @State private var selectedChoice: String?
    @State private var tags: Set<String> = []
    @State private var submitted = false
    @State private var otherSubmitted = false
    @State private var points = 0
    @State private var showDiscard = false

    private let titles = ["I01｜分享今天的散步", "I02｜喜歡的見面方式", "I03｜想對新朋友說", "I04｜分享喜歡的地方", "I05｜一起做什麼"]
    private var type: Int { taskIndex % 3 }
    private var canSubmit: Bool {
        switch type {
        case 0, 3: return (selectedPhoto != nil || usesSamplePhoto) && validTags
        case 1: return selectedChoice != nil
        default: return !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validTags
        }
    }
    private var validTags: Bool { tags.contains("其他") || (1...2).contains(tags.count) }

    var body: some View {
        Form {
            Section {
                Label("Debug 模擬：所有答案只留在本畫面，不上傳、不傳給對方，也不寫入熟絡度。", systemImage: "testtube.2")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if taskIndex < 0 {
                Section("配對成功後") {
                    Text("聊天室可立即使用；第一張任務在下一個台灣時間 06:00 出現。")
                    Button("模擬到下一個 06:00") { nextTask() }
                }
            } else if taskIndex >= titles.count {
                Section("五張任務已結束") {
                    Text("五張任務不循環；舊卡未雙方完成不補作、不加分。")
                    Text("本輪示範進度：\(points)%（上限 100%）")
                    Button("重新模擬") { taskIndex = -1; points = 0; resetAnswer() }
                }
            } else {
                Section(titles[taskIndex]) {
                    Text("今日任務｜台灣時間 06:00 更新")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("熟絡度示範：\(points)%／100%")
                    if submitted {
                        Label(otherSubmitted ? "雙方完成，可以揭曉" : "已提交，等待\(candidate.name)作答", systemImage: otherSubmitted ? "checkmark.circle.fill" : "clock")
                        if otherSubmitted {
                            Text("豆花與\(candidate.name)的分享已揭曉（模擬）。")
                            Text("本張示範加分已計入；不分析照片、簡答或聊天內容。")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Button("模擬對方完成今日任務") {
                                otherSubmitted = true
                                if !tags.contains("其他") {
                                    points = min(100, points + (type == 1 ? 25 : type == 2 ? 20 : 22))
                                }
                            }
                        }
                    } else {
                        answerFields
                        Button("提交今日答案") { submitted = true }
                            .disabled(!canSubmit)
                        Text("成功提交前可修改；提交後鎖定。這裡只模擬成功狀態，正式上傳失敗與重試仍待串接。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("模擬隔日 06:00 換卡") { nextTask() }
                    Text("未雙方完成的上一張會結束且不加分。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("每日任務模擬")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回聊天室") {
                    if hasDraft { showDiscard = true } else { dismiss() }
                }
            }
        }
        .confirmationDialog("捨棄未提交的答案？", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("捨棄並返回", role: .destructive) { dismiss() }
            Button("繼續編輯", role: .cancel) {}
        }
    }

    @ViewBuilder private var answerFields: some View {
        if taskIndex == 0 || taskIndex == 3 {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(selectedPhoto == nil ? "選擇一張照片" : "已選擇照片（本機）", systemImage: "photo")
            }
            Button(usesSamplePhoto ? "已使用示範照片" : "使用示範照片") { usesSamplePhoto = true }
            tagPicker
        } else if taskIndex == 1 || taskIndex == 4 {
            ForEach(["先保持距離散步", "遠處觀察再靠近", "放鬆時打招呼"], id: \.self) { choice in
                Button {
                    selectedChoice = choice
                } label: {
                    Label(choice, systemImage: selectedChoice == choice ? "checkmark.circle.fill" : "circle")
                }
            }
        } else {
            TextField("寫一句想對新朋友說的話", text: $answer, axis: .vertical)
                .lineLimit(2...5)
            tagPicker
        }
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("描述標籤（選 1–2 個，或選「其他」）")
                .font(.subheadline)
            ForEach(["散步", "慢慢認識", "探索", "其他"], id: \.self) { tag in
                Button {
                    if tag == "其他" { tags = [tag] }
                    else if tags.contains(tag) { tags.remove(tag) }
                    else if tags.count < 2 || tags.contains("其他") {
                        tags.remove("其他")
                        tags.insert(tag)
                    }
                } label: {
                    Label(tag, systemImage: tags.contains(tag) ? "checkmark.circle.fill" : "circle")
                }
            }
        }
    }

    private var hasDraft: Bool {
        !submitted && (selectedPhoto != nil || usesSamplePhoto || !answer.isEmpty || selectedChoice != nil || !tags.isEmpty)
    }

    private func nextTask() {
        taskIndex += 1
        resetAnswer()
    }

    private func resetAnswer() {
        selectedPhoto = nil
        usesSamplePhoto = false
        answer = ""
        selectedChoice = nil
        tags = []
        submitted = false
        otherSubmitted = false
    }
}
#endif
