# ops-workers-ts 待辦

## Bug

- [ ] outbox publisher 沒事件時固定等 60 秒（`job-outbox-event-publisher.ts`）：失敗重排的 `nextPublishAt = now + 5s` 與過期 lease 都不會產生 insert change event，Redis 短暫出錯讓 `queue.add` 失敗時，OTP 會延遲約 60 秒而不是 5 秒；publisher 崩潰留下的 lease 也要等 60 秒。claim 為空時改等 `min(最早的 max(nextPublishAt, publishLeaseUntil), 60s)`，並加「等待期間有新事件」的旗標。修好後 `publishAttemptCount >= 10` 的上限只剩約 50 秒，要一起改成指數退避或以時間為上限。
- [ ] 停在 Pending 的紀錄沒有收尾：reconciler 只掃 Processing，outbox 事件在 `queue.add` 後就刪除，之後 job 遺失（Redis 沒持久化或被清掉）、在 claim 前用完嘗試、或 stalled job 被另一個 worker 跑完後原 worker 才寫回 Pending，紀錄都會永遠停在 Pending。reconciler 另外掃「Pending 且 updatedAt 超過 N 分鐘、沒有對應 outbox 事件」的紀錄：job 是 failed／completed 就標 Failed，job 不存在就重新 add（Pending 有 claim 把關，重送安全）。
- [ ] publisher 的 switch 沒有 default（`#publishOutboxEvent`、`#finalizeOutboxEventTarget`）：下游在保留區段新增 `JobType` 卻沒補 case 時，TS 不報錯，事件每 30 秒被重新 claim、`publishAttemptCount` 無限增加且沒有錯誤紀錄。改用 `Record<JobType, handler>` 讓漏掉的型別編譯失敗，或 default 走 `#finalizeOutboxEventFailure`。
- [ ] change stream 出錯後不重建：遇到無法自動 resume 的錯誤（例如 history lost）時只記 log，之後只靠 60 秒輪詢，直到程序重啟。在 `error`／`close`（且不在關機中）時延遲後重新 `watch`。

## 簡化

- [ ] email 與 sms 模組逐行相同（worker、reconciler、index、queue、types，約 430 行；最近 `c1d9be1`、`e6e4cca`、`fe39cd8` 都得兩邊各修一次）：改成一個 send-channel factory，每個 channel 只提供 record／provider model、取得與關閉 instance 的函式、`send`、error class、`JobType`、concurrency env 名稱與 log 標籤。順手處理 `queue.ts` 為了取 logger 而 `import { emailModule } from '../'` 的循環依賴，以及 worker 取 provider 失敗分支併進同一條寫回路徑。pack 端配合見 `pack.md`。
- [ ] publisher 的 email／sms 分支（約 150 行）改成 `JobType → { queue, recordModel }` 表格驅動，可直接沿用上一項的 channel 設定，也一併解決 switch 沒有 default 的問題。
