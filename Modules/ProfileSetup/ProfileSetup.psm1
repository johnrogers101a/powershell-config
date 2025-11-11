#region Module Management
function Install-ModuleIfMissing {
    <#
    .SYNOPSIS
    Installs and imports a PowerShell module if it's not already available
    
    .PARAMETER ModuleName
    The name of the module to install
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )
    
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Install-Module $ModuleName -Scope CurrentUser -Force
    }
    Import-Module $ModuleName
}
#endregion

#region Git Branch Management
function Get-GitBranches {
    <#
    .SYNOPSIS
    Retrieves all git branches (local and remote)
    
    .PARAMETER Filter
    Filter pattern for branch names
    #>
    param(
        [string]$Filter = '*'
    )
    
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
}

function New-BranchCompletionResult {
    <#
    .SYNOPSIS
    Creates a completion result for a git branch name
    
    .PARAMETER BranchName
    The branch name to create a completion result for
    #>
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$BranchName
    )
    
    process {
        [System.Management.Automation.CompletionResult]::new(
            $BranchName, 
            $BranchName, 
            'ParameterValue', 
            $BranchName
        )
    }
}

function Test-GitSwitchCommand {
    <#
    .SYNOPSIS
    Tests if a command line is a git switch or checkout command
    
    .PARAMETER CommandLine
    The command line to test
    #>
    param(
        [string]$CommandLine
    )
    
    $CommandLine -match '^\s*git\s+(switch|checkout)\s'
}
#endregion

#region Startup Location
function Set-DefaultWorkingDirectory {
    <#
    .SYNOPSIS
    Sets the working directory to a default path if currently in home directory
    
    .PARAMETER DefaultPath
    The default path to navigate to
    #>
    param(
        [string]$DefaultPath = '~/code'
    )
    
    if ((Get-Location).Path -eq $HOME) {
        Set-Location -Path $DefaultPath
    }
}
#endregion

#region Profile Initialization
function Initialize-PowerShellProfile {
    <#
    .SYNOPSIS
    Initializes the PowerShell profile with all custom settings
    
    .DESCRIPTION
    Sets up:
    - Required modules (Terminal-Icons, posh-git)
    - PSReadLine configuration
    - Git branch completion
    - oh-my-posh prompt
    - Default working directory
    - ~/bin in PATH for git extensions
    
    .PARAMETER OhMyPoshConfig
    Path to oh-my-posh config file (default: omp.json in the config folder)
    
    .PARAMETER DefaultWorkingDirectory
    Default working directory to navigate to (default: ~/code)
    
    .EXAMPLE
    Initialize-PowerShellProfile
    
    .EXAMPLE
    Initialize-PowerShellProfile -OhMyPoshConfig '~/custom-omp.json' -DefaultWorkingDirectory '~/projects'
    #>
    param(
        [string]$OhMyPoshConfig = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'omp.json'),
        [string]$DefaultWorkingDirectory = '~/code'
    )
    
    # Add ~/bin to PATH for git extensions
    $binPath = Join-Path $HOME "bin"
    if ((Test-Path $binPath) -and ($env:PATH -notlike "*$binPath*")) {
        $env:PATH = $binPath + [IO.Path]::PathSeparator + $env:PATH
    }
    
    # Install required modules
    Install-ModuleIfMissing -ModuleName 'Terminal-Icons'
    Install-ModuleIfMissing -ModuleName 'posh-git'
    
    # Configure PSReadLine for better tab completion
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    
    # Initialize oh-my-posh
    if (Test-Path $OhMyPoshConfig) {
        oh-my-posh init pwsh --config $OhMyPoshConfig | Invoke-Expression
    }
    
    # Set default working directory
    Set-DefaultWorkingDirectory -DefaultPath $DefaultWorkingDirectory
}
#endregion

# Export functions
Export-ModuleMember -Function @(
    'Install-ModuleIfMissing',
    'Get-GitBranches',
    'New-BranchCompletionResult',
    'Test-GitSwitchCommand',
    'Set-DefaultWorkingDirectory',
    'Initialize-PowerShellProfile'
)
