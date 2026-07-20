#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [switch]$Verify,
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

function Get-FrontMatterAndBody {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $lines = [System.IO.File]::ReadAllLines($Path, $Utf8NoBom)
    if ($lines.Count -lt 3 -or $lines[0] -ne '---') {
        $exception = [System.InvalidOperationException]::new(
            "Frontmatter missing or malformed in '$Path' (no leading '---' delimiter)."
        )
        $exception.Data['SeedErrorId'] = 'source-frontmatter-invalid'
        $exception.Data['SeedErrorPath'] = $Path
        throw $exception
    }

    $endIndex = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq '---') {
            $endIndex = $i
            break
        }
    }

    if ($endIndex -lt 0) {
        $exception = [System.InvalidOperationException]::new(
            "Frontmatter missing closing '---' delimiter in '$Path'."
        )
        $exception.Data['SeedErrorId'] = 'source-frontmatter-invalid'
        $exception.Data['SeedErrorPath'] = $Path
        throw $exception
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
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$SourceFileName
    )

    $raw = Get-FrontMatterValue -FrontMatter $FrontMatter -Key $Key
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    $usesBrackets = $raw.StartsWith('[') -or $raw.EndsWith(']') -or $raw.Contains('[') -or $raw.Contains(']')
    if ($usesBrackets -and (-not $raw.StartsWith('[') -or -not $raw.EndsWith(']'))) {
        $exception = [System.InvalidOperationException]::new(
            "Malformed '$Key' list in '$SourceFileName': brackets must be balanced and enclose the complete value."
        )
        $exception.Data['SeedErrorId'] = 'frontmatter-list-invalid'
        $exception.Data['SeedErrorPath'] = $SourceFileName
        throw $exception
    }

    $listBody = if ($usesBrackets) {
        $raw.Substring(1, $raw.Length - 2).Trim()
    } else {
        $raw
    }
    if ([string]::IsNullOrWhiteSpace($listBody)) {
        return @()
    }

    $values = New-Object System.Collections.Generic.List[string]
    foreach ($rawToken in $listBody.Split(',')) {
        $token = $rawToken.Trim()
        $value = $null
        if ($token -match "^'([^']+)'$") {
            $value = $Matches[1]
        } elseif ($token -match '^"([^"]+)"$') {
            $value = $Matches[1]
        } elseif ($token -match '^[A-Za-z][A-Za-z0-9-]*$') {
            $value = $token
        }

        if (
            [string]::IsNullOrWhiteSpace($value) -or
            $value -notmatch '^[A-Za-z][A-Za-z0-9-]*$'
        ) {
            $exception = [System.InvalidOperationException]::new(
                "Malformed '$Key' list token '$token' in '$SourceFileName'; list values must be complete tool identifiers."
            )
            $exception.Data['SeedErrorId'] = 'frontmatter-list-invalid'
            $exception.Data['SeedErrorPath'] = $SourceFileName
            throw $exception
        }

        $values.Add($value)
    }

    return @($values)
}

function Test-FrontMatterKey {
    param(
        [AllowEmptyCollection()]
        [string[]]$FrontMatter,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    foreach ($line in $FrontMatter) {
        if ($line -match ("^{0}:\s*" -f [Regex]::Escape($Key))) {
            return $true
        }
    }

    return $false
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
        [string[]]$Tools,
        [string[]]$ExplicitClaudeTools,
        [Parameter(Mandatory = $true)]
        [string]$SourceFileName
    )

    $sourceTools = @($Tools | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $explicitTools = @($ExplicitClaudeTools | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })

    if ($sourceTools.Count -eq 0 -and $explicitTools.Count -gt 0) {
        $exception = [System.InvalidOperationException]::new(
            "Source '$SourceFileName' declares claude-tools without source tools; refusing to grant Claude-only permissions."
        )
        $exception.Data['SeedErrorId'] = 'claude-tools-permission-broadening'
        $exception.Data['SeedErrorPath'] = $SourceFileName
        throw $exception
    }

    if ($sourceTools.Count -eq 0) {
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

    if ($explicitTools.Count -gt 0) {
        $approvedNonPortableToolMap = @{
            'changes'           = @('Read')
            'extensions'        = @('Read')
            'fetch'             = @('WebFetch')
            'githubrepo'        = @('WebFetch')
            'new'               = @('Write')
            'opensimplebrowser' = @('WebFetch')
            'problems'          = @('Read')
            'runcommands'       = @('Bash')
            'runnotebooks'      = @('Bash')
            'runsubagent'       = @()
            'runtasks'          = @('Bash')
            'search'            = @('Read', 'Glob', 'Grep')
            'testfailure'       = @('Read')
            'todos'             = @('Read')
            'usages'            = @('Read', 'Grep')
            'vscodeapi'         = @('Read')
        }
        $approvedExplicitTools = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        foreach ($sourceTool in $sourceTools) {
            $sourceKey = ([string]$sourceTool).Trim().ToLowerInvariant()
            if ($safeMap.ContainsKey($sourceKey)) {
                [void]$approvedExplicitTools.Add([string]$safeMap[$sourceKey])
                continue
            }
            if (-not $approvedNonPortableToolMap.ContainsKey($sourceKey)) {
                $exception = [System.InvalidOperationException]::new(
                    "Unsupported Copilot tool '$sourceTool' in '$SourceFileName'; an explicit claude-tools field cannot mask an unknown source permission."
                )
                $exception.Data['SeedErrorId'] = 'unsupported-tool-mapping'
                $exception.Data['SeedErrorPath'] = $SourceFileName
                throw $exception
            }
            foreach ($approvedTool in @($approvedNonPortableToolMap[$sourceKey])) {
                [void]$approvedExplicitTools.Add([string]$approvedTool)
            }
        }

        $allowedClaudeTools = @{}
        foreach ($allowedTool in @($safeMap.Values | Sort-Object -Unique)) {
            $allowedClaudeTools[[string]$allowedTool.ToLowerInvariant()] = [string]$allowedTool
        }

        $mappedExplicit = New-Object System.Collections.Generic.List[string]
        foreach ($tool in $explicitTools) {
            $key = ([string]$tool).Trim().ToLowerInvariant()
            if (-not $allowedClaudeTools.ContainsKey($key)) {
                $exception = [System.InvalidOperationException]::new(
                    "Unsupported explicit Claude tool '$tool' in '$SourceFileName'; refusing to seed Claude agents."
                )
                $exception.Data['SeedErrorId'] = 'unsupported-claude-tool'
                $exception.Data['SeedErrorPath'] = $SourceFileName
                throw $exception
            }
            $canonicalTool = [string]$allowedClaudeTools[$key]
            if (-not $approvedExplicitTools.Contains($canonicalTool)) {
                $exception = [System.InvalidOperationException]::new(
                    "Explicit Claude tool '$canonicalTool' in '$SourceFileName' exceeds the permissions approved by its source tool mappings."
                )
                $exception.Data['SeedErrorId'] = 'explicit-tool-permission-broadening'
                $exception.Data['SeedErrorPath'] = $SourceFileName
                throw $exception
            }
            if (-not $mappedExplicit.Contains($canonicalTool)) {
                $mappedExplicit.Add($canonicalTool)
            }
        }

        return @($mappedExplicit)
    }

    $mapped = New-Object System.Collections.Generic.List[string]
    foreach ($tool in $sourceTools) {
        $key = ([string]$tool).Trim().ToLowerInvariant()
        if (-not $safeMap.ContainsKey($key)) {
            $exception = [System.InvalidOperationException]::new(
                "Unsupported Copilot tool '$tool' in '$SourceFileName'; add an explicit, least-privilege claude-tools mapping or remove the tool before seeding."
            )
            $exception.Data['SeedErrorId'] = 'unsupported-tool-mapping'
            $exception.Data['SeedErrorPath'] = $SourceFileName
            throw $exception
        }
        if (-not $mapped.Contains($safeMap[$key])) {
            $mapped.Add($safeMap[$key])
        }
    }

    return @($mapped)
}

function Convert-ToNormalizedAgentText {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return ''
    }

    $normalized = $Text -replace "^\uFEFF", ''
    $normalized = $normalized -replace "`r`n?", "`n"
    return $normalized.TrimEnd([char[]]@("`n")) + "`n"
}

function New-ClaudeAgentRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputDir
    )

    $parsed = Get-FrontMatterAndBody -Path $SourcePath
    $sourceFileName = [System.IO.Path]::GetFileName($SourcePath)
    $declaredName = Get-FrontMatterValue -FrontMatter $parsed.FrontMatter -Key 'name'
    $description = Get-FrontMatterValue -FrontMatter $parsed.FrontMatter -Key 'description'
    $model = Get-FrontMatterValue -FrontMatter $parsed.FrontMatter -Key 'model'
    $color = Get-FrontMatterValue -FrontMatter $parsed.FrontMatter -Key 'color'
    $sourceToolsDeclared = Test-FrontMatterKey -FrontMatter $parsed.FrontMatter -Key 'tools'
    $sourceTools = @(
        Get-FrontMatterListValue `
            -FrontMatter $parsed.FrontMatter `
            -Key 'tools' `
            -SourceFileName $sourceFileName
    )
    $explicitClaudeTools = @(
        Get-FrontMatterListValue `
            -FrontMatter $parsed.FrontMatter `
            -Key 'claude-tools' `
            -SourceFileName $sourceFileName
    )
    $tools = @(
        Convert-ToClaudeTools `
            -Tools $sourceTools `
            -ExplicitClaudeTools $explicitClaudeTools `
            -SourceFileName $sourceFileName
    )
    $name = Convert-ToClaudeAgentName -SourceFileName $sourceFileName -DeclaredName $declaredName

    if ([string]::IsNullOrWhiteSpace($description)) {
        $description = "Shared Claude subagent seeded from .github/agents/$sourceFileName."
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('---')
    $lines.Add("name: $name")
    $lines.Add(("description: ""{0}""" -f $description.Replace("""", "\""")))
    if ($sourceToolsDeclared) {
        if ($tools.Count -gt 0) {
            $lines.Add(("tools: {0}" -f ($tools -join ', ')))
        } else {
            $lines.Add('tools: []')
        }
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

    return [PSCustomObject]@{
        Name       = $name
        SourceFile = $sourceFileName
        OutputPath = $outputPath
        Content    = $content
    }
}

function Get-PublicClaudeAgentRecord {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Record
    )

    return [ordered]@{
        name       = [string]$Record.Name
        sourceFile = [string]$Record.SourceFile
        outputPath = ([string]$Record.OutputPath -replace '\\', '/')
    }
}

function Add-SeedError {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Errors,
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Path
    )

    $Errors.Add([ordered]@{
        id      = $Id
        message = $Message
        path    = $Path
    })
}

function Test-ClaudeAgentParity {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Records,
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Errors
    )

    if (-not (Test-Path -LiteralPath $OutputDir -PathType Container)) {
        Add-SeedError -Errors $Errors -Id 'claude-agent-output-directory-missing' -Message 'Claude shared agent output directory is missing.' -Path $OutputDir
        return
    }

    $expectedByRelativePath = @{}
    foreach ($record in $Records) {
        $fileName = [System.IO.Path]::GetFileName([string]$record.OutputPath)
        $expectedByRelativePath[$fileName] = $record
    }

    $actualEntries = @(
        Get-ChildItem -LiteralPath $OutputDir -Force -Recurse |
            Sort-Object FullName
    )
    $actualFiles = @($actualEntries | Where-Object { -not $_.PSIsContainer })
    $actualDirectories = @($actualEntries | Where-Object { $_.PSIsContainer })

    foreach ($fileName in @($expectedByRelativePath.Keys | Sort-Object)) {
        $record = $expectedByRelativePath[$fileName]
        if (-not (Test-Path -LiteralPath $record.OutputPath -PathType Leaf)) {
            Add-SeedError -Errors $Errors -Id 'claude-agent-mirror-missing' -Message "Generated Claude agent mirror is missing for source '$($record.SourceFile)'." -Path $record.OutputPath
            continue
        }

        $actualText = [System.IO.File]::ReadAllText([string]$record.OutputPath)
        $expectedNormalized = Convert-ToNormalizedAgentText -Text ([string]$record.Content)
        $actualNormalized = Convert-ToNormalizedAgentText -Text $actualText
        if (-not $actualNormalized.Equals($expectedNormalized, [System.StringComparison]::Ordinal)) {
            Add-SeedError -Errors $Errors -Id 'claude-agent-content-drift' -Message "Claude agent mirror differs from deterministic source rendering '$($record.SourceFile)'." -Path $record.OutputPath
        }
    }

    foreach ($actualDirectory in $actualDirectories) {
        Add-SeedError -Errors $Errors -Id 'claude-agent-mirror-unexpected-directory' -Message 'Unexpected directory exists in the flat generated Claude agent authority.' -Path $actualDirectory.FullName
    }

    foreach ($actualFile in $actualFiles) {
        $relativePath = [System.IO.Path]::GetRelativePath($OutputDir, $actualFile.FullName) -replace '\\', '/'
        if (-not $expectedByRelativePath.ContainsKey($relativePath)) {
            Add-SeedError -Errors $Errors -Id 'claude-agent-mirror-unexpected' -Message 'Unexpected file exists in the generated Claude agent authority.' -Path $actualFile.FullName
        }
    }
}

$generated = @()
$skipped = @()
$records = @()
$errors = [System.Collections.Generic.List[object]]::new()

try {
    foreach ($sourceFile in @(Get-ChildItem -LiteralPath $sourceDir -File -Filter '*.md' | Sort-Object Name)) {
        if ($sourceFile.Name -eq 'copilot-instructions.md') {
            $skipped += $sourceFile.Name
            continue
        }
        $records += New-ClaudeAgentRecord -SourcePath $sourceFile.FullName -OutputDir $outputDir
    }

    $duplicateNames = @(
        $records |
            Group-Object Name |
            Where-Object Count -gt 1
    )
    if ($duplicateNames.Count -gt 0) {
        $names = @($duplicateNames | ForEach-Object Name) -join ', '
        $exception = [System.InvalidOperationException]::new(
            "Multiple Copilot sources map to the same Claude agent name: $names"
        )
        $exception.Data['SeedErrorId'] = 'output-name-collision'
        $exception.Data['SeedErrorPath'] = $outputDir
        throw $exception
    }

    if ($Verify) {
        Test-ClaudeAgentParity -Records $records -OutputDir $outputDir -Errors $errors
    } else {
        if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        foreach ($record in $records) {
            [System.IO.File]::WriteAllText([string]$record.OutputPath, [string]$record.Content, $Utf8NoBom)
            $generated += Get-PublicClaudeAgentRecord -Record $record
        }
    }
} catch {
    $errorId = [string]$_.Exception.Data['SeedErrorId']
    if ([string]::IsNullOrWhiteSpace($errorId)) {
        $errorId = 'seed-generation-failed'
    }
    $errorPath = [string]$_.Exception.Data['SeedErrorPath']
    Add-SeedError -Errors $errors -Id $errorId -Message $_.Exception.Message -Path $errorPath
}

$publicRecords = if ($Verify) {
    @($records | ForEach-Object { Get-PublicClaudeAgentRecord -Record $_ })
} else {
    @($generated)
}
$result = [ordered]@{
    VALID         = ($errors.Count -eq 0)
    ERROR_COUNT   = $errors.Count
    MODE          = if ($Verify) { 'verify' } else { 'seed' }
    workspaceRoot = $resolvedWorkspaceRoot
    sourceDir     = $sourceDir
    outputDir     = $outputDir
    generated     = $publicRecords
    skipped       = @($skipped)
    count         = $publicRecords.Count
    skippedCount  = $skipped.Count
    ERRORS        = @($errors)
}
$exitCode = if ($result.VALID) { 0 } else { 1 }

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 8
    exit $exitCode
}

if ($Verify) {
    Write-Output ("Claude shared agent parity valid: {0}" -f $result.VALID.ToString().ToLowerInvariant())
} else {
    Write-Output ("Seeded {0} Claude shared agents in {1}" -f $generated.Count, $outputDir)
    $generated | ForEach-Object {
        Write-Output ("- {0} <= {1}" -f $_.name, $_.sourceFile)
    }
}
if ($errors.Count -gt 0) {
    foreach ($seedError in $errors) {
        [Console]::Error.WriteLine(
            ("ERROR [{0}]: {1} [{2}]" -f $seedError.id, $seedError.message, $seedError.path)
        )
    }
}

exit $exitCode
