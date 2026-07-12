#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/common.ps1"

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false, $true)
$resolvedWorkspaceRoot = if ($WorkspaceRoot) {
    Resolve-AbsolutePath -Path $WorkspaceRoot
} else {
    Find-WorkspaceRoot -StartDir $PSScriptRoot
}

if (-not $resolvedWorkspaceRoot) {
    throw 'Unable to resolve workspace root.'
}

$sourceDir = Join-Path $resolvedWorkspaceRoot '.github/agents'
$outputDir = Join-Path $resolvedWorkspaceRoot '.claude/agents'

if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
    throw "Shared Copilot agents source not found: $sourceDir"
}

if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

function Get-FrontMatterAndBody {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $lines = [System.IO.File]::ReadAllLines($Path, $Utf8NoBom)
    if ($lines.Count -lt 3 -or $lines[0] -ne '---') {
        Write-Warning "Frontmatter missing or malformed in '$Path' (no leading '---' delimiter); skipping."
        return $null
    }

    $endIndex = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq '---') {
            $endIndex = $i
            break
        }
    }

    if ($endIndex -lt 0) {
        Write-Warning "Frontmatter missing closing '---' delimiter in '$Path'; skipping."
        return $null
    }

    return [PSCustomObject]@{
        FrontMatter = [string[]]@($lines[1..($endIndex - 1)])
        Body        = if ($endIndex + 1 -lt $lines.Count) { [string[]]@($lines[($endIndex + 1)..($lines.Count - 1)]) } else { [string[]]@() }
    }
}

function Get-FrontMatterValue {
    param(
        [AllowEmptyCollection()]
        [string[]]$FrontMatter,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    for ($i = 0; $i -lt $FrontMatter.Count; $i++) {
        if ($FrontMatter[$i] -match ("^{0}:\s*(.*)$" -f [Regex]::Escape($Key))) {
            $raw = $Matches[1].Trim()
            if ([string]::IsNullOrWhiteSpace($raw) -or $raw -eq '>' -or $raw -eq '|') {
                $buffer = New-Object System.Collections.Generic.List[string]
                for ($j = $i + 1; $j -lt $FrontMatter.Count; $j++) {
                    $candidate = $FrontMatter[$j]
                    if ($candidate -match '^[A-Za-z0-9_-]+:\s*') {
                        break
                    }
                    if ($candidate -match '^\s+') {
                        $buffer.Add($candidate.Trim())
                    }
                }

                if ($buffer.Count -gt 0) {
                    return ($buffer -join ' ').Trim()
                }
            }

            return $raw.Trim('"', "'")
        }
    }

    return $null
}

function Get-FrontMatterListValue {
    param(
        [AllowEmptyCollection()]
        [string[]]$FrontMatter,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $raw = Get-FrontMatterValue -FrontMatter $FrontMatter -Key $Key
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    if ($raw.StartsWith('[') -and $raw.EndsWith(']')) {
        return [regex]::Matches($raw, "'([^']+)'|""([^""]+)""|([A-Za-z][A-Za-z0-9-]*)") |
            ForEach-Object {
                foreach ($groupName in 1, 2, 3) {
                    if (-not [string]::IsNullOrWhiteSpace($_.Groups[$groupName].Value)) {
                        return $_.Groups[$groupName].Value
                    }
                }
            }
    }

    return $raw.Split(',') | ForEach-Object { $_.Trim(" ", "'", '"') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

function Convert-ToClaudeAgentName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFileName,
        [string]$DeclaredName
    )

    $candidate = if ([string]::IsNullOrWhiteSpace($DeclaredName)) {
        $SourceFileName -replace '\.agent\.md$', '' -replace '\.md$', ''
    } else {
        $DeclaredName
    }

    $candidate = $candidate.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    $candidate = $candidate.Trim('-')

    if ([string]::IsNullOrWhiteSpace($candidate)) {
        throw "Unable to derive Claude agent name from '$SourceFileName'."
    }

    return $candidate
}

function Convert-ToClaudeTools {
    param(
        [string[]]$Tools
    )

    if ($null -eq $Tools -or $Tools.Count -eq 0) {
        return @()
    }

    $safeMap = @{
        'read'      = 'Read'
        'glob'      = 'Glob'
        'grep'      = 'Grep'
        'bash'      = 'Bash'
        'edit'      = 'Edit'
        'write'     = 'Write'
        'multiedit' = 'MultiEdit'
        'webfetch'  = 'WebFetch'
        'websearch' = 'WebSearch'
    }

    $mapped = New-Object System.Collections.Generic.List[string]
    foreach ($tool in $Tools) {
        $key = $tool.ToLowerInvariant()
        if (-not $safeMap.ContainsKey($key)) {
            return @()
        }
        $mapped.Add($safeMap[$key])
    }

    return @($mapped)
}

function Write-ClaudeAgentFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputDir
    )

    $parsed = Get-FrontMatterAndBody -Path $SourcePath
    if ($null -eq $parsed) {
        return $null
    }

    $sourceFileName = [System.IO.Path]::GetFileName($SourcePath)
    if ($sourceFileName -eq 'copilot-instructions.md') {
        return $null
    }

    $declaredName = Get-FrontMatterValue -FrontMatter $parsed.FrontMatter -Key 'name'
    $description = Get-FrontMatterValue -FrontMatter $parsed.FrontMatter -Key 'description'
    $model = Get-FrontMatterValue -FrontMatter $parsed.FrontMatter -Key 'model'
    $color = Get-FrontMatterValue -FrontMatter $parsed.FrontMatter -Key 'color'
    $tools = Convert-ToClaudeTools -Tools (Get-FrontMatterListValue -FrontMatter $parsed.FrontMatter -Key 'tools')
    $name = Convert-ToClaudeAgentName -SourceFileName $sourceFileName -DeclaredName $declaredName

    if ([string]::IsNullOrWhiteSpace($description)) {
        $description = "Shared Claude subagent seeded from .github/agents/$sourceFileName."
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('---')
    $lines.Add("name: $name")
    $lines.Add(("description: ""{0}""" -f $description.Replace("""", "\""")))
    if ($tools.Count -gt 0) {
        $lines.Add(("tools: {0}" -f ($tools -join ', ')))
    }
    if (-not [string]::IsNullOrWhiteSpace($model)) {
        $lines.Add("model: $model")
    }
    if (-not [string]::IsNullOrWhiteSpace($color)) {
        $lines.Add("color: $color")
    }
    $lines.Add('---')
    $lines.Add('')
    $lines.Add(("<!-- Seeded from .github/agents/{0} via studio/scripts/powershell/seed-claude-agents.ps1. The workspace root /.claude/agents directory is the Claude shared runtime authority after generation. -->" -f $sourceFileName))
    $lines.Add(("<!-- WARNING: This file is a seeded copy from .github/agents/{0}. Direct edits will be overwritten on the next seed-claude-agents.ps1 run. To make permanent changes, edit the source file and re-seed. -->" -f $sourceFileName))
    if ($parsed.Body.Count -gt 0) {
        foreach ($bodyLine in $parsed.Body) {
            $lines.Add([string]$bodyLine)
        }
    }

    $outputPath = Join-Path $OutputDir "$name.md"
    $content = ($lines -join "`n") + "`n"
    [System.IO.File]::WriteAllText($outputPath, $content, $Utf8NoBom)

    return [ordered]@{
        name       = $name
        sourceFile = $sourceFileName
        outputPath = ($outputPath -replace '\\', '/')
    }
}

$generated = @()
$skipped = @()
Get-ChildItem -LiteralPath $sourceDir -File -Filter '*.md' |
    Sort-Object Name |
    ForEach-Object {
        $result = Write-ClaudeAgentFile -SourcePath $_.FullName -OutputDir $outputDir
        if ($null -ne $result) {
            $generated += $result
        } else {
            $skipped += $_.Name
        }
    }

$result = [ordered]@{
    workspaceRoot = $resolvedWorkspaceRoot
    sourceDir     = $sourceDir
    outputDir     = $outputDir
    generated     = @($generated)
    skipped       = @($skipped)
    count         = $generated.Count
    skippedCount  = $skipped.Count
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 6
    exit 0
}

Write-Output ("Seeded {0} Claude shared agents in {1}" -f $generated.Count, $outputDir)
$generated | ForEach-Object {
    Write-Output ("- {0} <= {1}" -f $_.name, $_.sourceFile)
}
