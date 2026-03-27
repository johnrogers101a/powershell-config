#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Launches Jarvis agent via Claude Code or GitHub Copilot CLI.

.DESCRIPTION
    Starts Claude Code (default) or GitHub Copilot CLI with the Jarvis agent,
    auto-approve permissions, and low reasoning effort.

.PARAMETER Copilot
    Use GitHub Copilot CLI instead of Claude Code.

.PARAMETER NoYolo
    Prompt for permissions instead of auto-approving.

.EXAMPLE
    Invoke-Jarvis
    Invoke-Jarvis -Copilot
    Invoke-Jarvis -NoYolo
#>

[CmdletBinding()]
param(
    [switch]$Copilot,
    [switch]$NoYolo,
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Remaining
)

if ($Copilot) {
    if ($NoYolo) {
        & copilot --agent Jarvis --reasoning-effort low @Remaining
    } else {
        & copilot --agent Jarvis --yolo --reasoning-effort low @Remaining
    }
} else {
    if ($NoYolo) {
        & claude --agent Jarvis --effort low @Remaining
    } else {
        & claude --agent Jarvis --dangerously-skip-permissions --effort low @Remaining
    }
}
