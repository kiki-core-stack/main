# pack 待辦

## 服務商與寄送

- [ ] provider `cacheKey`（`models/{email,sms}/provider.ts`）：只是 instance 快取的 key 卻設了 `unique`，建立第二個 code、proxy、config 都相同的 provider（例如同一組帳號、不同 priority）時會回 `duplicateKey`，`fields: ['cacheKey']` 是表單上沒有的欄位。拿掉 `unique`，把計算移進 pack（schema `pre('validate')` 或匯出 helper），刪掉 management-backend 的四份。`providers/*/index.ts` 的 instances Map 不清舊 key、編輯設定後舊 instance 一直留在 worker，和「審查」的 provider class 項目一起看。
- [ ] email 與 sms 兩套幾乎相同的堆疊收斂：`*SendRecordStatus` 完全相同、provider schema 只差 code enum、send-record 只差 `from`／`subject` 與 `sender`、`*ProviderBaseData` 相同、`libs/{email,sms}.ts` 是同一個 transaction 內 insertMany 加 outbox 的流程、`providers/*/error.ts` 相同。共用一個狀態 enum、provider schema 欄位 builder、一個 error class、一個 enqueue helper，並提供通道描述（Provider 與 SendRecord model、取得 instance 的函式、`JobType`）給 ops-workers-ts 的 factory（見 `ops-workers-ts.md`）；collection 維持分開。`sendEmail`／`sendSms` 統一成 `send` 和 provider class 審查一起做。

## Auth

- [ ] 只給後端用的 auth 型別（`StoredAuthSession` 含 `secretHash`、引用 mongoose `Types` 的 `AuthPrincipal`、`RecordAuthEventInput`、`AuthMessage`、`AuthOperationContext`）放在公開的 `types/auth.ts`，經 `./types/*` 匯出給前端；前端只用 `AuthFactor`。移到 `libs/auth` 或 `hono-backend/types`，`types/auth.ts` 只留 `AuthFactor`／`AuthSecondFactor`。

## 簡化

- [ ] 無效 ObjectId 的處理統一：`findByRouteIdOrThrowNotFoundError` 自己檢查 `Types.ObjectId.isValid`，`findByRouteId` 與 `assertUpdateOneByRouteId` 則靠 `setups/error-handling.ts` 把 `_id` 的 `CastError` 轉成 notFound。留全域對應，刪掉個別檢查。
