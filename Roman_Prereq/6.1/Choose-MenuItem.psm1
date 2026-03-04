function Choose-MenuItem {
<#
.SYNOPSIS
Create a menu from an input list, then capture the user's selection.
 
.DESCRIPTION
This script should be dot sourced into your code and used as a function (Choose-MenuItem). It will return the string of the chosen item.
The item "Cancel" will always be added to the end of the list.

.NOTES
    Script: Choose-MenuItem.ps1
    Author: Roman Revell
    Requirements: PowerShell 5.1 (developed on 7.4.4)

    History:
    version 2.0.1   2024-10-14 Fix up the comment section a little.
    version 2       2024-10-12 Add the functionality from the original Login-AWS Show-Menu function which saves the most recent selection to the registry to make it come up next time.
    version 1       2024-09-02

.PARAMETER MenuItems
List of items that should appear in the menu. "Cancel" will always be added to the end.

.PARAMETER PromptMessage
A prompt to tell the user what the menu is or whatever explanation you want.

.PARAMETER MenuTitle
Title appearing just above the list of items that are the menu.

.EXAMPLE 
Choose-MenuItem -MenuItems $AccountProfileList -PromptMessage "Choose an account profile" -MenuTitle "profiles" -RegisteredApp "Login-Account"
#>
    param (
        [parameter(mandatory)][array]
        $MenuItems,
        [string]$PromptMessage,
        [string]$MenuTitle = "Choose item",
        [int]$DefaultMenuItem, # zero based index. Default is 0.
        [string]$RegisteredApp # This is the name that will be used in the registry to record the last menu item selected so that it will come up by default (unless overridden by $DefaultMenuItem)
    )

    # initialize
    #region Registry
    # If the application this menu system is being used for is specified, then get or set the default menu item. This allows for getting the same item as was last selected.
    If ($RegisteredApp) {
        # First make sure this registry key exists because we will be trying to write to it later anyway.
        if (! (test-path hkcu:\software\RomanRevell\Menu\$RegisteredApp\)) {
            New-Item hkcu:\software\RomanRevell\ | Out-Null
            New-Item hkcu:\software\RomanRevell\Menu\ | Out-Null
            New-Item hkcu:\software\RomanRevell\Menu\$RegisteredApp\ | Out-Null
            New-ItemProperty -Path hkcu:\software\RomanRevell\Menu\$RegisteredApp\ -Name DefaultMenuItem -PropertyType dword -Value 0 | Out-Null
        }
        # Registry key does exist already.
        else {
            # If default menu item was not specified, then get or create it.
            if (! $DefaultMenuItem) {
                try { $DefaultMenuItem = (Get-ItemProperty -path hkcu:\software\RomanRevell\Menu\$RegisteredApp\ -Name DefaultMenuItem -ErrorAction Stop ).DefaultMenuItem }
                catch {
                    New-ItemProperty -Path hkcu:\software\RomanRevell\Menu\$RegisteredApp\ -Name DefaultMenuItem -PropertyType dword -Value 0
                    $DefaultMenuItem = 0
                }
            }
        }
    }
    #endregion Registry
    # Caller does not want to register an app name to keep track of last menu item. So, if a default item also was not specified, then just set it to the first item.
    else {
        if (! $DefaultMenuItem) {
            $DefaultMenuItem = 0
        }
    }

    $MenuItems += "Cancel"
    $MenuItemCount = $MenuItems.Count
    # If the menu got changed since the last time the script was run and the DefaultMenuItem from the registry is larger than the number of items, that's not going to work. So, just reset it.
    if ($DefaultMenuItem -gt $MenuItemCount) {
        $DefaultMenuItem = 0
    }

    # Main
    Write-Host "$PromptMessage" -ForegroundColor Blue
    $KeyPressed = $null
    Write-Host "======== $MenuTitle ======== Hit enter to select ========"
    $cursorPos = $host.UI.RawUI.CursorPosition
    # 'enter' key = code 13
    # The default menu item is really the current menu item within the loop
    $CurrentMenuItem = $DefaultMenuItem
    while ($KeyPressed -ne '13') {
        $host.UI.RawUI.CursorPosition = $cursorPos
        for ($i = 0; $i -lt $MenuItemCount; $i++) {
            if ($i -eq $CurrentMenuItem) {
                Write-Host "$($MenuItems[$i])" -ForegroundColor Green
            }
            else {
                Write-Host "$($MenuItems[$i])"
            }
        }
        $KeyPressed = $host.ui.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode
        switch ($KeyPressed) {
            38 {
                # Up arrow
                if ($CurrentMenuItem -gt 0) {
                    $CurrentMenuItem--
                }
                # Wrap around
                elseif ($CurrentMenuItem -eq 0) {
                    $CurrentMenuItem = $MenuItemCount - 1 # change it to the last item in the list, and account for the $CurrentMenuItem being zero based, while $MenuItemCount is one based.
                }
            }
            40 {
                # Down arrow
                if ($CurrentMenuItem -lt ($MenuItemCount - 1)) {
                    $CurrentMenuItem++
                }
                # Wrap around
                elseif ($CurrentMenuItem -eq $MenuItemCount - 1) {
                    $CurrentMenuItem = 0
                }
            }
            13 {
                # enter key
                If ($RegisteredApp) {
                    Set-ItemProperty -Path hkcu:\software\RomanRevell\Menu\$RegisteredApp\ -Name DefaultMenuItem -Value $CurrentMenuItem
                }
                return $MenuItems[$CurrentMenuItem]
            }
        }
        # Move the cursor up to overwrite the menu with a different item highlighted
        $cursorPos = $host.UI.RawUI.CursorPosition
        $cursorPos.Y -= $MenuItemCount
    }
    Write-Host "You selected " -NoNewline
    Write-Host "$($MenuItems[$SelectedIndex])" -ForegroundColor Green
    $MenuItems[$SelectedIndex]
}