# management-backend 待辦

## 權限與帳號

- [ ] 授出的權限不能超過操作者自己的權限（非 unrestricted 時）。
  - 現況：建立或編輯身分組（`admin/role/index.post.ts`、`role/[id]/index.put.ts`）、建立或編輯管理員時指派身分組（`admin/index.post.ts`、`admin/[id]/index.put.ts`），都不比對操作者權限。只有 `admin.role.update` 的人可以把自己所屬的身分組改成全部權限；有 `admin.account.update` 的人可以替自己掛上任何身分組；有 `admin.account.create` 的人可以建一個高權限帳號再登入。
  - `findManageableAdminOrThrow` 只擋超級管理員：有 `admin.account.update` 的人可以重設權限比自己高的一般管理員的密碼並登入；若另有 `manageSecurity`，連對方有雙重驗證也能先重設再接管。
  - 做法：在 `libs/admin/permission.ts` 加共用檢查，要求身分組權限、指派的身分組權限聯集、目標管理員的權限都 ⊆ 操作者權限；`findManageableAdminOrThrow` 一併套用（不符時回 notFound）。
- [ ] `PUT /admin/:id` 改密碼的驗證：
  - 改別人的密碼只要 `account.update`，不需要操作者驗證；重設雙重驗證卻要 `manageSecurity` 加驗證。帶 `password` 時改為要求 `adminAuth.assertVerification(ctx, authVerificationOperations.changePassword)`，或規定改密碼必須有 `manageSecurity`。
  - 對象是自己時，會略過個人頁改密碼要求的目前密碼與驗證，並撤銷包含目前工作階段在內的所有工作階段，前端顯示成功後直接被導回登入頁。改為回欄位錯誤，請使用者改到個人安全性頁（前端配合見 `admin-frontend.md`）。
  - 寫入改用 pack 的 `resetAuthPassword`，取代手寫的 `revokeAllAuthSessionsAround` 加 `recordAuthEvent`。
- [ ] 禁止停用或刪除自己的三種寫法統一：delete 回 `common.conflict`、`enabled.patch` 回 `cannotDisableSelf` 欄位錯誤、put 不報錯而直接把 `enabled` 改回 true（回成功但沒有停用）。put 改成與 patch 相同，delete 改用語意明確的錯誤；可在 `libs/admin/auth.ts` 放 `assertNotSelf` 共用。

## 服務商

- [ ] 決定服務商密鑰是否只寫：pack 的 provider `config` 是 `s.mixed()`，列表原樣回傳 SMTP 密碼與 SMS API key，只有 `*.provider.list` 的管理員就能取得第三方憑證，前端編輯表單也直接預填。若改為只寫：列表不回傳密鑰欄位，PUT 留空時保留原值，`cacheKey` 以合併後的 config 計算；需要 pack schema 與前端表單一起改。
- [ ] `cacheKey` 的計算移到 pack 後（見 `pack.md`），刪掉 `{email,sms}/provider/index.post.ts`、`[id]/index.put.ts` 的四份 `cryptoMd5(...)`。

## 簡化

- [ ] `email/provider`、`email/sender-identity`、`sms/provider`、`platform/ip-access-policy` 的 `[id]/enabled.patch.ts` 都是先 find 再 `assertUpdateSuccess`，改用 pack 既有但沒人用的 `assertUpdateOneByRouteId` 一次查詢；`z.object({ enabled: z.boolean() })` 放進 `common-zod-schemas`。admin 的 `enabled.patch` 要範圍檢查，維持現狀。
- [ ] email 與 sms provider 的 CRUD 路由只差 model、variants 與權限 key；做完上面兩項後每檔約 10 行，維持各自的檔案，不做路由工廠。要再合併的話只抽 `jsonSchemaShape` 與「code 不可變」檢查到 `libs/provider.ts`。
