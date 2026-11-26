# admin-frontend 待辦

## Bug

- [ ] 管理員頁編輯自己時隱藏密碼與確認密碼欄位，配合後端改為拒絕（見 `management-backend.md` 改密碼的驗證）。

## 簡化

- [ ] 刪掉多餘的 `before-dialog-open` config 設定：`pages/email/provider.vue`、`pages/sms/provider.vue`、`pages/platform/config.vue`（含 `resetFormConfig`）；`form-dialog.vue` 的 `createFormData` 已經會深拷貝 `config`。
- [ ] email 與 sms 服務商頁合併成一個 `provider-page` 元件，props 為 `crudApi`、`permissionGroup`、`resourceName`、`codeEnum`、`i18nPrefix`、`configForms`；form data 型別改成同一個泛型。`sms/provider-config-form/tw-sms.vue` 與 `mitake.vue` 完全相同（pack schema 也相同），合併成一個元件，兩個 code 都對應到它。
- [ ] 啟用開關欄改由 `data-table-page` provide/inject `crudApi`、`can`、`loadData`：目前 5 頁各自傳 `ref`、重複的 `:crud-api`、`!dataTablePageRef?.can('toggle')`、`@status-change="loadData()"`；改完頁面只傳 `field`、`label`、`confirm-message` 與額外的停用條件。
- [ ] 「建立管理員帳號／編輯管理員帳號」兩欄在 6 頁重複，`data-table-page` 加一個開關（例如 `showAdminAuditColumns`）統一顯示。
- [ ] enum 下拉做成 `selector-enum`（props 為 `enum`、`i18nPrefix`），取代 `selector/admin/log-type.vue`、`auth/event-type.vue`、`email/sender-identity-key.vue` 與頁面內嵌的 4 處 `el-select` + `getEnumNumberValues`。
- [ ] `auth/principal-security-dialog.vue` 複製了 `pages/profile/security/session.vue`、`event.vue` 的欄位與 `formatEventType`，文案已分岔（「由管理員操作」對「由其他管理員操作」）。抽出共用的 column 元件或 formatter，統一文案，並刪掉兩邊空的 `import {} from '@kcs-project/pack/constants/auth'`。
- [ ] `pages/profile/index.vue` 只有 `<div>1</div>`：刪掉或轉址到 `/profile/security/`。
