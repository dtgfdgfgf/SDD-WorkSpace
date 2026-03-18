#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-commit hook for SDD document validation and commit message format checking.

.DESCRIPTION
    This hook validates:
    1. spec.md files contain required sections
    2. readiness and ECI dossier artifacts contain required governance fields
    3. plan.md files contain required sections
    4. tasks.md files follow checklist format
    5. Commit messages follow Conventional Commits format

.NOTES
    To enable: git config core.hooksPath .githooks
    To bypass: git commit --no-verify
#>

$ErrorActionPreference = 'Continue'
$script:hasErrors = $false
$script:workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:sharedRuntimeContractPath = Join-Path $script:workspaceRoot 'studio/runtime/shared-runtime-contract.json'
$script:sharedRuntimeAuditScript = Join-Path $script:workspaceRoot 'studio/scripts/powershell/check-speckit-runtime.ps1'

function Write-HookError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    $script:hasErrors = $true
}

function Write-HookWarning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-HookSuccess {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-HookInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Convert-ToRepoRelativePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    return ($Path -replace '\\', '/').TrimStart('./')
}

function Get-SharedGatePaths {
    if (-not (Test-Path -LiteralPath $script:sharedRuntimeContractPath)) {
        return @()
    }

    try {
        $contract = Get-Content -LiteralPath $script:sharedRuntimeContractPath -Raw | ConvertFrom-Json -AsHashtable
        return @($contract.sharedGatePaths | ForEach-Object { Convert-ToRepoRelativePath -Path ([string]$_) })
    } catch {
        Write-HookError "Unable to read shared runtime contract: $($script:sharedRuntimeContractPath)"
        return @()
    }
}

function Test-IsSharedGateHit {
    param(
        [string]$Path,
        [string[]]$GatePaths
    )

    $normalizedPath = Convert-ToRepoRelativePath -Path $Path
    foreach ($gatePath in $GatePaths) {
        if ($gatePath.EndsWith('/')) {
            if ($normalizedPath.StartsWith($gatePath, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        } elseif ($normalizedPath.Equals($gatePath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Invoke-SharedRuntimeAudit {
    if (-not (Test-Path -LiteralPath $script:sharedRuntimeAuditScript)) {
        Write-HookError "Shared runtime audit script not found: $($script:sharedRuntimeAuditScript)"
        return
    }

    # shared runtime audit
    $auditOutput = & $script:sharedRuntimeAuditScript -Json 2>&1
    $auditExitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    $auditJson = if ($auditOutput) { $auditOutput -join [Environment]::NewLine } else { $null }

    if ([string]::IsNullOrWhiteSpace($auditJson)) {
        Write-HookError 'Shared runtime audit did not return JSON output.'
        return
    }

    try {
        $auditResult = $auditJson | ConvertFrom-Json -AsHashtable
    } catch {
        Write-HookError 'Unable to parse shared runtime audit JSON output.'
        Write-Host $auditJson -ForegroundColor DarkGray
        return
    }

    if ($auditExitCode -ne 0 -or -not $auditResult.VALID -or [int]$auditResult.ERROR_COUNT -gt 0) {
        Write-HookError 'Shared runtime audit failed: studio shared layer drift detected.'
        foreach ($failure in @($auditResult.FAILURES)) {
            $pathSuffix = if ($failure.path) { " [$($failure.path)]" } else { '' }
            Write-Host "    - [$($failure.category)] $($failure.message)$pathSuffix" -ForegroundColor Red
        }
        return
    }

    Write-HookSuccess 'Shared runtime audit passed'
}

function Get-EdgeCaseCount {
    param([string]$Content)

    $count = 0
    $sectionPattern = '(?ms)^#{2,6}\s*(Edge Cases|Boundary Cases|Exception Cases|Error Handling|邊界情況|邊界案例|例外情況|異常情況|錯誤處理)\s*$([\s\S]*?)(?=^#{1,6}\s|\z)'
    $sectionMatches = [regex]::Matches($Content, $sectionPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    foreach ($match in $sectionMatches) {
        $body = $match.Groups[2].Value
        $count += [regex]::Matches($body, '(?m)^\s*(?:[-*]|\d+\.)\s+').Count
    }

    if ($count -gt 0) {
        return $count
    }

    $fallbackPattern = '(?mi)^\s*(?:[-*]|\d+\.)\s+.*(edge|boundary|exception|error|invalid|empty|null|overflow|timeout|邊界|例外|異常|錯誤|無效|空值|逾時|超時)'
    return [regex]::Matches($Content, $fallbackPattern).Count
}

function Test-RequiredPatterns {
    param(
        [string]$Content,
        [object[]]$Requirements
    )

    $missing = @()
    foreach ($requirement in $Requirements) {
        if ($Content -notmatch $requirement.Pattern) {
            $missing += $requirement.Name
        }
    }

    return $missing
}

function Get-ReadinessValidationErrors {
    param(
        [string]$Path,
        [string]$Content
    )

    $leaf = Split-Path -Path $Path -Leaf
    $requirements = @()

    switch ($leaf) {
        'readiness-assessment.md' {
            $requirements = @(
                @{ Name = 'Title'; Pattern = '(?mi)^#\s+Readiness Assessment:' },
                @{ Name = 'Date field'; Pattern = '(?mi)^\*\*Date\*\*:' },
                @{ Name = 'Primary Status field'; Pattern = '(?mi)^\*\*Primary Status\*\*:' },
                @{ Name = 'Recommended Next Step field'; Pattern = '(?mi)^\*\*Recommended Next Step\*\*:' },
                @{ Name = 'Summary section'; Pattern = '(?mi)^##\s+Summary\s*$' },
                @{ Name = 'Readiness Dimension Scan section'; Pattern = '(?mi)^##\s+Readiness Dimension Scan\s*$' },
                @{ Name = 'Primary Blocker Analysis section'; Pattern = '(?mi)^##\s+Primary Blocker Analysis\s*$' },
                @{ Name = 'Allowed / Not Allowed Next Actions section'; Pattern = '(?mi)^##\s+Allowed\s*/\s*Not Allowed Next Actions\s*$' },
                @{ Name = 'Allowed subsection'; Pattern = '(?mi)^#{2,3}\s+Allowed\s*$' },
                @{ Name = 'Not Allowed subsection'; Pattern = '(?mi)^#{2,3}\s+Not Allowed\s*$' }
            )
        }
        'eci-trigger.md' {
            $requirements = @(
                @{ Name = 'Preliminary Recommendation field'; Pattern = '(?mi)^\*\*Preliminary Recommendation\*\*:' },
                @{ Name = 'Why This Blocks Planning section'; Pattern = '(?mi)^##\s+Why This Blocks Planning\s*$' },
                @{ Name = 'Return Condition section'; Pattern = '(?mi)^##\s+Return Condition\s*$' }
            )
        }
        'eci-assessment.md' {
            $requirements = @(
                @{ Name = 'Title'; Pattern = '(?mi)^#\s+ECI Assessment:' },
                @{ Name = 'ECI Level field'; Pattern = '(?mi)^\*\*ECI Level\*\*:' },
                @{ Name = 'Recommended Authorization field'; Pattern = '(?mi)^\*\*Recommended Authorization\*\*:' },
                @{ Name = 'Capability Inventory section'; Pattern = '(?mi)^##\s+Capability Inventory\s*$' },
                @{ Name = 'Governance Determination section'; Pattern = '(?mi)^##\s+Governance Determination\s*$' },
                @{ Name = 'Recommended Authorization Path section'; Pattern = '(?mi)^##\s+Recommended Authorization Path\s*$' },
                @{ Name = 'Return To Readiness section'; Pattern = '(?mi)^##\s+Return To Readiness\s*$' }
            )
        }
        'source-manifest.md' {
            $requirements = @(
                @{ Name = 'Title'; Pattern = '(?mi)^#\s+ECI Source Manifest:' },
                @{ Name = 'Canonical Source Rules section'; Pattern = '(?mi)^##\s+Canonical Source Rules\s*$' },
                @{ Name = 'Source Inventory section'; Pattern = '(?mi)^##\s+Source Inventory\s*$' },
                @{ Name = 'Known Gaps section'; Pattern = '(?mi)^##\s+Known Gaps\s*$' }
            )
        }
        'adoption-record.md' {
            $requirements = @(
                @{ Name = 'Title'; Pattern = '(?mi)^#\s+ECI Adoption Record:' },
                @{ Name = 'Adoption Boundary section'; Pattern = '(?mi)^##\s+Adoption Boundary\s*$' },
                @{ Name = 'ADR-Lite Decision section'; Pattern = '(?mi)^##\s+ADR-Lite Decision\s*$' },
                @{ Name = 'Packaging / Integration Stance section'; Pattern = '(?mi)^##\s+Packaging\s*/\s*Integration Stance\s*$' },
                @{ Name = 'Allowed Modes section'; Pattern = '(?mi)^##\s+Allowed Modes\s*$' },
                @{ Name = 'Prohibited Modes section'; Pattern = '(?mi)^##\s+Prohibited Modes\s*$' },
                @{ Name = 'Re-Intake Triggers section'; Pattern = '(?mi)^##\s+Re-Intake Triggers\s*$' }
            )
        }
        'authorization-record.md' {
            $requirements = @(
                @{ Name = 'Title'; Pattern = '(?mi)^#\s+ECI Authorization Record:' },
                @{ Name = 'Authorization Outcome field'; Pattern = '(?mi)^\*\*Authorization Outcome\*\*:' },
                @{ Name = 'Allowed Implementation Scope section'; Pattern = '(?mi)^##\s+Allowed Implementation Scope\s*$' },
                @{ Name = 'Explicit Prohibitions section'; Pattern = '(?mi)^##\s+Explicit Prohibitions\s*$' },
                @{ Name = 'Prerequisites section'; Pattern = '(?mi)^##\s+Prerequisites\s*$' },
                @{ Name = 'Evidence Required To Upgrade Authorization section'; Pattern = '(?mi)^##\s+Evidence Required To Upgrade Authorization\s*$' },
                @{ Name = 'Return To Readiness section'; Pattern = '(?mi)^##\s+Return To Readiness\s*$' }
            )
        }
        'repo-context-packet.md' {
            $requirements = @(
                @{ Name = 'Canonical Source / Runtime Authority Map section'; Pattern = '(?mi)^##\s+Canonical Source\s*/\s*Runtime Authority Map\s*$' },
                @{ Name = 'Protected or Do-Not-Break Areas section'; Pattern = '(?mi)^##\s+Protected or Do-Not-Break Areas\s*$' },
                @{ Name = 'Return Condition section'; Pattern = '(?mi)^##\s+Return Condition\s*$' }
            )
        }
        'decision-record.md' {
            $requirements = @(
                @{ Name = 'Viable Options section'; Pattern = '(?mi)^##\s+Viable Options\s*$' },
                @{ Name = 'Recommended Owner / Approver section'; Pattern = '(?mi)^##\s+Recommended Owner\s*/\s*Approver\s*$' },
                @{ Name = 'Return Condition section'; Pattern = '(?mi)^##\s+Return Condition\s*$' }
            )
        }
        'validation-contract.md' {
            $requirements = @(
                @{ Name = 'Claims That Require Evidence section'; Pattern = '(?mi)^##\s+Claims That Require Evidence\s*$' },
                @{ Name = 'Evaluation Method section'; Pattern = '(?mi)^##\s+Evaluation Method\s*$' },
                @{ Name = 'Return Condition section'; Pattern = '(?mi)^##\s+Return Condition\s*$' }
            )
        }
        'access-setup-checklist.md' {
            $requirements = @(
                @{ Name = 'Required Access / Runtime Items section'; Pattern = '(?mi)^##\s+Required Access\s*/\s*Runtime Items\s*$' },
                @{ Name = 'Risks of Proceeding Without Setup section'; Pattern = '(?mi)^##\s+Risks of Proceeding Without Setup\s*$' },
                @{ Name = 'Return Condition section'; Pattern = '(?mi)^##\s+Return Condition\s*$' }
            )
        }
        'exploration-boundary.md' {
            $requirements = @(
                @{ Name = 'Why Mainline Commitment Is Premature section'; Pattern = '(?mi)^##\s+Why Mainline Commitment Is Premature\s*$' },
                @{ Name = 'Allowed Exploration section'; Pattern = '(?mi)^##\s+Allowed Exploration\s*$' },
                @{ Name = 'Explicitly Not Allowed section'; Pattern = '(?mi)^##\s+Explicitly Not Allowed\s*$' },
                @{ Name = 'Evidence Needed To Re-Enter Readiness section'; Pattern = '(?mi)^##\s+Evidence Needed To Re-Enter Readiness\s*$' }
            )
        }
        default {
            return @()
        }
    }

    return Test-RequiredPatterns -Content $Content -Requirements $requirements
}

# ========================================
# Get staged files
# ========================================
$stagedFiles = git diff --cached --name-only --diff-filter=ACM 2>$null
if (-not $stagedFiles) {
    Write-HookInfo 'No staged files to validate'
    exit 0
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  SDD Pre-Commit Validation' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

$sharedGatePaths = Get-SharedGatePaths
$sharedLayerFiles = @()
if ($sharedGatePaths.Count -gt 0) {
    $sharedLayerFiles = @($stagedFiles | Where-Object { Test-IsSharedGateHit -Path $_ -GatePaths $sharedGatePaths })
}

if ($sharedLayerFiles.Count -gt 0) {
    Write-HookInfo 'Shared-layer files detected; running shared runtime audit...'
    Invoke-SharedRuntimeAudit
    Write-Host ''
}

# ========================================
# 1. Validate spec.md files
# ========================================
$specFiles = $stagedFiles | Where-Object { $_ -match 'spec\.md$' }

if ($specFiles) {
    Write-HookInfo 'Validating spec.md files...'

    $requiredSections = @(
        @{ Name = 'Problem/Goal'; Pattern = 'Problem|Goal|Overview|問題|目標|概述' },
        @{ Name = 'Actors'; Pattern = 'Actor|User|Stakeholder|角色|使用者|利害關係人' },
        @{ Name = 'Scenarios'; Pattern = 'Scenario|User Flow|Use Case|情境|流程|使用案例' },
        @{ Name = 'Functional Requirements'; Pattern = 'Functional Requirement|FR\b|功能需求' },
        @{ Name = 'Non-Functional Requirements'; Pattern = 'Non-Functional Requirement|NFR\b|非功能需求' },
        @{ Name = 'Edge Cases'; Pattern = 'Edge Case|Boundary|Exception|Error Handling|邊界|例外|錯誤處理' },
        @{ Name = 'Success Criteria'; Pattern = 'Success Criteria|Acceptance Criteria|成功標準|驗收標準' },
        @{ Name = 'Out of Scope'; Pattern = 'Out of Scope|Exclusion|Not Included|不在範圍|排除項目' }
    )

    foreach ($file in $specFiles) {
        if (-not (Test-Path $file)) { continue }
        $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $missingSections = @()
        foreach ($section in $requiredSections) {
            if ($content -notmatch $section.Pattern) {
                $missingSections += $section.Name
            }
        }

        $edgeCaseCount = Get-EdgeCaseCount -Content $content
        if ($edgeCaseCount -lt 3) {
            $missingSections += "At least 3 Edge Cases (found: $edgeCaseCount)"
        }

        if ($missingSections.Count -gt 0) {
            Write-HookError "[$file] Missing required sections:"
            foreach ($missing in $missingSections) {
                Write-Host "    - $missing" -ForegroundColor Red
            }
        }
        else {
            Write-HookSuccess "[$file] All required sections present"
        }
    }
    Write-Host ''
}

# ========================================
# 2. Validate readiness artifacts
# ========================================
$readinessFiles = $stagedFiles | Where-Object {
    $_ -match '(^|[\\/])readiness(?:[\\/]eci)?[\\/](readiness-assessment|eci-trigger|repo-context-packet|decision-record|validation-contract|access-setup-checklist|exploration-boundary|eci-assessment|source-manifest|adoption-record|authorization-record)\.md$'
}

if ($readinessFiles) {
    Write-HookInfo 'Validating readiness artifacts...'

    foreach ($file in $readinessFiles) {
        if (-not (Test-Path $file)) { continue }
        $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $validationErrors = Get-ReadinessValidationErrors -Path $file -Content $content
        if ($validationErrors.Count -gt 0) {
            Write-HookError "[$file] Readiness validation failed:"
            foreach ($err in $validationErrors) {
                Write-Host "    - Missing $err" -ForegroundColor Red
            }
        }
        else {
            Write-HookSuccess "[$file] Readiness artifact structure valid"
        }
    }
    Write-Host ''
}

# ========================================
# 3. Validate plan.md files
# ========================================
$planFiles = $stagedFiles | Where-Object { $_ -match 'plan\.md$' }

if ($planFiles) {
    Write-HookInfo 'Validating plan.md files...'

    $requiredSections = @(
        @{ Name = 'Architecture'; Pattern = 'Architecture|System Design|Overview|架構|系統設計' },
        @{ Name = 'Technology'; Pattern = 'Tech|Technology|Stack|Language|Framework|技術|技術棧|框架' },
        @{ Name = 'Integration'; Pattern = 'Integration|API|Endpoint|整合|介接|端點' },
        @{ Name = 'Data Flow'; Pattern = 'Data Flow|Data Model|Schema|資料流|資料模型|結構' },
        @{ Name = 'Risks'; Pattern = 'Risk|Constraint|Limitation|風險|限制' },
        @{ Name = 'Why Not'; Pattern = 'Why Not|Alternative|Decision|Rejected|替代方案|不採用' }
    )

    foreach ($file in $planFiles) {
        if (-not (Test-Path $file)) { continue }
        $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $missingSections = @()
        foreach ($section in $requiredSections) {
            if ($content -notmatch $section.Pattern) {
                $missingSections += $section.Name
            }
        }

        if ($missingSections.Count -gt 0) {
            Write-HookError "[$file] Missing required sections:"
            foreach ($missing in $missingSections) {
                Write-Host "    - $missing" -ForegroundColor Red
            }
        }
        else {
            Write-HookSuccess "[$file] All required sections present"
        }
    }
    Write-Host ''
}

# ========================================
# 4. Validate tasks.md files
# ========================================
$tasksFiles = $stagedFiles | Where-Object { $_ -match 'tasks\.md$' }

if ($tasksFiles) {
    Write-HookInfo 'Validating tasks.md files...'

    foreach ($file in $tasksFiles) {
        if (-not (Test-Path $file)) { continue }
        $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $validationErrors = @()
        $taskMatches = [regex]::Matches($content, '(?m)^\s*-\s\[[ xX]\]\sT\d{3}\b')
        if ($taskMatches.Count -eq 0) {
            $validationErrors += 'No tasks found with proper checklist ID format (`- [ ] T001 ...`)'
        }

        if ($content -notmatch 'Definition of Done|DoD|Done when|Acceptance|完成條件') {
            $validationErrors += 'Missing Definition of Done section'
        }

        if ($content -notmatch '\[P[123]\]|Priority|優先') {
            $validationErrors += 'Missing priority markers (P1/P2/P3)'
        }

        if ($content -notmatch 'Risk:|Low|Medium|High|風險') {
            Write-HookWarning "[$file] Consider adding Risk Level indicators"
        }

        if ($validationErrors.Count -gt 0) {
            Write-HookError "[$file] Validation failed:"
            foreach ($err in $validationErrors) {
                Write-Host "    - $err" -ForegroundColor Red
            }
        }
        else {
            Write-HookSuccess "[$file] Checklist format valid"
        }
    }
    Write-Host ''
}

# ========================================
# 5. Validate Conventional Commits (if commit message exists)
# ========================================
Write-HookInfo 'Commit message will be validated by commit-msg hook'
Write-Host ''

# ========================================
# Final Result
# ========================================
Write-Host '========================================' -ForegroundColor Cyan

if ($script:hasErrors) {
    Write-Host ''
    Write-Host '[ERROR] Pre-commit validation FAILED' -ForegroundColor Red
    Write-Host ''
    Write-Host "Fix the issues above or use 'git commit --no-verify' to bypass" -ForegroundColor Yellow
    Write-Host ''
    exit 1
}
else {
    Write-Host '[OK] Pre-commit validation PASSED' -ForegroundColor Green
    Write-Host ''
    exit 0
}
