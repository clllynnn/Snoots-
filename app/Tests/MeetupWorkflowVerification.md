# D05／F12–F18 建置與驗證交接

2026-10-13：App 畫面、RPC 用戶端與資料庫 migration 已建置；未套用至遠端 Supabase，未完成 Notion 定義的兩帳號／不同 iPhone 驗收。

## 程式入口

- `DesignSystem/MeetupWorkflowViews.swift`：我的狗聚、瀏覽、詳情、發起／編輯、報名、審核、行前準備與群組。
- `MeetupRepository.swift`：正式帳號呼叫 Supabase RPC；Debug 模擬登入使用明確標示的記憶體資料，結束 App 後模擬狗聚不保存。
- `MeetupDomain.swift`：畫面資料、表單驗證、權限及 14 天到期判斷。
- `../../supabase/migrations/20261013020000_meetup_workflow.sql`：資料表、RLS、RPC、同意分享的照片權限、結束驗證、檢舉案件及保留期提醒。

## 已驗證

- Debug／Release iOS Simulator 編譯成功。
- `MeetupDatabaseTests.mjs` 在 PGlite 獨立記憶體 PostgreSQL 執行 51 項斷言：封閉測試名單／Demo 隔離、權限、同意、重試去重、更新版本、重申請審核、場地限制、五人檢舉、兩人確認、48 小時及 14 天邊界。
- iPhone 17 Pro 模擬器：報名前明確同意、待審核、核准解鎖、三區個人確認、群組文字與示範回覆、建立活動、核准申請、結束申請及到期時間。
- 自訂邀請 URL 開啟 App 並導向我的狗聚；無效邀請有錯誤提示。

PGlite 測試只對本機記憶體資料執行，不使用或修改遠端資料。由可信 npm registry 取得 `@electric-sql/pglite@0.5.9` 後執行：

```sh
node app/Tests/MeetupDatabaseTests.mjs /absolute/path/to/pglite/package/dist/index.js
```

## 部署及正式驗收

1. 在既有 Supabase 專案確認先前 account_profiles、matching_profiles migration 狀態，再套用 meetup_workflow。不可重跑已套用的建表 migration。
2. 以後台管理權限將本次真實測試者加入 `meetup_testers`；Demo 帳號設定 `is_demo=true`，兩類活動互不可見。App 不可持有 service-role key。
3. 確認私有 `dog-photos` bucket 與 Storage RLS 生效；只有該場有效發起人能取得申請人明確同意分享的照片，拒絕、退出或到期後撤銷此權限。
4. 若已有 pg_cron，migration 安裝每分鐘 `snoots-meetup-lifecycle` 工作；否則由後台排程每分鐘執行 `maintain_meetup_lifecycle()`。即使排程延遲，RPC 仍依伺服器時間立即拒絕逾期存取。
5. 後台監看 `meetup_review_cases` 的 pending 案件；五位不同參與者檢舉會產生案件，不會自動結束。透過管理環境呼叫 `review_meetup_case` 並提供審核人及理由。目前未建置獨立管理者網頁或 Email／推播提醒。
6. 至少兩個正式帳號、不同 iPhone 驗證建立、報名、審核、行前確認、對話與重新登入；結束驗證需發起人加兩位參與者，檢舉驗證需發起人加五位參與者。另測弱網、重試、過期 Session、滿額競爭與舊邀請。
7. 自訂 `snoots://meetup?code=...` 只供已安裝 App 的測試者使用，登入／建檔後接續；未安裝者先安裝 TestFlight 版本，再貼上邀請碼。尚無公開 Universal Link 網頁。
8. F19 簽到串接時必須呼叫 `meetup_checkin_eligible` 並在實際寫入簽到的交易內再檢查目前版安全守則。F22 共同回憶須套用同場成員及 14 天期限；目前入口明示待串接。

群組首版以在前景時每 5 秒同步，取回選定活動的文字歷史；這是封閉小規模測試的實作。推播及一般聊天照片不在此交付。若訊息量擴大，再加入游標分頁與增量訂閱。Notion 09 的驗收核取方塊仍維持未勾選。
