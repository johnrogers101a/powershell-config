# Plan: Add -No-Install Parameter to install.ps1

## Problem Statement
Add a `-No-Install` switch parameter to `install.ps1` that skips software installation, Windows Updates, Store Updates, and Visual Studio installation while still installing profile files, fonts, and performing other configuration.

## Proposed Approach
Add a simple switch parameter with minimal changes to the existing script flow.

## Current Behavior (lines affected)
1. **Line 113-114**: Software installation via `Install-Software.ps1`
2. **Line 121-122**: Windows Updates via `Install-WindowsUpdates.ps1`
3. **Line 135-136**: Visual Studio installation via `Install-VisualStudio.ps1`

## Changes Required

### Task 1: Add parameter block
- [ ] Add `-No-Install` switch parameter to the `param()` block (line 23)
- [ ] Update `.SYNOPSIS` documentation to describe the new parameter

### Task 2: Conditionally skip software installation
- [ ] Wrap software installation call (lines 113-114) in `if (-not ${No-Install})` block

### Task 3: Conditionally skip Windows Updates
- [ ] Wrap Windows Updates call (lines 121-122) in `if (-not ${No-Install})` block

### Task 4: Conditionally skip Visual Studio installation
- [ ] Wrap Visual Studio installation call (lines 135-136) in `if (-not ${No-Install})` block

### Task 5: Add informational output
- [ ] Display installation mode in header (Full vs Profile-Only)
- [ ] Show skip messages when `-No-Install` is used

## Usage After Implementation

```powershell
# Full installation (default behavior)
./install.ps1

# Profile-only installation (skip software, updates, and Visual Studio)
./install.ps1 -No-Install
```

## What Will Still Run with -No-Install
- ✅ Font installation (needed for terminal theming)
- ✅ Time zone configuration (Windows)
- ✅ Windows Terminal configuration (Windows)
- ✅ Profile file installation
- ✅ Profile loading

## What Will Be Skipped with -No-Install
- ❌ Software installation (winget/brew packages)
- ❌ Windows Updates
- ❌ Microsoft Store Updates
- ❌ Visual Studio installation

## Notes
- Fonts are lightweight and needed for the profile to display correctly
- Changes are minimal and don't affect existing behavior when parameter is not used
