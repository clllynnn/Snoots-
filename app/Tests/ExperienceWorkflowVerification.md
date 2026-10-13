# F19–F29 建置與驗證紀錄

日期：2026-10-13。需求來源：[Notion 09｜尚未串接的流程畫面](https://app.notion.com/p/3f651418ae83818d93e0f6cf03465af9)。

這是工程交接紀錄，不取代 Notion Scope，不表示跨帳號／真機驗收完成。本次沒有部署遠端 migration、沒有修改 Supabase 線上資料，也沒有申請 Apple Developer 帳號。

## 已加入程式的流程

| 範圍 | 畫面與資料規則 |
| --- | --- |
| F19–F21 | 同場接待／簽到、Network＋Bonjour、前景停止、短效憑證、後端資格與安全守則驗證、發起人手動備案；三位其他核准成員簽到才能開始；暫離／返回不取消資格；開始後由發起人直接結束。 |
| F22–F24 | 已舉行活動的共同回憶、實際簽到狗狗辨識牆、答對解鎖、五面向觀察／標籤、私人觀察與暖心卡分離、照片私有上傳、二次確認與不可修改。 |
| F25–F26 | 愛心收件／已寄出／好友邀請、查看與確認區分、24 小時撤回並重算、30 天好友邀請期限、接受後個人聊天室、本人五面向按不同活動累積。 |
| F27–F28 | 本人真實檔案與編輯、私人獸醫院資料、封鎖／解除、登出、刪除帳號畫面與伺服端清除流程原始碼；登入與設定共用可設定政策 URL。 |
| F29 | 新增頁面的載入、空白、權限失敗／重試、伺服端成功才顯示完成、原生動態字型與安全區域。全 P0 跨尺寸驗收仍未完成。 |

資料不寫入 DogProfile 當作社交評分：觀察、卡片、活動資格與好友關係使用獨立資料表。數值代表觀察累積，不是能力、安全保證或診斷。

## 本機驗證

- Debug 與 Release 的 iOS Simulator build 成功；未進行簽署封裝。Xcode 僅有無 AppIntents 依賴的 metadata extraction 提示。
- `ExperienceDatabaseTests.mjs`：79 項斷言通過。使用隔離的 PGlite/Postgres，不接遠端專案。
- 測試包含：角色／錯場／守則拒絕、重複簽到、三人開始門檻、結束時間不可重設、14 天存取界線、24 小時撤回、未讀撤回不留痕、已讀撤回通知、觀察重算／同場去重、30 天邀請失效、好友與卡片互不連動、封鎖後無權讀写、私人電話隔離、取消與結束差異、刪除途中／完成後舊 JWT 不能恢復私有存取。
- 額外測試：過期停止請求不能停止新簽到接待；檔案修改犬種會建立後台待對照紀錄；已送出暖心卡的照片不能單獨刪除。
- Edge Function 通過 Babel TypeScript 語法解析；**沒有執行 Deno 型別檢查、Apple API、Storage API 或 Supabase Auth 整合測試**。

### iPhone 17 Pro／iOS 26.5 模擬器實際操作

- 個人檔案讀取本人已保存內容；私人安全資料及空觀察頁可進入。
- 建立明示的現場示範 → 同意安全守則 → 人數不足時確認照常舉辦。
- 加入三位已簽到示範成員 → 開始狗聚 → 暫離 → 返回 → 結束；沒有兩人同意或 48 小時等待。
- 共同回憶 → 辨識答錯提示 → 答對超超 → 解鎖回饋。
- 同類社交性選「放鬆自在」→「禮貌相遇」→ 二次確認 → 卡片與觀察儲存成功。
- 模擬收到卡片 → 詳情才變已讀 → 確認收到（不加好友）→ 另送好友邀請 → 模擬對方接受。
- 已寄出 → 24 小時期限提示 → 二次確認撤回 → 原內容隱藏；既有個人聊天室仍可進入並送出文字。
- 本人觀察頁顯示一場有效同類社交性觀察，累積 20／100；其他未觀察面向不顯示假分數。
- 設定可進入刪除影響說明及取消返回；未執行刪除既有模擬帳號，也未使用任何真實 Apple 帳號。

## 如何重跑本機資料規則測試

環境需 Node.js 及 `@electric-sql/pglite`。將實際安裝位置的 `dist/index.js` 當參數傳入，不使用正式資料庫 URL：

```sh
node app/Tests/ExperienceDatabaseTests.mjs /absolute/path/to/@electric-sql/pglite/dist/index.js
```

測試會建立隔離的 Auth／Storage 最小模型、套用 20261013000000 至 20261013050000 migration；只驗證 SQL 規則，不模擬 Storage HTTP 或 Apple 身分驗證服務。

## 提供給畫面確認成員的入口

Debug 模擬登入 → 首頁狗聚入口 →「建立現場流程示範（我是發起人）」→ 行前準備／現場儀表板。

示範活動安排於建立後約一分鐘，使用自己保留的模擬狗狗資料。所有示範按鈕只在 Debug＋模擬帳號出現，不接 Supabase；活動、卡片、邀請及觀察為記憶體資料，重啟即清空。正式帳號不自動塞入這些資料。

## 尚未通過的交付門檻

1. **遠端部署**：先確認既有專案已部署哪些 migration 並備份，再依序套用新增 `20261013030000_onsite_feedback.sql`、`20261013040000_account_deletion_lifecycle.sql`、`20261013050000_meetup_start_boundary.sql`；不可因本機測試成功就假定遠端 schema 相同。
2. **刪除服務部署**：部署 `supabase/functions/delete-account/index.ts`。Apple client/team/key ID 與 private key 僅存在伺服端 secrets，不進 App。服務先驗證同一 Apple 身分、撤銷 Apple 授權，再停止存取、清除 Storage 真正物件，最後刪除 Auth；202 pending 不表示完成。
3. **排程與受理結果**：既有每分鐘 `maintain_meetup_lifecycle()` 工作須確實啟用；另須由伺服端排程呼叫刪除清理重試（service-role only）。pending 刪除的處理時限、完成回報通道，以及測試結束後 90 天清理／備份保留仍未落地，不應宣稱已符合完整上線政策。
4. **公開隱私政策**：`SNOOTS_PRIVACY_POLICY_URL` 尚無 Snoots! 公開網址；登入／設定如實顯示待提供，不使用 Apple 政策替代。
5. **F01–F11 整合依賴**：愛心的貼文互動區保留，但貼文通知資料服務尚未串接。活動後好友目前使用持久化好友／訊息 API；既有一對一配對示範聊天室尚未接同一正式關係資料源，仍須整合以保證已配對者不重建第二個聊天室。
6. **真機與多人**：不同 iPhone 的 Bonjour／peer-to-peer 發現、權限拒絕、切背景、弱網、多人簽到、照片上傳與跨帳號收送，以及重新登入持久化均須實測。可連線範圍不是距離證明，也不保證特定 Wi-Fi 環境可用；保留手動備案。
7. **F29 全站**：小螢幕、大字體、鍵盤遮擋、拒絕權限、網路失敗、既有配對／貼文頁面需集中回歸。本次沒有進行視覺重設，也沒有將所有 P0 頁面驗收標為完成。

## 技術參考

- [Apple：includePeerToPeer](https://developer.apple.com/documentation/network/nwparameters/includepeertopeer)
- [Apple：TN3194 Account deletion and Sign in with Apple token revocation](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)

Bonjour 只負責發現端點；本場資格、安全守則與儲存結果由後端決定。接待憑證不包含私人聯絡資訊，但附近廣播仍可能被轉送，不把它當成精確位置／防作弊證明。
