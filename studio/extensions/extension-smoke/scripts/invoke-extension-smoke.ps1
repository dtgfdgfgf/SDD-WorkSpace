#!/usr/bin/env pwsh

[CmdletBinding()]
param()

$result = [ordered]@{
    extension = 'extension-smoke'
    status    = 'ok'
    checkedAt = (Get-Date).ToString('o')
}

[PSCustomObject]$result | ConvertTo-Json -Depth 3
