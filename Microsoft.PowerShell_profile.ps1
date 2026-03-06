# Initialize PowerShell profile using script-based architecture
# No module caching issues - scripts are always fresh

# Ensure Homebrew is on PATH (needed when launched directly, e.g. as login shell)
$brewPaths = @(
    "/home/linuxbrew/.linuxbrew/bin",
    "/home/linuxbrew/.linuxbrew/sbin",
    "/opt/homebrew/bin",
    "/usr/local/bin"
)
foreach ($p in $brewPaths) {
    if ((Test-Path $p) -and ($env:PATH -notlike "*$p*")) {
        $env:PATH = "${p}:$env:PATH"
    }
}

$initScript = Join-Path $PSScriptRoot "Scripts/Profile/Initialize-PowerShellProfile.ps1"
. $initScript