Function Global:Question-RunScript {
    <#
.DESCRIPTION
Ask the user if they want to continue running the script. This is a quick easy way to verify that a person wants to run a script that does not carefully make sure that the user wants to take every action before taking it. Hopefully, if the user does not know exactly what the script does, they will review it first before continuing.

.NOTES
    Script: Question-RunScript.ps1
    Author: Roman Revell
    developed on PowerShell 7.4.13

    History:
    version 2   2026-02-18 Modified to use Ask-Question function.
#>
    
    write-host $MyInvocation.ScriptName -ForegroundColor Yellow
    $Response = Ask-Question "This is a custom script that will make changes to an environment without further prompting. Do you want to continue? "
    if ($Response) {
        Write-Host "Continuing script execution..." -ForegroundColor Green
    }
    else {
        Write-Host "Aborting script execution." -ForegroundColor Yellow
        break
    }
}