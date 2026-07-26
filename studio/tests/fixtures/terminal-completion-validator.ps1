#!/usr/bin/env pwsh

#Requires -Version 7.0
param(
    [ValidateSet('ready', 'empty', 'malformed', 'nonboolean', 'nonzero')]
    [string]$Mode = 'ready'
)

switch ($Mode) {
    'ready'      { '{"READY":true,"BLOCKERS":[]}' }
    'empty'      { }
    'malformed'  { 'not-json' }
    'nonboolean' { '{"READY":"true","BLOCKERS":[]}' }
    'nonzero'    { '{"READY":true,"BLOCKERS":[]}'; exit 9 }
}
