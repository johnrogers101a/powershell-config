# Force reload ProfileSetup module to ensure latest code
if (Get-Module -Name ProfileSetup) {
    Remove-Module -Name ProfileSetup -Force
}
Import-Module $PSScriptRoot/Modules/ProfileSetup -Force
Initialize-PowerShellProfile