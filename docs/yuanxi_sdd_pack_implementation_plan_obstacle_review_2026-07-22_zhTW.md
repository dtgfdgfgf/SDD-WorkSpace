---
title: "Yuanxi SDD Pack Implementation Plan：2026-07-22 CLI 障礙重驗"
version: "0.1.0"
date: "2026-07-22"
language: "zh-TW"
owner: "元熙"
status: "bounded-revalidation"
parent_document: "docs/yuanxi_sdd_pack_implementation_plan_zhTW.md"
supersedes_for_current_use: "docs/yuanxi_sdd_pack_implementation_plan_obstacle_review_zhTW.md"
scope: "R-G03 B-001 and B-003 CLI fact revalidation only"
---

# Yuanxi SDD Pack Implementation Plan：2026-07-22 CLI 障礙重驗

## 1. 使用邊界

本文件只重新驗證舊 obstacle review 的 B-001 與 B-003。它不更新或授權執行
`docs/yuanxi_sdd_pack_implementation_plan_zhTW.md`，也不完成下列獨立工作：

- R-G02 的 implementation plan 全面版本與驗收條件更新。
- R-F01 的 machine-readable upstream alignment state。
- R-F02、R-F03、R-F05 的 Wave-4 採用、調整或拒絕決策矩陣。

因此，本文件是防止舊建議被誤用的 bounded evidence，不是 Yuanxi pack 的開工核准。

## 2. 重驗方法

2026-07-22 Asia/Taipei 執行下列唯讀命令：

```powershell
specify version
specify --help
specify init --help
specify extension --help
specify preset --help
specify workflow --help
```

同日核對 GitHub 官方 `github/spec-kit` v0.13.3 release 與該 tag 的 core、extensions、
presets、workflows reference。未執行 CLI upgrade、init、extension install、preset install
或 workflow run。

## 3. 證據分層

| Evidence surface | 2026-07-22 observed result | Interpretation |
|---|---|---|
| Local `specify version` | CLI Version `0.0.22`; displayed Template Version `0.13.3`; Released `2026-07-22` | Template metadata does not prove that the installed executable implements the v0.13.3 command surface. |
| Local `specify --help` | Only `init`, `check` and `version` are available | B-001 remains true for this installed executable. |
| Local `specify init --help` | Uses `--ai`; no `--integration` option | The old B-003 observation remains true only as a local legacy-executable fact. |
| Local extension, preset and workflow help | Each command is rejected as unknown | The installed executable cannot execute the planned extension, preset or workflow path. |
| Official v0.13.3 core reference | `specify init` uses `--integration <key>` | The old recommendation to replace `--integration` with `--ai` is wrong for the current official baseline. |
| Official v0.13.3 extension and preset references | `specify extension add` and `specify preset add` are documented | B-001 is false for the current official command surface. |
| Official v0.13.3 workflow reference | `specify workflow` supports run, install, lifecycle and catalog operations | Current upstream has a workflow surface that the local executable lacks. |

## 4. Revalidated Findings

### B-001

B-001 must be split by evidence source:

- Local result: still blocked because the installed CLI exposes only three top-level commands.
- Current official result: no longer true because v0.13.3 documents extension, preset and workflow
  command groups.

The pack plan cannot treat either statement as universal. Before implementation, the local CLI must
be deliberately upgraded or pinned to an owner-selected official release, then the exact executable
must be rechecked.

### B-003

B-003's 2026-05-08 observation is preserved as local history, but its recommended correction is
superseded. The current official v0.13.3 init interface uses `--integration`, while this machine's
legacy executable still uses `--ai`.

New examples targeting the current official baseline must use `--integration`. Existing local
`--ai` output is migration evidence, not current upstream guidance.

## 5. Safe Disposition

1. Do not execute the existing Yuanxi pack implementation plan as written.
2. Keep the original obstacle review as a visible historical snapshot.
3. Resolve R-G02 before implementation by selecting a tested target release and updating the full
   version range, acceptance criteria, tasks and smoke tests.
4. After any CLI upgrade or pin, rerun the six commands in Section 2 against that exact executable.
5. Do not infer adoption of current upstream workflows, extensions or presets from their existence;
   those decisions remain under the Wave-4 findings listed in Section 1.

## 6. Sources

| Source | Purpose |
|---|---|
| `specify version` and help output captured locally on 2026-07-22 | Installed executable facts |
| https://github.com/github/spec-kit/releases/tag/v0.13.3 | Official release identity and date |
| https://github.com/github/spec-kit/blob/v0.13.3/docs/reference/core.md | Current init option |
| https://github.com/github/spec-kit/blob/v0.13.3/docs/reference/extensions.md | Current extension commands |
| https://github.com/github/spec-kit/blob/v0.13.3/docs/reference/presets.md | Current preset commands |
| https://github.com/github/spec-kit/blob/v0.13.3/docs/reference/workflows.md | Current workflow commands |
| `docs/sdd-workspace-deep-review-2026-07-08_zhTW.md` Section 5.5 | Prior drift finding |
