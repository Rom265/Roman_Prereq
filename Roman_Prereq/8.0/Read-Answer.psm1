function Read-Answer {
    [Alias("Ask-Question")]
    <#
.SYNOPSIS
Ask a simple yes/no question or a multi-choice question and capture the user's answer/selection.
 
.DESCRIPTION
There are two modes for this function: 
1. simple yes/no question.
In this mode, the message you supply will be followed by: [Y] Yes  [other] No  (enter for default "Yes")
when you do not supply a default or you supply "Yes" for the default. If you supply "No" for the default, then it will look like: [Y] Yes  [other] No  (enter for default "No")
Either way, press the 'Y' key for Yes or any other key (except Enter) for No. The function will return 'True' for Yes and 'False' for No. If you press enter, it will select the default.

Note: This script does not echo the choice, but expects you to write something in response to the input, thus does leave the cursor at the end of the inquiry line. This allows you to create a construct like:
This is a custom script that will make changes to an environment without further prompting. Do you want to continue?  [Y] Yes [N] No  (default is "Y"): Continuing script execution...
If you want the next output to the screen to be on a new line, then you need to add a line with Write-Host or something.

2. multi-choice question.
If you use the -Choices parameter, it will activate multi-choice mode. That mode will display the optional title and message, then provide a list of the choices in the order you supplied (with the first/0 choice being "Cancel/Esc"). The default will be highlighted in green. You can either press the number next to the item or use the arrow keys to move the selection and hit enter to select. Also, if there are multi-digit options, as you press numbers, it will go to the next matching item and wait if it is still ambiguous which one you want, until you either complete typing in the number or hit Enter to select the highlighted item. The index of the selection will be returned--that includes 0 for the automatically added 0/Cancel choice. You may also hit Esc to select the 0/Cancel choice.

To store the choice selected to use as the default next time, see parameter -StoreChoiceIndex.

.NOTES
    Script: Read-Answer.ps1
    Author: Roman Revell, with help from ChatGPT, Copilot
    developed on PowerShell 7.4.13

    History:
    version 2.2  2026-07-15 Fix to make this work with Windows PowerShell 5.1. Saving from PowerShell ISE fixed encoding problem
    version 2.1  2026-03-20 Renamed function (with alias) to avoid using a non-approved verb.
    version 2    2026-02-28 Create a process to handle more than 9 items in multi-choice mode. Clean up some other issues.
    version 1    2026-02-18 Initial version, based on previously created functions Choose-MenuItem and Question-Yes.

.PARAMETER Message
A message to prompt the user for what the choices mean, or whatever explanation you want.

.PARAMETER Default
The default answer to the question.
In yes/no mode: The default is 'Yes' unless you use this parameter and supply the argument "No". Any other entry will show a warning and default to 'Yes'.
In multi-choice mode: The default is 0/Cancel unless you supply an integer that corresponds to one of the choices you supplied. This parameter is overridden by a choice stored by using -StoredChoiceIndex, if a choice has been stored already.

.PARAMETER Choices
List of items that should appear in a multi-choice menu, in the order entered. Supplying an argument for this parameter activates multi-choice mode.
"Cancel" will always be added to the beginning and if selected, returns '0'. Thus, all other choices return 1 through however many choices you enter here.
This does not work with PowerShell ISE.

.PARAMETER Title
Title appearing in blue just above the message (and list of choices if multi-choice mode).

.PARAMETER StoreChoiceIndex
Available in multi-choice mode. If specified, the selected choice will be stored in the registry so that it will be the default the next time the same script calls Ask-Question. This parameter accepts a '1' based index. The index number specifies which call from the calling script you are referring to; so that you can create multiple menus with Ask-Question within the same script. The choice is stored in HKCU:\Software\RomanRevell\Ask-Question\<script file name>\ REG_DWORD: name = <1 based usage index>, value = <default choice index>. Example:
HKCU:\Software\RomanRevell\Ask-Question\Login-AWS.ps1\ REG_DWORD: Name = 1, value = 1
The default for that registry key will be set to "These are default menu choices for this script. See function Ask-Question from Powershell module Roman_Prereq." just to give someone who happens upon this registry key a clue.
This function queries the default variable $MyInvocation to get the script file name that called it. If it determines that it was not called from a script file, this parameter does nothing. This does even work from within a module script. If you use a module function that calls Ask-Question, the $MyInvocation.ScriptName will return that function's .psm1 file name.
A stored choice overrides the parameter -Default, if both are specified.

.EXAMPLE 
Ask-Question "Are you answering Yes to this question?"

Are you answering Yes to this question? [Y] Yes  [other] No  (enter for default "Yes")

.EXAMPLE
Ask-Question "Are you answering Yes to this question?" -Default "No"

Are you answering Yes to this question? [Y] Yes  [other] No  (enter for default "No")

.EXAMPLE
Ask-Question -Title "Choose account profile to login to" -Choices "ok-stage-rrevell","ok-prod-rrevell","ok-proddr-rrevell" -Default 0 -StoreDefault 1

Choose account profile to login to
Use ↑/↓ to navigate, Enter to select, digit(s) to quick select
[0] Cancel/Esc
[1] ok-stage-rrevell
[2] ok-prod-rrevell
[3] ok-proddr-rrevell
#>
    [CmdletBinding()]
    param (
        
        [string]$Message,
        [string]$Default, # Don't worry, when using this with a number, it will be converted to a string, but when used as an integer, it will be coerced back into an integer. So, you can use this for both yes/no and multi-choice modes.
        [array]$Choices,
        [string]$Title
    )
    
    dynamicparam {
        # Only add -StoreChoiceIndex when -Choices is supplied
        if ($PSBoundParameters.ContainsKey('Choices')) {
            $paramName = 'StoreChoiceIndex'

            $attr = New-Object System.Management.Automation.ParameterAttribute
            $attr.HelpMessage = "Which call to Ask-Question is this?"
            $attrs = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $attrs.Add($attr) | Out-Null
            $rdp = New-Object System.Management.Automation.RuntimeDefinedParameter($paramName, [int], $attrs)
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add($paramName, $rdp)
            return $paramDictionary
        }
    }

    Process {
        #region Main initialization
        Set-StrictMode -Version latest
        function LineNumber {
            $MyInvocation.ScriptLineNumber
        }
        #endregion Main initialization

        #region Main header
        if ($Title) {
            Write-Host "$Title" -ForegroundColor Blue
        }
        if ($Message) {
            Write-Host "$Message" -NoNewline
        }
        #endregion Main header
            
        #region multi-choice mode
        if ($Choices) {
           
            function Get-RowCount {
                param(
                    [Parameter(Mandatory)][string]$Text,
                    [Parameter(Mandatory)][int]$Width,
                    [int]$PrefixLen = 0
                )
                if ($Width -le 0) { return 1 }

                $rows = 0
                #Note: '\r?\n' means the carriage return is optional to support both Windows and Unix line endings.
                foreach ($line in ($Text -split '\r?\n')) {
                    $len = $PrefixLen + $line.Length
                    $rows += [Math]::Max(1, [Math]::Ceiling([double]$len / $Width))
                    # Only the first visual row includes the prefix length
                    $PrefixLen = 0
                }
                return $rows
            }

            function Get-MenuHeight {
                ## Computes the total height (in buffer rows) of the menu for the current width.
                $height = 0
                # The instruction line is long enough that it might wrap, so we need to take that in to account when calculating the height of the menu.
                $height += Get-RowCount -Text $instructionLine -Width $host.UI.RawUI.BufferSize.Width -PrefixLen 0
                for ($i = 0; $i -lt $Menu.Count; $i++) {
                    $prefix = "[{0}] " -f $i
                    $height += Get-RowCount -Text $Menu[$i] -Width $host.UI.RawUI.BufferSize.Width -PrefixLen $prefix.Length
                }
                #DEBUG
                if ($DebugPreference) { "line $(LineNumber + 4) Calculated MenuHeight: $height" | Out-File c:\scripts\temp\Ask-Question-debug.txt -Append }

                return $height
            }
            
            #region Choice Initialization
            # Access dynamic parameter values via $PSBoundParameters
            $StoreChoiceIndex = $PSBoundParameters['StoreChoiceIndex']
            
            # Prepare the registry key to store the choice to use as the default next time.
            if ($StoreChoiceIndex) {
                if ($MyInvocation.ScriptName) {
                    # Get the name of the script that called this function.
                    $ScriptName = Split-Path $MyInvocation.ScriptName -Leaf -ErrorAction Stop
                    # Ensure registry key exists for the calling script.
                    if (! (test-path "hkcu:\software\RomanRevell\Ask-Question\$ScriptName")) {
                        # Create the path/key.
                        try {
                            New-Item "hkcu:\software\RomanRevell\Ask-Question\$ScriptName\" -Force | Out-Null
                            New-ItemProperty -Path "hkcu:\software\RomanRevell\Ask-Question\$ScriptName\" -Name "(Default)" -PropertyType string -Value "These are default menu choices for this script. See function Ask-Question from Powershell module Roman_Prereq." | Out-Null
                        }
                        catch {
                            $_
                            Write-Host "Failed to create registry key for script $ScriptName for storing last used menu choice." -ForegroundColor Red
                        }
                    }
                    else {
                        # Path exists, get the stored choice for default.
                        try { $Default = Get-ItemProperty -path "hkcu:\software\RomanRevell\Ask-Question\$ScriptName\" -Name $StoreChoiceIndex -ErrorAction Stop | Select-Object -ExpandProperty "$StoreChoiceIndex" }
                        catch {
                            Write-Host "Failed to get stored default choice from registry for script $ScriptName." -ForegroundColor Yellow
                        }
                    }
                }
            }

            # Coerce the $Default into an integer or set to 0
            if (!$Default) {
                $Default = 0
            }
            else {
                try { [int]$Default = $Default }
                catch {
                    Write-Host  "$($_.Exception.Message) Default will be set to 0/Cancel." -BackgroundColor DarkYellow -ForegroundColor Black -NoNewline
                    # Need this second Write-Host because a bug in Write-Host left the background color on (sort-of)
                    Write-Host
                    $Default = 0
                }
            }

            ## Create the choice menu and get the user's selection. Store the selection in the registry if -StoreChoiceIndex was specified.
            # If the menu got changed since the last time the script was run and the Default from the registry is larger than the number of items, that's not going to work. So, just reset it.
            if ($Default -gt $Choices.Count) {
                $Default = 0
            }

            ## For a menu with greater than 9 choices, we must allow the user to type in multiple digits until the choice is unambiguous, or hit enter to select the currently highlighted item at any time. We should also still be able to use the arrow keys to highlight and hit enter. So, when digits are entered, that should move the hightlight to the corresponding item to prepare for hitting enter, the same as using the arrow keys to highlight the item.                
                
            $Menu = @("Cancel/Esc")
            $Menu += $Choices
            # The default menu item (initially from $Default) is really the current menu item within the loop
            [int]$CurrentMenuItem = $Default

            $maxIndex = $Menu.Count - 1
            $indices = 0..$maxIndex

            if ($Choices.count -le 9) {
                ## We don't want to accept an input that is outside the choices available.
                # $Menu will have count of 1 to 10, indexes 0 to 9
                # key 0 has a code of 48, key 9 has code 57.
                $UpperLimit = 48 + $Choices.count
            }
            else {
                # If there are more than 9 choices input, then we just use key 9 (code 57) as the upper limit because we are watching for digits or 'Enter'.
                $UpperLimit = 57
            }
            $ChoiceMade = $false
            # The numbers will be presented as numbers, but need to be converted to a string so that we can do digit matching. Later they need to be converted back to integers in order to be used as an index into the $Menu array.
            [string]$numBuffer = $null
            
            <# Tutorial on using $host.UI.RawUI.CursorPosition ...
            First, the CursorPosition is the current position of the cursor within the visible window, not the position within text that has been printed since the last screen clear. So, if the text has filled the terminal window already, then the current CursorPosition.Y will be the last line of the terminal window (an integer that is equal to the number of visible lines in the window (minus 1 because it is a zero based coordinate)). To go up, we must set the system variable to a program variable, subtract some number of lines from this variable, and then set the system variable equal to it. We can not modify the X or Y coordinate of the system variable directly (even though Powershell does not give an error if we try); so, we must use an intermediate variable.
            Example: 1. get the CursorPosition with
              $cursorPos = $host.UI.RawUI.CursorPosition
            2. subtract some number of lines with
              $cursorPos.Y -= 1
            Set the CursorPosition by doing
              $host.UI.RawUI.CursorPosition = $cursorPos

            By the way, if the menu that is drawn is taller than the visible window, and thus we can't see the entire menu at once, if we move the current menu item, it tries to set the menu location to a negative Y value above the screen. If you try to set that, it will just be ignored as though you didn't attempt to set the location. So, this script checks for that and sets the Y value to zero instead. You can't change text once it has scrolled out of the Powershell terminal window. But, you can't even tell without scrolling up with the mouse because what is visible still looks the same as the previous draw.
            #>
            #endregion Choice Initialization

            function DrawMenu {
                Write-Host $instructionLine -ForegroundColor Cyan
                for ($i = 0; $i -lt $Menu.count; $i++) {
                    if ($i -eq $CurrentMenuItem) {
                        Write-Host "[$i] $($Menu[$i])" -ForegroundColor Green
                    }
                    else {
                        Write-Host "[$i] $($Menu[$i])"
                    }
                }
            }

            function Wipe-ScreenArea {
                param (
                    $CursorPosition                    
                )
                #DEBUG
                if ($DebugPreference) { "line $(LineNumber + 4) Setting CursorPosition $($CursorPosition.X), $($CursorPosition.Y)" | Out-File c:\scripts\temp\Ask-Question-debug.txt -Append }

                $host.UI.RawUI.CursorPosition = $CursorPosition                
                $blankLine = " " * $host.UI.RawUI.BufferSize.Width
                $heightToClear = $host.UI.RawUI.BufferSize.Height - $CursorPosition.Y
                # Wipe from current position to the end of the visible window (buffer)
                Foreach ($i in 1..$heightToClear) {
                    # It will write the entire width of the window and thus the next write will wrap anyway. And, we want to end without scrolling the screen if we are at the bottom of the window, hence -NoNewLine.
                    Write-Host $blankLine -NoNewline
                }
            }
            
            function Set-CursorPosition {
                $CursorPosition = $host.UI.RawUI.CursorPosition
                $CursorPosition.X = 0
                
                ## 1. If the window size has changed
                if ($host.UI.RawUI.BufferSize -ne $lastBufferSize) {
                    Set-Variable -Name MenuHeight -Value (Get-MenuHeight) -Scope 1

                    ## Go up to the top of the current menu and wipe it, or if that is above the top of the visible window, wipe the whole visible window.
                    if ($MenuHeight -ge $host.UI.RawUI.BufferSize.Height) {
                        # greater than or equal because the cursor is on a line after the end of the menu; so, there is one fewer line available to go up to than the BufferSize.Height .
                        #DEBUG
                        if ($DebugPreference) { "Line $(LineNumber): " + '$MenuHeight -ge $host.UI.RawUI.BufferSize.Height -- setting Y = 0' | Out-File c:\scripts\temp\Ask-Question-debug.txt -Append }

                        $CursorPosition.Y = 0 # Where we want to wipe from and redraw the menu from next time.
                        if ($CursorPosition.Y -lt 0) {
                            #DEBUG
                            if ($DebugPreference) { "line $(LineNumber) CursorPosition.Y is less than 0, setting to 0" | Out-File c:\scripts\temp\Ask-Question-debug.txt -Append }

                            $CursorPosition.Y = 0
                        }
                        Wipe-ScreenArea -CursorPosition $CursorPosition
                    }
                    else {
                        # To go to the position at the top of the current menu
                        #DEBUG
                        if ($DebugPreference) { "Line $(LineNumber): cursor position: $($CursorPosition.Y)" | Out-File c:\scripts\temp\Ask-Question-debug.txt -Append }
                        $CursorPosition.Y -= $MenuHeight
                        if ($CursorPosition.Y -lt 0) {
                            #DEBUG
                            if ($DebugPreference) { "line $(LineNumber) CursorPosition.Y is less than 0, setting to 0" | Out-File c:\scripts\temp\Ask-Question-debug.txt -Append }

                            $CursorPosition.Y = 0
                        }
                        Wipe-ScreenArea -CursorPosition $CursorPosition
                    }
                    Set-Variable -Name lastBufferSize -Value $host.UI.RawUI.BufferSize -Scope 1
                }
                else {
                    # 2. If the window size has not changed
                    if ($MenuHeight -ge $host.UI.RawUI.BufferSize.Height) {
                        # If the menu is taller than the visible window, we can't go up enough to get to the top of the menu, so just go to the top of the visible window and wipe.
                        $CursorPosition.Y = 0
                        Wipe-ScreenArea -CursorPosition $CursorPosition
                    }
                    else {
                        # The screen size has not changed and the menu fits; so, just go up to the top of the menu to redraw it.
                        $CursorPosition.Y -= $MenuHeight
                    }
                }
                #DEBUG
                if ($DebugPreference) { "line $(LineNumber) Setting CursorPosition $($CursorPosition.X), $($CursorPosition.Y)" | Out-File c:\scripts\temp\Ask-Question-debug.txt -Append }

                $host.UI.RawUI.CursorPosition = $CursorPosition
            }

            $instructionLine = "Use ↑/↓ to navigate, Enter to select, digit(s) to quick select"
            Write-Host # Because the $Message was written with -NoNewLine, we need to go to a new line before drawing the menu.
            DrawMenu
            $lastBufferSize = $host.UI.RawUI.BufferSize
            $MenuHeight = Get-MenuHeight # Header and footer plus the number of lines taken up by the menu items with consideration that they might wrap.
            Do {
                While ($true) {
                    try { $KeyPressed = $host.ui.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode }
                    catch [System.Management.Automation.MethodInvocationException] {
                        Write-Host "The method used to get entry `$host.ui.RawUI.ReadKey is not supported by PowerShell ISE. Use PowerShell or Visual Studio Code with PowerShell when using multi-choice mode with Ask-Question." -ForegroundColor Red
                        $_
                        return # Exit the process block and thus the entire Ask-Question function
                    }
                    # Key code 13 = 'Enter', 27 = 'Esc', 38 = up, 40 = down, 48 - 57 = 0 - 9
                    if ( ($KeyPressed -in 13, 27, 38, 40) -or ($KeyPressed -ge 48 -and $KeyPressed -le $UpperLimit) ) {
                        break
                    }
                    # Else continue while loop
                }
                switch ($KeyPressed) {
                    13 {
                        ## Don't redraw the menu as we have the correct current item and just need to return that.
                        # Enter key was pressed. Return current menu item.
                        $ChoiceMade = $true                            
                        break
                    }
                    27 {
                        # Esc key was pressed. Set to 0/Cancel item.
                        [int]$CurrentMenuItem = 0
                        Set-CursorPosition
                        DrawMenu
                        $ChoiceMade = $true
                        break
                    }
                    38 {
                        # Up arrow
                        if ($CurrentMenuItem -gt 0) {
                            $CurrentMenuItem--
                        }
                        # Wrap around
                        elseif ($CurrentMenuItem -eq 0) {
                            [int]$CurrentMenuItem = $Menu.Count - 1 # change it to the last item in the list, and account for the $CurrentMenuItem being zero based, while $Menu.Count is one based.
                        }
                        Set-CursorPosition
                        DrawMenu
                        break
                    }
                    40 {
                        # Down arrow
                        if ($CurrentMenuItem -lt ($Menu.Count - 1)) {
                            $CurrentMenuItem++
                        }
                        # Wrap around
                        elseif ($CurrentMenuItem -eq $Menu.Count - 1) {
                            [int]$CurrentMenuItem = 0
                        }
                        Set-CursorPosition
                        DrawMenu
                        break
                    }
                    default {
                        ## Either select choice based on digit entered (prefix) or move CurrentMenuItem to the first item that matches the digits entered so far and redraw the menu.
                        # Keypressed must be a digit between 0 and 9 inclusive represented by a code between 48 and 57; so, we need to subtract 48 to get the digit.
                        $numBuffer += $KeyPressed - 48

                        ## The number buffer contains index numbers as strings, so we need to convert them to integers before comparing to the menu item indices.
 
                        ## Apply prefix logic after each digit
                        # Get matching indices based on the current buffer. The buffer is converted from a number to a string so that we can do the "StartsWith" comparison to find matches based on the digits entered so far.
                        $matches = @($indices | Where-Object { $_.ToString().StartsWith($numBuffer, $true, [Globalization.CultureInfo]::InvariantCulture) })

                        switch ($matches.Count) {
                            0 {
                                ## This could happen if a user types an ambiguous prefix and then afterward, types a prefix that doesn't match any of the current matching indices. What should we do with that? Just set it to the always unambiguous 0 and start over.
                                # Invalid prefix; clear buffer
                                [string]$numBuffer = $null
                                # We reset to the 0/Cancel item (instead of the default item) so that there will not be any ambiguity of whether or not you have typed something.
                                [int]$CurrentMenuItem = 0
                            }
                            1 {
                                $CurrentMenuItem = $matches[0]

                                # This will make the Do loop end, return the "you selected" message, and return the selected item index to the caller of Ask-Question.
                                $ChoiceMade = $true
                            }
                            default {                    
                                # Ambiguous: move CurrentMenuItem to the first match and wait for more input or Enter
                                $CurrentMenuItem = $matches[0]

                                # $ChoiceMade is still false, so the loop will continue and wait for more input or Enter.
                            }
                        }
                        Set-CursorPosition
                        DrawMenu
                    }
                }
            }
            Until ($ChoiceMade) # If choice was made, then print the selected menu item and return its index.
            If ($StoreChoiceIndex -and (test-path variable:\ScriptName)) {
                Set-ItemProperty -path "hkcu:\software\RomanRevell\Ask-Question\$ScriptName\" -Name $StoreChoiceIndex -Value $CurrentMenuItem
            }
            Write-Host "You selected " -NoNewline
            Write-Host $Menu[$CurrentMenuItem] -ForegroundColor Green
            return $CurrentMenuItem # Return index of selected item to the caller of Ask-Question
        }
        #endregion multi-choice mode

        #region Yes/No mode
        else {
            # This section completed 2026-2-15 3:19PM PST
            function Get-Key {
                if (test-path variable:\psise) {
                    # Method for PowerShell ISE: Requires Enter
                    Do {
                        $text = Read-Host "(type one of those choices and hit enter)"
                    }
                    #Until ($text -eq "Y" -or $text -eq "Yes" -or $text -eq "N" -or $text -eq "No" -or $text.Length -eq 0)
                    Until (($text -in "Y", "Yes", "N", "No") -or $text.Length -eq 0)
                    $text
                }
                else {
                    # Method for Console (v5.1 & 7): Immediate on press and release
                    Do {
                        $key = [Console]::ReadKey($true).Key # note: $true means to "intercept" the key press and thus not display it
                    }
                    Until ($key -in "Y", "N", "Enter")
                    $key
                }
            }
            
            if (!$Default) {
                $Default = "Yes"
            }
            if (!($Default -in "Yes", "No")) {
                Write-Host
                Write-Warning "Invalid default value '$Default' for yes/no question. Default will be set to 'Yes'."
                $Default = "Yes"
            }

            switch ($Default) {
                "No" {
                    write-host " [Y] Yes " -NoNewline
                    write-host '[N] No' -ForegroundColor Yellow -NoNewline
                    write-host ' (default is "' -NoNewline
                    write-host 'N' -ForegroundColor Yellow -NoNewline
                    write-host '"): ' -NoNewline
                }
                "Yes" {
                    write-host " [Y] Yes" -ForegroundColor Yellow -NoNewline
                    write-host ' [N] No  (default is "' -NoNewline
                    write-host 'Y' -ForegroundColor Yellow -NoNewline
                    write-host '"): ' -NoNewline
                }
            }
            
            $KeyPress = Get-Key
            If ($KeyPress.gettype().name -eq "String") {
                # Process input from Powershell ISE
                if ($KeyPress.Length -eq 0) {
                    $Choice = "Enter"    
                }
                else {
                    $Choice = ($KeyPress.Substring(0, 1)).ToUpper()
                }
            }
            else {
                # Process input from Powershell console
                $Choice = $KeyPress
            }

            # Choice will equal Y, N, or Enter...
            if (!$Default -or $Default -eq "Yes") {
                If ($Choice -eq "N") {
                    $false
                    return
                }
                else {
                    $true
                    return
                }
            }
            if ($Default -eq "No") {
                If ($Choice -eq "Y") {
                    $true
                    return
                }
                else {
                    $false
                    return
                }
            }
        }
        #endregion Yes/No mode
    }
}