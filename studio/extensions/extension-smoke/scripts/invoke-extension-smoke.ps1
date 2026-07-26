#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param()

$result = [ordered]@{
    extension = 'extension-smoke'
    status    = 'ok'
    checkedAt = (Get-Date).ToString('o')
}

[PSCustomObject]$result | ConvertTo-Json -Depth 3
