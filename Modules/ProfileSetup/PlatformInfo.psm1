class PlatformInfo {
    [string]$OS
    [bool]$IsWindows
    [bool]$IsMacOS

    PlatformInfo() {
        $this.IsWindows = (-not (Test-Path variable:global:IsWindows)) -or $global:IsWindows
        $this.IsMacOS = (Test-Path variable:global:IsMacOS) -and $global:IsMacOS
        
        if ($this.IsWindows) {
            $this.OS = "windows"
        }
        elseif ($this.IsMacOS) {
            $this.OS = "macos"
        }
        else {
            throw "Unsupported operating system. This installer only supports Windows and macOS."
        }
    }
}

Export-ModuleMember -Variable * -Function *
