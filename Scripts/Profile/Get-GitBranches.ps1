#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Retrieves all git branches (local and remote) with optional filtering.

.DESCRIPTION
    Gets local branches and remote branches (strips origin/ prefix).
    Returns unique sorted list. Supports wildcard filtering.
    Safe to use in non-git directories (returns empty).

.PARAMETER Filter
    Optional wildcard pattern to filter branch names (default: '*' for all)

.EXAMPLE
    $branches = & "$PSScriptRoot/Get-GitBranches.ps1"
    $branches = & "$PSScriptRoot/Get-GitBranches.ps1" -Filter "feature/*"

.OUTPUTS
    Array of branch name strings
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Filter = '*'
)

$ErrorActionPreference = 'SilentlyContinue'

$branches = @()

# Get local branches
$localBranches = git branch --format='%(refname:short)' 2>&1 | Where-Object { $_ -is [string] }
if ($localBranches) {
    $branches += $localBranches | ForEach-Object { $_.Trim() }
}

# Get remote branches (strip origin/ prefix)
$remoteBranches = git branch -r --format='%(refname:short)' 2>&1 | 
    Where-Object { $_ -is [string] -and $_ -notmatch 'HEAD' } |
    ForEach-Object { $_ -replace '^origin/', '' }

if ($remoteBranches) {
    $branches += $remoteBranches
}

# Return unique branches matching filter
$branches | Select-Object -Unique | Where-Object { $_ -like $Filter }
