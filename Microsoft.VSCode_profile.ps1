# Initialize PowerShell profile using script-based architecture
# No module caching issues - scripts are always fresh
$initScript = Join-Path $PSScriptRoot "Scripts/Profile/Initialize-PowerShellProfile.ps1"
. $initScript