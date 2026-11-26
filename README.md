# kiki-core-stack (KCS)

KCS 的主 repo：整合各服務 repo、部署設定與共用腳本。各服務是獨立的 git repo，clone 到 `repos/`。

- 架構、開發與部署：[docs/kcs/main.md](./docs/kcs/main.md)。

下游 repo 以 `fetch-and-merge.sh` 合併本專案；自己的說明寫在 `docs/<專案名>/`，不修改上游的 docs，以免合併衝突。
