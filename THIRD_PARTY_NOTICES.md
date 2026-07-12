# Third-Party Notices

The repository-level MIT License applies only to material that the repository owner has the right
to license. It does not replace, supersede, or relicense the third-party terms recorded below.
Path listings identify the current distribution scope. Generated mirrors and tracked archival
copies inherit the same source provenance as their canonical source.

This inventory reflects the repository at 2026-07-13. It is a provenance record, not legal advice.
If a contributor knows of an additional source or separate license, this file must be updated before
redistributing the affected material.

## GitHub Spec Kit

- Project: [github/spec-kit](https://github.com/github/spec-kit)
- License: [MIT](https://github.com/github/spec-kit/blob/main/LICENSE)
- Copyright notice: Copyright GitHub, Inc.
- Initial comparison baseline:
  [`9111699cd27879e3e6301651a03e502ecb6dd65d`](https://github.com/github/spec-kit/commit/9111699cd27879e3e6301651a03e502ecb6dd65d)

The following current paths contain material copied, translated, generated from, or substantially
adapted from GitHub Spec Kit:

- `.github/agents/speckit.{analyze,checklist,clarify,constitution,implement,plan,specify,tasks,taskstoissues}.agent.md`
- `.github/prompts/speckit.{analyze,checklist,clarify,constitution,implement,plan,specify,tasks,taskstoissues}.prompt.md`
- The corresponding generated files under `.claude/agents/` and tracked copies under
  `.claude/.agent-no-bom-resave-backup/`
- `studio/scripts/powershell/check-prerequisites.ps1`
- `studio/scripts/powershell/common.ps1`
- `studio/scripts/powershell/create-new-feature.ps1`
- `studio/scripts/powershell/setup-plan.ps1`
- `studio/scripts/powershell/update-agent-context.ps1`
- `studio/templates/sdd-docs/{agent-file,checklist,plan,spec,tasks,project-constitution}-template.md`

The following paths are conservatively included because repository records describe them as local
adaptations or reimplementations of upstream Spec Kit capabilities:

- `studio/scripts/powershell/setup-{clarify,readiness,tasks,analyze,implement}.ps1`
- `studio/extensions/` and the extension lifecycle scripts under `studio/scripts/powershell/`
- `studio/workflows/` and the workflow runner, engine, list, state, and validation scripts under
  `studio/scripts/powershell/`
- The Wave-2 skill and generic-agent export scripts under `studio/scripts/powershell/`

The conservative-scope paths are listed for provenance and attribution; this does not assert that
every line was copied from upstream. Local modifications and original additions are covered by the
repository-level MIT License, while the upstream portions retain the following notice.

### GitHub Spec Kit MIT License Text

MIT License

Copyright GitHub, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Removed Historical Snapshot: doggy8088/github-copilot-configs

Older commits contained `resources/github-copilot-configs/`, added in local commit `8e933b26`.
The removed snapshot matched 391 of 392 blobs from
[`doggy8088/github-copilot-configs` commit `e5969f1cc89a60c931049bd41dce55eaa8e6037f`](https://github.com/doggy8088/github-copilot-configs/commit/e5969f1cc89a60c931049bd41dce55eaa8e6037f).
The local `.vscode/mcp.json` was the sole differing blob.

No repository-level license was detected in that source when reviewed. Its
[`SYNC_README.md`](https://github.com/doggy8088/github-copilot-configs/blob/e5969f1cc89a60c931049bd41dce55eaa8e6037f/SYNC_README.md)
stated that portions under `.github/` were synchronized from
[`github/awesome-copilot`](https://github.com/github/awesome-copilot), which carries an
[MIT license](https://github.com/github/awesome-copilot/blob/main/LICENSE). The snapshot also
contained source-repository documentation, settings, and images without a verified license.

The snapshot is not part of the current tree and is not covered by this repository's MIT License.
Do not treat the historical snapshot as uniformly MIT-licensed, and do not restore it from Git
history as a source intake method. Any future intake must start from a source with a verified
license, pin a commit and hashes, and retain the applicable license and manifest.

## Runtime and CI Dependencies Not Bundled Here

These components are installed or executed by the operator or CI service and are not vendored into
this repository. Their names are recorded for dependency provenance. Their own licenses govern
them, and the repository-level MIT License does not relicense them.

| Dependency | Use | License |
|---|---|---|
| [Pester](https://github.com/pester/Pester) | PowerShell test framework | [Apache-2.0](https://github.com/pester/Pester/blob/main/LICENSE) |
| [powershell-yaml](https://github.com/cloudbase/powershell-yaml) | Workflow YAML parsing | [Apache-2.0](https://github.com/cloudbase/powershell-yaml/blob/master/LICENSE) |
| [actions/checkout](https://github.com/actions/checkout) | CI repository checkout | [MIT](https://github.com/actions/checkout/blob/main/LICENSE) |
| [actions/upload-artifact](https://github.com/actions/upload-artifact) | CI test-result artifact upload | [MIT](https://github.com/actions/upload-artifact/blob/main/LICENSE) |
