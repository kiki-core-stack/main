# 改 pack／pack-rs 的流程（給 agent）

依本流程改 pack／pack-rs 時，pack／pack-rs 可直接 push，不必另外詢問；下游 `main/repos/*` 的 push 照 KCS-RULES。

先改 pack／pack-rs，再依「下游程式要不要跟著改」與「要不要以實際執行驗證」選一種：

| 情況 | 做法 |
| --- | --- |
| 只改 pack，不需實際驗證（型別、文件、小修正） | pack commit 並 push → 下游 `update-pack-sha.mjs` 與安裝依賴 |
| 下游也要改，pack 的部分小且已確定 | pack commit 並 push → 下游重新 pin、安裝依賴後接著改 → 下游驗收後 commit |
| 跨多個 repo，或 pack 要邊驗證邊改 | 下游暫時改用本機 pack → 反覆修改與驗證直到驗收 → pack commit 並 push → 下游改回 git pin、重新安裝後 commit |

- 驗收：agent 以 API 或瀏覽器實際操作，或與人一起確認；型別與 lint 通過不算驗收。
- 依賴更新的 commit：下游以 `scripts/commit-dependency-upgrades.sh` commit 成 `chore: upgrade deps`；KCS 上游不 commit pin 與 lockfile（見 KCS-RULES）。
- 暫時改用本機 pack：
  - TS repo 的 `@kcs-project/pack` 改成 `link:<到 pack 的相對路徑>` 後重新安裝；ws.io-server 的 `kcs-project-pack` 改成 `path = "<到 pack-rs 的相對路徑>"`。
  - 驗收後改回 git pin 再重新安裝；commit 前確認 `package.json`、lockfile、`Cargo.toml` 沒有留下本機路徑。
- pack 的 ws.io 事件名稱改了時，跑 `scripts/generate-rust-ws.io-event-names.ts` 同步到 pack-rs，兩邊一起 commit。
