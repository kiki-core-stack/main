# KCS 待辦

## 以工具取代提示：lint、檢查腳本與驗證證據

方向：每次糾正都變成 lint 規則或檢查，而不是再寫一條記憶或文件；規則的錯誤訊息直接寫原因與改法，在出錯當下就是指示。人審查證據（截圖、錄影、測試結果），不逐行審程式碼。

參考：Lauren Tan〈All Code Is Slop (Except Mine)〉（https://ai.engineer/talks/O_zcc6Xl12g-all-code-is-slop-except-mine）、OpenTeams〈Your AI Agent Ignored AGENTS.md. Your Linter Won't Let It.〉（https://openteams.com/lint-rules-for-ai-agents/）。

### 規則放哪一層

每條規則只有一個家，不複製 linter。

| 層 | 位置 | 內容 |
| --- | --- | --- |
| 通用 | `@kikiutils/eslint-config`、`rs-dylint-rules` | 排版、匯入順序、與專案無關的寫法 |
| KCS 共用 | 新的 KCS ESLint plugin（Rust 之後比照開一個 dylint library） | 架構邊界與 KCS 慣例，上游與所有下游共用 |
| 專案專屬 | 各專案自己的設定檔 | 例如下游的 UI 用語、`TODO` 格式 |

- [ ] 決定 KCS 共用 ESLint plugin 的位置：獨立 repo（像 pack 一樣由各 repo 依賴），或放進 pack（少一個 repo，但改規則要連帶更新所有 repo 釘的 pack 版本）。

### 待做的規則

- [ ] 自己的 composable 不可解構（`const xxx = useXxx()`）；第三方（VueUse、Nuxt）不在此限。
- [ ] `keepalive: false` 只允許出現在 auth 頁；訊息寫明其他頁要用 `defineOptions({ name })` + `keepalive: { exclude: [name] }` 與原因（`keepalive: false` 會讓舊頁立刻卸載並清空快取頁）。
- [ ] UI 用語：模板文字與字串出現禁用詞就報錯並給替換詞（工作階段 → 登入裝置、信箱 → 電子郵件、高危操作驗證 → 驗證身分）；禁用詞表由各專案設定。
- [ ] 前端（含 `.ts`）不可匯入 pack 的 `hono-backend/**`：屬 KCS 專屬的邊界，放在 KCS 這一層而非通用設定。
- [ ] 區段標記（`// Functions` 等）後的空行慣例：直接接程式碼不空行，接 JSDoc 才空一行。
- [ ] 非同步錯誤處理寫法（try/catch 與 `.then`／`.catch`／`.finally` 的選用）：先定準則，再視需要做成規則並整理既有程式。
- [ ] 註解白名單：只允許區段標記、工具指令與 `TODO(...)`，其餘註解需明確標成原因。爭議最大，最後做。
- [ ] Rust 端比照整理一輪可規則化的慣例（例如 impl 排序：先 `impl Trait for Type`，最後 `impl Type`）。

### 不適合做成 lint 的檢查

取決於意圖的約束先把意圖寫成明確的清單或宣告，再機械地比對；寫不成清單的才留在文件。

- [ ] 自動產生的檔案（`app/generated/**`、`app/apis/**`）被手改：重新產生後比對的檢查腳本。
- [ ] 上游擁有的檔案在下游被改：比照 `check-downstream-sync.mjs` 寫檢查腳本（與上游內容相同的檔案只能在上游改）。
- [ ] Claude Code hook：改完檔案後自動對該檔跑 lint，讓診斷當下出現。
- [ ] 公開匯出清單：有公開入口的套件（pack、`@kikiutils/eslint-config`）維護一份各入口的匯出名稱清單，檢查時與實際匯出比對，不一致即失敗；訊息寫明「加進清單，或移到 `_internals`」。用來擋住只為內部共用而從公開入口多匯出的情況（lint 分不出匯出是否為公開 API，`knip` 也抓不到有被使用的匯出）。
  - 先從 pack 的 `libs/auth` 做起，以模組為單位：`scripts/sync-package-exports.ts` 加一份公開模組清單，清單外的在 `exports` 產生成 `null`（與擋 `_internals` 同一機制），檔案不搬。
  - 目前 pack 以外有用到的：`session`、`realm`、`event`、`access`、`principal`、`rate-limit`、`code`、`password`、`passkey/browser`。其餘（`passkey/server`、`challenge`、`error`、`factor`、`login`、`principal-setting`、`qr-code-login`、`recovery-code`、`secret-encryption`、`totp`、`two-factor`、`verification`）只有 pack 自己的路由與 `libs/auth` 內部使用，下游卻能匯入並繞過路由直接呼叫。
  - 不搬進 `_internals`：它表示只給同目錄使用，而這些模組要被 `hono-backend/` 跨目錄匯入。

### 驗證證據

- [ ] 每次 UI 或流程改動附上截圖或錄影作為審查依據。
- [ ] 形式驗證（TLA+ 等）只考慮並行邏輯（工作階段換發與全部踢除的競態等），優先度最低。

## Auth

- [ ] 加入 Device Bound Session Credentials（DBSC），降低 cookie 被搬到其他機器後的可用時間。
  - 做法：工作階段拆成長效的綁定紀錄與短效 cookie；瀏覽器以 TPM 內的私鑰簽章才能換新 cookie，pack 需新增註冊與刷新兩個端點。不支援的瀏覽器維持現行行為。
  - 範圍：做在 pack，所有 realm 共用；先開後台類 realm，再開前台。
  - 驗證：需在有 TPM 的 Windows Chrome／Edge 實機測試。
  - 不採用 IP／User-Agent 比對或瀏覽器指紋：都是用戶端可重放的資料，而正常使用者的 IP 會因行動網路、Wi-Fi、VPN 變動，誤判多且擋不住取得 cookie 的人。

## 併發與資料完整性

- [ ] 刪除路由 read→check→delete：`admin/role`、`email/provider`、`sms/provider` 的 `[id]/index.delete.ts` 查詢 → 檢查引用 → `deleteOne()`，中間沒有 transaction／CAS；檢查後另一個請求仍可新增引用，原刪除照樣執行。下游沿用此寫法的刪除路由一併受影響。

## 後端共用

- [ ] SMS provider class 新增取得餘額或點數的方法，串上 management-backend 與 admin-frontend。
- [ ] Outbox event 傳遞改為 MongoDB Outbox → CDC → Kafka → BullMQ → Worker：CDC／Kafka 取代目前自行掃描、claim 與發布 outbox 的流程，BullMQ 保留工作排隊、執行、重試、延遲與排程。另立架構工作，不阻擋現有功能，不考慮舊資料。

## File／storage 與圖片

檔案只存 S3（每個專案一個公開、一個私有 bucket，見 pack `libs/storages/files`），公開檔案由 gateway 以 `/files/<hash>.<ext>` 轉發。

- [ ] 縮圖：上傳時不產生多尺寸，交給前端 `@nuxt/image`，可接受的尺寸以 preset 集中管理。自架用 imgproxy（強制簽章，只處理後端簽過的網址）並在前面加快取；站點在 Cloudflare 後面時可用 Cloudflare 轉換，但無法限制尺寸，且免費額度用完後新的轉換回 9422。
- [ ] 未引用檔案清理：從 schema 找出所有 `ref: 'File'` 欄位收集被引用的 id，排除建立不到 N 天的 File（先上傳、後儲存表單），刪除其餘 File 與物件；另以 `S3Client.list()` 找出沒有 File 文件的物件。富文字內容（如 strayit tinymce 的 `/api/file/redirect/<id>`）不在 schema ref 內，需解析內容或另存引用。
- [ ] 私有檔案（第一個用例出現時，在 pack 加上傳到私有 bucket 與檔案資訊的子文件 schema）：不進 File 模型、不去重，物件 key 用隨機 id，`{ key, mimeType, size, ... }` 存在擁有它的文件裡、隨該文件刪除。
  - 純內部檔案（如 ECP／CHCP 程式）只由後端或 worker 讀取，沒有讀取路由。
  - 受控存取（私人對話、群組附件、證件）每次讀取都檢查權限，回應的 `content-type` 用存下的 `mimeType`（`z.customFile()` 依內容偵測 type，偵測不到時為空字串）。讀取方式依流量決定：後端串流、gateway `auth_request` 問後端後直接從 bucket 回應（nginx 無法自行簽 S3 請求，需另外處理），或短效簽名網址。
- [ ] 改用 R2 時：站點放在 Cloudflare 後面，以 Worker 綁同網域的 `/files/*` 從 R2 回應，網址不變，gateway 的 `/files/` 設定可移除。

## 前端共用

- [ ] 遠端 selector 共用元件：KCS admin-frontend 有 2 個、strayit admin-frontend 有 8 個幾乎相同的遠端 selector（各約 55 行，載入、loading、已選資料合併），API、搜尋欄位、label、回傳 ID 或物件由使用端決定。先討論做法再動手：放在 KCS admin-frontend（非 pack），以及下游衍生的 selector 如何乾淨地改用共用元件、處理與上游的差異。

## 審查

- [ ] 逐一檢查 provider class（`pack/src/providers` 的 email／sms）有無 bug 或可簡化處，並與官方 API 文件比對。

## 各 repo 雜項

- [ ] 清除 `minimumReleaseAgeExclude(s)`（`pnpm-workspace.yaml`、`bunfig.toml`）中標註 `TODO: remove it` 的 `@kikiutils/*`：pack、base-backend 與 `repos/*`，以及其上游範本。
- [ ] Bun `RedisClient` 提供 `getdelBuffer` 後改為直接呼叫，並刪除 `get-and-delete-hex.lua`（`pack/src/storages/redis/msgpack.ts`，https://github.com/oven-sh/bun/issues/19576）。
