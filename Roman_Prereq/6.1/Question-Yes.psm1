function Question-Yes {
    [system.obsolete("You should use Ask-Question instead. It may be removed in a future version of the module.")]
    param ($QuestionMessage)

    function Get-Key {
        if ($psISE) {
            # Method for ISE: Requires Enter
            Read-Host
        }
        else {
            # Method for Console (v5.1 & 7): Immediate on press and release
            [Console]::ReadKey($true).Key # note: $true means to "intercept" the key press and thus not display it
        }
    }
    
    Write-Host $QuestionMessage -NoNewline
    write-host " [Y] Yes" -ForegroundColor Yellow -NoNewline
    write-host '  [' -NoNewline
    write-host 'other' -ForegroundColor DarkGray -NoNewline
    write-host '] No  (default is "Y")'
    $KeyPress = Get-Key
    If ($KeyPress.gettype().name -eq "String") {
        # Process input from Powershell ISE
        if ($KeyPress.Length -eq 0) {
            $Choice = "Enter"    
        }
        else {
            $Choice = ($KeyPress.Substring(0,1)).ToUpper()
        }
    }
    else {
        # Process input from Powershell console
        if ($KeyPress.Key) {
            $Choice = $KeyPress.Key
        }
        else {
            $Choice = $KeyPress
        }
    }

    If ($Choice -eq "Y" -or $Choice -eq "Enter") {
        $true
        return
    }
    else {
        $false
        return
    }
}