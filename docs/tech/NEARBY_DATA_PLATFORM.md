# Snoots! 附近地圖資料管理與安全串接規範

狀態：已採用
最後更新：2026-07-17

## 1. 架構決策

Snoots! 的正式地點資料以 **Supabase PostgreSQL** 為唯一真實來源，使用 PostGIS 處理距離排序及附近搜尋。App 只使用 Supabase publishable key 讀取已發布資料；專案內的 `maps_database.sqlite` 保留為尚未啟用雲端、網路失敗或開發預覽時的本機 fallback，不得再視為正式線上資料來源。

資料流：

```text
Numbers／管理後台
  → 暫存與資料檢查
  → Supabase PostgreSQL
  → RLS 權限與 nearby_places 查詢
  → iOS App
  → 本機最近成功資料快取（後續階段）
```

## 2. 專案檔案

- `supabase/migrations/20260717000000_nearby_places.sql`：正式 schema、索引、RLS 與附近搜尋函式。
- `supabase/seed.sql`：由現有 SQLite 產生的 35 筆待審核地點與次標籤關聯。
- `scripts/generate_supabase_seed.py`：可重複產生 seed，避免人工複製資料。
- `scripts/generate_geocoded_publish_sql.swift`：使用 Apple Maps 為 Development 待審地點產生座標與發布 SQL；產出必須人工檢查後才可執行。
- `app/Snoots!/SupabaseNearbyClient.swift`：App 的唯讀 Supabase REST 串接。
- `app/Snoots!/MapPlacesRepository.swift`：遠端優先、本機 fallback 的資料載入入口。

## 3. 資料表責任

### `places`

一列代表一個地點。保存分類、名稱、地址、經緯度、犬隻進入規則、政策摘要、來源、確認日期與發布狀態。

`published = true` 前，資料庫會強制要求：

- 有經緯度。
- 有來源網址。
- 有最後確認日期。
- 有標準化 dog access label。
- 有清楚、可執行的政策摘要。

因此，只有名稱但沒有可驗證進入規則的資料不能意外上線。

### `filter_options`

次標籤的主檔，包含：

- 穩定 ID。
- 所屬主分類。
- 繁體中文與英文名稱。
- UI 顯示順序。
- 是否啟用。

App 不應再以地點 ID 猜測標籤。新增次標籤時，應先在這張表建立定義。

### `place_filters`

連結地點與次標籤。每一組關聯都保存自己的來源、確認日期與驗證等級。空白或未知資料不能當成「否」。

### `saved_places`

每位使用者只能讀取、新增及刪除自己的收藏資料。

### `user_feedback`

保存「確認正確、回報變更、增加條件、標記歇業」。使用者只能送出及查看自己的回報，不能自行把回報標為已審核。

## 4. 權限與金鑰規範

1. iOS App 只能使用 Supabase publishable key。
2. `service_role`、secret key、資料庫密碼不得放進 App、plist、原始碼、Git 或可下載的設定檔。
3. 公開及登入使用者只能讀取 `published = true` 的地點與其標籤。
4. 正式地點與標籤不開放 App 直接寫入；管理操作使用 Supabase Dashboard，未來再改為受保護的管理後台或 Edge Function。
5. 使用者資料一律以 `auth.uid()` 限制擁有者。
6. 權限調整必須新增 migration，不可只在線上 Dashboard 手動修改 schema。
7. `.env`、本機 secrets xcconfig 及 service key 必須由 `.gitignore` 排除。

如果金鑰曾被提交到 Git，即使之後刪除檔案也仍可能存在於歷史中，必須立即到供應商後台撤銷並重建。是否重寫 Git 歷史需另行安排，不能在未通知協作者時直接執行。

## 5. 雲端專案首次啟用

### 建立環境

至少分成：

- Development：日常開發與測試資料。
- Production：App Store 正式資料。

正式環境不可拿來測試 schema 或大量匯入。

目前 Development 已建立於 Supabase：

- 專案名稱：`Snoots Development`
- Project ref：`erixfppvrhxvhdagncrf`
- 區域：Northeast Asia（Seoul）

Production 尚未建立。不得把 Development 的資料庫密碼、secret key 或 service role key 複製到正式 App。

### 套用資料庫

安裝 Supabase CLI 並登入後：

```sh
supabase link --project-ref <development-project-ref>
supabase db push
supabase db reset --local
```

上傳 seed 前必須先確認目前連結的是 Development。現有 seed 全部為 `published = false`，所以匯入不會直接對使用者公開。

### 設定 App

Build Settings 需要提供：

- `SNOOTS_SUPABASE_URL`
- `SNOOTS_SUPABASE_PUBLISHABLE_KEY`

未設定、值無效或遠端連線失敗時，Repository 保留 bundled SQLite，不會讓附近頁面因設定缺失而無法啟動。正式封存前應由 CI 或 Release build configuration 注入正確環境值。

目前只有 Debug build configuration 指向 Development，且只包含可公開的 publishable key。Release 保持空白，等 Production 建立後由發行流程注入，禁止直接沿用 Development。

## 6. Numbers 匯入流程

Numbers 可以作為大量整理工具，但不能直接覆蓋 Production。

1. 在 Numbers 整理資料並保留來源欄位。
2. 匯出成規定格式，先更新 bundled SQLite 或未來的 staging importer。
3. 執行：

   ```sh
   python3 scripts/generate_supabase_seed.py
   ```

4. 檢查新增、修改、重複及被移除的地點。
5. 匯入 Development。
6. 補齊座標、dog access、確認日期與政策摘要。
7. 由管理者抽查來源後才設為 `published = true`。
8. Development 驗證通過後，以 migration／受控匯入流程部署 Production。

禁止把空白欄位解讀成否定條件。例如「牽繩規則未提供」不等於「不需要牽繩」。

## 7. 發布檢查表

每個地點發布前必須確認：

- 名稱、分類、地址及地圖位置正確。
- Dog access 使用標準值：Indoor OK、Outdoor only、Carrier required、Restrictions apply。
- 政策摘要回答實際可做什麼，不使用模糊的 pet-friendly。
- 每個次標籤都有來源與確認日期。
- 驗證等級正確。
- Apple Maps／網站連結可開啟。
- 不把營業時間當成永久資料；需要能辨識時區及特殊休假。
- 急診資訊已由院方或官方來源確認，並清楚顯示最後確認日期。

## 8. 備份、變更與事故處理

- Production 使用每日備份；上線後評估啟用 Point-in-Time Recovery。
- schema 只透過 `supabase/migrations` 變更並進 Git review。
- Production 大量更新前先做可還原備份。
- 發現錯誤資料時先取消發布，不直接刪除，保留稽核線索。
- 懷疑金鑰外洩時：撤銷金鑰、建立新金鑰、更新部署設定、檢查存取紀錄，再評估是否清理 Git 歷史。
- RLS 或 migration 變更必須先在 Development 測試匿名、登入使用者及管理操作三種權限。

## 9. 目前邊界與下一階段

本次已完成 Development 專案、schema、RLS、PostGIS 查詢、種子產生器與 iOS 唯讀串接。UI 次標籤直接取自 `filter_options`，複選時保存穩定 `filter_id` 並傳給 `nearby_places`；地圖與清單使用 RPC 回傳結果。本機 SQLite 僅在未設定或連線失敗時備援。

目前 Development 有 24 個啟用中的次標籤、35 筆匯入地點，其中 15 筆已完成初步座標並發布供串接驗證。其餘 20 筆仍維持未發布，不能為了補數量而略過座標與來源審核。狗聚活動仍來自 App 既有活動資料，尚未搬入 `places`。

下一階段應依序完成：

1. 人工核對已發布的 15 筆座標，補齊並審核其餘 20 筆資料。
2. 將狗聚活動搬入受控的活動資料表或統一的附近查詢層。
3. 建立 Production Supabase 專案與獨立 Release 設定。
4. 增加最後成功資料的持久快取與同步時間顯示。
5. 建立非技術人員可使用的管理表單與審核流程。
