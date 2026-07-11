# Studio Learnings

Cumulative learnings from all projects. Updated after each project completion.

## 本檔定位(2026-07-11 確立)

- 這裡收的是**盲點**:全 LLM 開發過程中,使用者與 LLM 當下都沒察覺、事後才暴露的痛點。特徵簽名是「靜默失敗」與「假信心」(綠燈但壞掉、宣稱完成但有缺口)。純工作記錄不收。
- 條目是中繼站,不是博物館:每條 learning 的終點是**畢業成環境改進**(gate、測試、prompt 資產或憲章規則),讓同類盲點下次自動現形;已畢業或不再適用的條目應退役。
- 內容會隨模型進化過期:半年回顧時對每條問「這在當前模型世代還會發生嗎?」——環境事實類(Git/PowerShell 行為)近乎永久,方法論類耐久,模型行為類最先過期。退役條目移到檔尾 Retired 區並留一行原因。
- 條目預設**不**升級成 session 層規則:能用機器 gate 攔的用 gate(零 context 成本);只有重複發生且 gate 攔不住的才進 prompt,且進一條要檢視能否退一條——過多過程約束會轉化為繞過率與 alert fatigue(依據: 2026-04-12 稽核)。

> 2026-07-11 回填說明:以下 [2026-04-02] 至 [2026-07-08] 條目為一次性考古回填,來源為
> docs/mainline-updates/ 21 份 note、56 個 commit、稽核文件與 Claude Code 對話 transcript
> (claude-mem observations),每條均經獨立對抗式驗證並附證據指標。此後條目應於每次
> session 收尾時即時追加,不再累積後考古。

---

## [2026-04-02] Project: SDD-WorkSpace(worktree parity)

### Learned

- Git 正確不等於專案完整:一次 Git 上完全正確的 cleanup 仍可產出操作性殘缺的 worktree,因為 junction、local bootstrap 資產不在 Git 追蹤面裡。此後同一抽象至少再滲漏三次(04-28 漏拷 AGENTS.md、Patch 5 的 .gitignore 牴觸 parity 政策、Patch 7 的 hooksPath),證明 parity 不變量無法一次定義完——每新增一個 adapter/junction/hook 都會再漏一次,parity 面必須收斂成單一清單讓所有衍生腳本讀同一份。(證據: docs/mainline-updates/2026-04-02-project-worktree-parity-governance.md、2026-04-28-worktree-agents-md-parity.md、2026-04-30-template-completion.md、2026-05-01-validation-and-worktree-hardening.md)
- Git worktree 不會繼承相對路徑的 core.hooksPath:主 repo 用相對路徑設 hooksPath 時,worktree 內解析到不存在的位置,等於整套 pre-commit 治理 gate 靜默失效、無任何錯誤訊息。建 worktree 的腳本必須事後主動重設,並用 e2e 測試驗證 hook 真的觸發。(證據: 2026-05-01 note M8、new-project-worktree.ps1:69-79、validate-feature-structure.Tests.ps1:218-257)

### Pain Points

- Trading worktree 事故:清理後 Git 視角完全乾淨,操作上殘缺;之後每加一個 bootstrap 資產,worktree 機器就漏一次。

---

## [2026-04-12] Project: SDD-WorkSpace(治理環境稽核,18 bugs)

### Learned

- 誰來治理治理者:pre-commit、runtime contract、impact routing 這些「驗證別人」的工具本身零測試,最嚴重的 bug 從系統建立起就存在且零偵測。驗證邏輯的 bug 比被驗證對象的 bug 更危險,因為它產生 false positive 安全假象;治理工具的第一優先投資是 self-verification layer,不是更多規則。(證據: claude-mem #S205/#S209、docs/studio-infrastructure-challenge-2026-04-12.md §3)
- PowerShell TrimStart('./') 是字元集合不是字首:它逐字移除 {'.','/'} 集合中的字元,導致 .github/、.claude/、.githooks/ 等 dotfile 路徑被剝掉開頭的點,impact routing 對全部核心治理路徑「從建立起就從未觸發過」。字首移除要用 -replace '^\.\/', ''。(證據: commit 33557cf 前身 diff、claude-mem #S205/#S206、pre-commit.Tests.ps1 C1/C2 回歸測試)
- 生成器輸出編碼必須顯式對齊來源:seed 腳本用 UTF8 BOM + CRLF 輸出,來源是 no-BOM + LF,15 個生成檔全部變 git 髒檔、front-matter 開頭出現不可見 BOM。(證據: claude-mem obs #3325/#3327、.claude/.agent-no-bom-resave-backup/)
- 強制治理若無逃生路徑,實際效果是訓練使用者繞過它:--no-verify 一個 flag 繞過整套治理且無補償控制(無 CI 二次驗證);七階段無 hotfix 協議;所有驗證失敗一視同仁造成 alert fatigue。嚴格度會轉化為繞過率;治理設計要同時給緊急路徑與嚴重度分級。(證據: claude-mem #S209 learned 段)
- 想簡化卻沒想法時,先建測試:原目標「簡化 agent mirror」零進展,session 轉向先建測試套件(7 檔 61 測試),過程中又挖出 3 個稽核沒抓到的 bug,且隔天的簡化因此變成低風險操作。(證據: claude-mem #S210)
- 知識回饋機制設計太重就不會轉:learnings.md 建立數月零條目,專案內 retrospective 都存在,但「聚合到 studio 層」這步從未自然發生——跨專案聚合需要工具化(transcript 收割),不能指望手動儀式。(證據: claude-mem obs #1459、#S209)

### Prompt Candidates

- [ ] PowerShell 陷阱掃描 prompt:TrimStart/TrimEnd 字元集合語意、$LASTEXITCODE 可能為 null、@($null) 非空陣列、Get-ChildItem 單結果回傳 scalar 等,供審查 .ps1 逐項掃描(target: studio/prompts/implement/)

---

## [2026-04-13 至 04-26] Project: SDD-WorkSpace(mirror 簡化與 impact registry)

### Learned

- 沒有消費者的同步副本是死基礎設施:studio/templates/sdd-agents/ 鏡像沒有任何 init script 或 runtime 讀它,requiredMirrorPairs 契約、SHA256 parity、auto-fix、Pester 測試整條鏈只服務「維持這份鏡像存在」本身。維護同步契約前先問「誰在消費這份拷貝」;安全移除順序是先刪契約定義讓 validator 變 no-op,再拆執行程式碼。(證據: claude-mem #S211/#S212、commit 3355c7f「Remove the obsolete sdd-agents template mirror」)
- 手工副本與手工中央索引都是 drift 產生器:手工同步使「刻意的未 commit 更新」與「未發現的 drift」在資訊上不可區分;為治理 drift 而建的中央索引若手工維護,自己就變成新 drift 源。正解是宣告 authority、由 generator 產生、加 -Compare freshness gate。(證據: commit a6c4fbd 對稱 diff、commit 3355c7f + generate-impact-registry.ps1、docs/sdd-drift-governance-core-logic.md 原則 9)

---

## [2026-04-17] Project: SDD-WorkSpace + japanese-learning(模型升級)

### Learned

- 模型 ID 升級不是改一個字串:Workspace 端 30 個 agent 檔各自寫死 model 欄位;三個月後 japanese-learning 重演同型事故——只改 MODE_MODEL_MAP,結果 PRICING 表 fallback 導致成本低估約 40%、3 個測試寫死舊 model 名而紅掉、Opus 4.7 拒收 temperature 導致每請求 400。model ID 應集中單一來源;升級需固定 checklist(model map、pricing、測試斷言、sampling 參數相容、文件),用 prefix 比對換前向相容。(證據: commit b1ee5cb、claude-mem #S285、observer transcript 39406ae9)

### Prompt Candidates

- [ ] LLM 模型升級檢查清單 prompt:列出 repo 內所有 model ID 出現點(config、pricing、tests、docs、agent frontmatter),逐項確認同步與 API 參數相容性(target: studio/prompts/implement/)

---

## [2026-04-28] Project: SDD-WorkSpace(v1.8.0 收尾)

### Learned

- 「真正收尾」宣告不可信:v1.8.0 合入當天連補四個 commit,message 從「follow-up 收尾」升級到「真正收尾」;同日三份 mainline note 互相 supersede 對方的 closure 宣稱;之後 deep review 仍挖出 48 個實作缺口(機器強制率當時僅約 70%)。收尾的定義必須是「每條新規則有對應的 invariant/hook/test」,不是「文件寫了」;當自己開始寫「真正收尾」時,正是該跑獨立深評的訊號。(證據: commits 1a8078b/ef71fb3/8fe7357/a439c64/5804628 同日、c6ee1f1 message 載 48 gaps、三份 04-28 note)
- 機器 invariant 也會流於表面:update-constitution-script 條目只鎖 6 個表面片語,沒鎖到腳本真正落實的三條治理規則——grep 字串的 invariant 製造「已被機器治理」的假象,比沒有檢查更危險。寫 invariant 要鎖規則的行為觸發點,不是措辭。(證據: commit a439c64 message、shared-runtime-contract.json update-constitution-script 條目)
- 向「同步檔案集」新增成員時,每個硬編碼枚舉該集合的腳本都是靜默漂移點:AGENTS.md 升為第三 adapter 後,worktree 腳本的複製迴圈仍只枚舉舊兩檔,靜默丟失且無錯誤。結構性解法是把「集合變更」註冊為 impact routing 的 change type。(證據: commits 5804628、8fe7357)
- 新增 enforcement 或 source_of_truth 文件時,impact routing 不會自己跟上:advisory 系統輸出過時地圖反而助長漏改——worktree parity 治理文件是 source_of_truth 卻無任何路由扇出到實作它的腳本,真的漏改一次後回頭才看見。每新增執法規則,同批必須新增對應路由。(證據: 2026-04-28-adapter-change-routing.md、2026-04-30-impact-routing-and-contract-split.md)

### Prompt Candidates

- [ ] 收尾前置檢查 prompt:宣稱治理批次 closed 前,列舉每條新規則並逐條回答「哪個 hook/script/invariant 驗證它?哪些衍生面(worktree、template、registry)要同步?」答不出即不得宣稱 closed(target: studio/prompts/analyze/)

---

## [2026-04-30 至 05-01] Project: SDD-WorkSpace(deep review 9 patches)

### Learned

- 文件裡的 MUST 不等於被執行的 MUST:憲章要求 shared-layer 變更附 note,hook 只查 constitution.md 一個路徑;七階段順序只由 agent prompt 執行,直呼腳本可跳過;一次審查找出 8 個「文件說 MUST、runtime 不驗」缺口。最有力的證據是自我違反:Patch 4 明訂 Ready note 必填 commit hash,但立規那份 note 自己至今仍是 TBD——因為該規則同樣沒有 gate。每寫一條 MUST,同批就要接上執行機制。(證據: 2026-04-30-hook-enforcement-tightening.md、2026-05-01-stage-entry-gates.md、2026-04-10-shared-layer-consistency-fix.md)
- 治理腳本的 warn-and-continue 是系統性風險:同一次審查找出至少五處靜默吸收錯誤(audit 未覆蓋路徑靜默 pass、checkout -b 失敗仍繼續、frontmatter 解析失敗靜默跳過、registry 過期只 warn)。在驗證機器中 warning 等於不存在;失敗路徑一律升級為非零 exit。(證據: 2026-04-30-critical-bug-cleanup.md H4/H6/M12/M14/M15)
- Gate 必須有「破壞後斷言它會擋」的 negative-path e2e 測試:憲章指定的機器驗收入口在 Patch 2 前沒有任何整合測試,「passing tests gave false confidence」。每個 gate 至少一個 break-then-assert-fail 測試,否則 gate 與 no-op 無法區分。(證據: 2026-04-30-hook-enforcement-tightening.md、pre-commit.Tests.ps1:438-501 H3 模式)
- 建立 artifact 不等於接上流程:change-manifest-template 出貨數月無任何 agent 引用,是讓 audit 綠燈的裝飾品;為消 ghost reference 建的 change-manifests/ 目錄至今仍只有 .gitkeep。audit 驗「存在」不驗「被使用」,死資產可長期綠燈;新增 template/schema/目錄時同批必須接上至少一個消費者。(證據: 2026-05-01-housekeeping.md M17)
- 字面子字串鎖內容的 invariant 太脆:無害的標點修改就 fail audit,逼人不敢改文件;解法是 governance-anchor HTML 註解 + mustContainAnchors。遷移策略:先在五個最常改的檔案 pilot,不做一次性全面遷移;遷移候選判準是「同一措辭六個月內改過兩次以上」。(證據: 2026-05-01-housekeeping.md、shared-runtime-contract.json governance-anchor-pilot-*)
- 檔名後綴匹配的 validator 會誤傷同名異類檔:*plan.md 打到 .claude/agents/speckit-plan.md;repo 裡「長得像目標檔案」的 mirror/seed/template 遠比想像多,validator 必須錨定完整 canonical 路徑(specs/<feature>/plan.md)。(證據: 2026-04-30-critical-bug-cleanup.md 的 Update 段、commit c6ee1f1 regex diff)
- 複製貼上的 parser 必然靜默分歧:三份近似的 Markdown 欄位 parser 各有微妙差異,且資料格式本身分裂成兩種冒號方言(**Field:** 與 **Field**:)。統一成單一 helper;但 pre-commit hook 刻意保留 shadow copy 加對齊註解——hook 的自我完備性優先於 DRY,因為 hook 必須在 common.ps1 被改壞時仍能運作。(證據: 2026-04-30-init-script-refactor.md M4/M13、common.ps1:856-871、pre-commit.ps1:463-467)

### Prompt Candidates

- [ ] MUST 落地稽核 prompt:掃描治理文件每條 MUST/MAY NOT,輸出三欄表(規則、執行機制、prose-only 標記),prose-only 列為待補 gate(target: studio/prompts/analyze/)
- [ ] Gate 驗收 prompt:對每個新 hook/gate/validator,產生「建 fixture、注入違規、斷言非零 exit + 錯誤訊息」的 e2e 測試骨架(target: studio/prompts/implement/)

---

## [2026-05-05 至 05-08] Project: SDD-WorkSpace(安全強化與 yuanxi pack 規劃)

### Learned

- 安全 helper 已存在不等於有安全:Assert-PathInsideRoot 早已在 common.ps1,但七階段 entry-gate 與 create-new-feature 共 8 個 call site 全部沒呼叫它,主要輸入路徑裸奔。安全控制的效力在 call-site 覆蓋率,不在 helper 是否存在;且邊界模型假設被推翻——consumer 專案可在磁碟任意位置,邊界要動態推導。防回歸:每個 call site 各加一條 scriptInvariant + 專屬回歸測試。(證據: 2026-05-05-studio-workflows-runtime.md、commit b01c366、path-traversal-hardening.Tests.ps1)
- 對一週多 release 的上游寫文件,版本基準必然過期:yuanxi pack 三份文件的基準三天內過期兩次(v0.8.5 到 0.8.6 到 0.8.7);更狠的是連「修正」本身也被反轉(當時建議改用 --ai,上游 0.10.0 移除 --ai)。文件必須記 verified-on 日期,並把 declared range 與 actually tested versions 分兩欄;接受「結論方向通常有效、操作細節每次實作前重驗」的現實。(證據: 三份 yuanxi 文件的 P0-5/B-002/B-003、deep-review §5.5)
- 官方 repo main 分支的文件不等於已出貨的 CLI 能力:依 main 分支 reference 假設 extension/preset subcommand 存在,本機實測 CLI 只有 init/check/version,plan 的多條 AC 無可執行路徑。依賴外部 CLI 的 plan 第一步必須是本機 --help capability detection;且 specify version 同時輸出 CLI 與 Template 兩個版本,要指明解析哪一欄。(證據: obstacle review B-001/B-003/R-004 與 §8)
- LLM 產出文件的完整感與可實作性是兩回事:strategy 收斂後 review 抓出 5 個 P0;plan 五輪迭代到 decisions-complete,同日 obstacle review 又抓出 5 個 P0——因為那些是「本機 CLI 實況」這種紙上決策解不了的經驗事實。實作前障礙檢查應制度化為獨立 companion 文件,核心動作是實測環境而非再讀文件。(證據: strategy review §3、obstacle review §3、plan §13 Iteration Log)
- Fork 母體模式被推翻,維護成本應掛鉤自用量而非上游速度:自訂語意(readiness gate、Intent Drift Check)織入官方 command 後,每次上游更新都是逐檔三方合併,而上游一週可出 5 個 release。反轉後架構:官方當 base、自有能力封裝成 namespaced extension、不覆寫 core。釘版本被證明正當(baseline 停 2026-03-06、上游衝到 0.12.6、本地零損壞——spec-kit 是 template+init CLI 不是 runtime 依賴);唯一必須主動追的是安全修補。(證據: yuanxi strategy §1-2、docs/0308upstreams/、deep-review §4.4/§8.1/§9)

### Prompt Candidates

- [ ] 外部 CLI capability detection prompt:列出 plan 假設的每個 subcommand/參數,逐一跑 --help 驗證並記錄,標記哪些 AC 依賴未驗證能力(target: studio/prompts/plan/)
- [ ] Pre-implementation obstacle review prompt:輸入 strategy/plan,輸出 P0 blockers(附本機實測證據)、P1 風險、回寫清單——已成功執行兩次,結構可直接抽自兩份 review 文件(target: studio/prompts/plan/)

---

## [2026-06-16] Project: KMS(RAG 規格審查)

### Learned

- 規格「技術正確」不等於「明天可以開工」:RAG 規格 v2 技術方向全對、18/18 計畫變更落實,但 executability 審查另挖出 11 個開工阻斷點(Windows 無 pgvector 安裝路徑、Python 3.14 無穩定 wheels、中文 BM25 斷詞未定義、DoD 依賴倒置、API key 不在 checklist)。且分節獨立修訂會產生跨節衝突(Citations 與 structured output 互斥)。規格審查至少三個獨立視角:涵蓋率、對抗式技術審查、可執行性;分段打磨後必須再做跨節交叉驗證。(證據: observer transcript 3ff13654)

### Prompt Candidates

- [ ] 「明天能否開工」executability review prompt:檢查環境安裝路徑、依賴版本相容、外部服務金鑰、步驟依賴方向、未定義關鍵參數(target: studio/prompts/plan/)

---

## [2026-07-11] Project: SDD-WorkSpace(外部 LLM 分析驗證)

### Learned

- LLM 盤點型調查的「計數」不可信,必須用確定性指令複驗:同一輪深評的三個計數全部出錯(測試檔 23 實為 18、模板 32 實為 28、TBD note 10 實為 18),而且錯誤方向不一致(有高估有低估),事後都由「ls/grep + wc」一行指令戳破。凡是進入文件或決策的數字,一律以指令輸出為準,LLM 讀後報數只能當線索。(證據: docs/sdd-workspace-deep-review-2026-07-08_zhTW.md §1 的兩處 2026-07-11 更正、驗證工作流 F5/F7 判定)
- 另一個 LLM 的分析同樣是自我報告,採納前要對抗式驗證——但驗證結果可能是「它對、我錯」:外部分析文件 31 條具體指控經六路平行實查全數 CONFIRMED,並糾正了本方兩個計數錯誤。驗證的價值是雙向的:既防對方的幻覺,也暴露自己的。(證據: docs/sdd-workspace-purpose-governance-maintenance-usage-analysis-2026-07-11_zhTW.md、驗證工作流 wf_c7dbaff4)
- 「命令齊全」不等於「執行圖合憲」:七階段的 agent 檔案與 inventory 全部存在且 audit 全綠,但 agent handoff 圖上存在三條可跳過強制階段的捷徑(specify 直達 readiness、clarify 明文可跳、tasks 直達 implement),且 analyze 被定義為 read-only 不落檔,使「從未分析」與「分析無 Critical」在機器上不可區分。契約鎖了檔案存在與內容片段,沒鎖階段轉移關係。(證據: 驗證工作流 A1-A5、B1-B3 全數 CONFIRMED)

### Pain Points

- 綠色 audit + 全綠測試給出的安全感,覆蓋不到「audit 根本沒檢查的維度」(handoff 圖、analyze 完成證明、Claude 鏡像 body 同步、extension 路徑安全)。

---

## [2026-07-07 至 07-08] Project: SDD-WorkSpace(求職資料稽核與深度評估)

### Learned

- 「未追蹤」不等於「安全」,「標注私有」不等於「實際私有」:個人求職資料在公開 repo 工作目錄下只差一個 git add .;更嚴重的是 bushingAOI 在履歷材料標注「公司專案、不可開源」,實際早已公開在 GitHub(P0 緊急轉私有)。repo 公開狀態與爆炸半徑必須驗證,不能靠記憶。(證據: observer transcripts 39406ae9、1e782568)
- Repo 內的測試結果檔會雙向說謊:過期的 testResults.xml 帶著 23 failures 躺兩個月,實跑是全綠;反向(舊綠檔掩蓋真壞)同樣成立。分析與交接一律本機實跑取當下真值;測試產物不入 repo;在全靠 LLM 維護的模式下,CI 是唯一不經 LLM 之手的獨立驗證者。(證據: deep-review §1/§8.2)
- 重驗本身也會查錯對象:一次重驗把 Trading-003 的 README 矛盾誤判為「已修掉」(grep 查到了 Trading 而非 Trading-003);同一輪深評把 18 個測試檔誤計為 23。重驗前先確認指涉的 repo/檔案正確;帶行號與數字的主張,行動前對現況再驗一次。(證據: 本次回填工作流的 verify 階段實測;Trading-003 README:41 矛盾至 2026-07-11 仍在)
- Mandatory 但無 enforcement 的義務執行率為零,連治理系統作者也不例外:憲章第 13 節強制 knowledge capture,learnings.md 空轉七個月,被稽核點名後仍未回填,直到工具化(transcript 考古收割)才發生。評估流程真實採用度看它強制產物的實際數量(全 workspace readiness artifact 僅 3 份),不看規則寫得多完整。(證據: claude-mem obs #1459、deep-review §2.3/§2.4)

### Pain Points

- 本次回填本身就是教訓的直接後果:痛點素材在 git 史沉睡數月,必須動用三路收割 + 34 條對抗式驗證的考古工程,而非當時隨手兩三行記下。

### Prompt Candidates

- [ ] Session 收尾 learnings 追加規則:每次治理 session 結束在 learnings.md 追加 2-3 行(踩的坑、哪個 gate 真的擋下什麼、哪個機制從未觸發),把 mandatory 變成有觸發點的動作(target: CLAUDE.md session 規則或 hook)
- [ ] 證據重驗 prompt:給定 evidence matrix/audit 文件,逐條 grep/實測當前 repo,輸出「仍成立/已失效/數字漂移」三態報告(target: studio/prompts/analyze/)
