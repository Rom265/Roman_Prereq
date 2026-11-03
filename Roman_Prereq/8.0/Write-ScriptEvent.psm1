function Write-ScriptEvent {
    <#
.SYNOPSIS
Write a message to the Windows Event Log for a custom script application.
 
.NOTES
Script: Write-ScriptEvent.ps1
Author: Roman Revell
Requirements: PowerShell 5.1 +

History: 
version 1     2026-09-14

.PARAMETER Message
Text of message to store in the event log.

.PARAMETER Level
Severity level of the event (Information, Warning, Error).

.PARAMETER EventId
Numeric identifier for the event.

.PARAMETER LogName
Name of the event log to write to.

.PARAMETER Source
Name of the application/script source.

.EXAMPLE

#>
    [cmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Level = 'Information',

        [int]$EventId = 1000,

        [string]$LogName = 'Application',

        [string]$Source = 'generic-script-event'
    )
    
    # Script initialization
    Set-StrictMode -Version 3.0

    
    $sourceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\$LogName\$Source"
    if (-not (Test-Path $sourceKey)) {
        try {
            # Source registration requires elevation and only needs to happen once.
            [System.Diagnostics.EventLog]::CreateEventSource($Source, $LogName)
        }
        catch [System.Management.Automation.MethodInvocationException] {
            Write-Output "Likely lack of permission to create event source. Run script `"as administrator`"."
            $_ # pass error or warning
            return
        }
        catch {
            $_ # pass error or warning
            return
        }
    }

    $EntryType = [System.Diagnostics.EventLogEntryType]::$Level

    [System.Diagnostics.EventLog]::WriteEntry(
        $Source,
        $Message,
        $EntryType,
        $EventId
    )
}