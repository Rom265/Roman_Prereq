<#
.SYNOPSIS
    Writes to the screen like write-host and to a text file
 
.DESCRIPTION 
    The Write-Log function writes to the Powershell host (screen) using Write-Host. It also sends the same text to a text file.
    
    Create a standard line for the start of logging with:
        Write-Log -Start

    That also sets the log path into a global variable $LogLocation. This allows you to write to the same log file even if calling Write-Log from another script or scope.
    
    If you want to specify a log file (as opposed to using the default) to write to for the rest of the script, include -LogPath.
        Write-Log -Start -LogPath myScript'sLogFile.txt
    
    -LogPath takes precedence over $LogLocation if the latter already exists.
    Write-Log "Another message which should go to this specified location only for this command" -LogLocation someOtherFile.txt

    Write to the log and to the screen with 
        Write-Log "Some message"

    Create a standard line for the end of a script with:
        Write-Log -End

    That will also let the Powershell host forget the global $LogLocation variable. So, you could also just delete or change that variable if you want.

    This function is now included in the module Roman_Prereq.

.NOTES
Script: Write-Log.ps1
Author: Roman Revell
developed on PowerShell v.5.1, 7.4.13

Test scenarios:
1. call Write-Log -Start from script (with and without $LogLocation existing first)
2. call Write-Log -End from script (with and without $LogLocation existing first)
3. call function from a script with no message
4. call function from a script with a message, but $LogLocation does not exist.
5. call function from a script with a message, and $LogLocation does exist.
6. call function from a function or command line with no message
7. call function from a function or command line with a message, but $LogLocation does not exist.
8. call function from a function or command line with a message, and $LogLocation does exist.
9. call Write-Log -Start from function or command line
10. call Write-Log -End from function or command line
When using -LogPath, use full path, just file name, and partial path/relative path.


History: 
    version 5.6    2026-02-18 Remove the logging of the line that says I'm logging, only display it.
    version 5.5    2025-06-01 Add use of the Ensure-Folder function so that when a log location is specified, if the folder does not exist, it is created to ensure that we're able to write to the log file. Also, fix so that it checks for UNC paths as legitimate absolute paths.
    version 5.4.1  2025-03-13 Change the new option to -OnlyLog because there are many existing scripts that used the original -log and creating another option that starts with log created ambiguity and thus broke those scripts.
    version 5.4    2025-03-04 Add option -LogOnly to only write to the log and not the screen.
    version 5.3.1  2024-10-15 Improved some of the help comments.
    version 5.3    2024-09-10 Revising to run as a module. Previously, if Write-Log was called without having called it with a LogPath argument, it wrote the output to where the Write-Log.psm1 file was. We don't want that.
    version 5.2.1  2023-12-18 Just added example for standard start to documentation.
    version 5.2    2022-05-15 Changed the start and end formatting to look better.
    version 5.1    2020-05-22 Notably, this doesn't work when not specifying the full path to the log file. Fix so that the log path is ultimately a full path.
    version 5.0	   2018-10-01 Make it work even if not running from a script. Use the current directory and name write-log###.log.txt.
	version 4.3    2017-01-04 Detect encoding of existing log file and match it when writing to avoid munged output.
    version 4.2    2016-12-28 Add no new line function for writing out to file as well as screen.
    version 4.1.1  2016-12-28 Added some documentation
	version 4.1    2016-12-16 fixed invoke-expression
	version 4	   2015-10-29 Added copy of Write-Host options
	version 3.1.2  Change -scope 1 to -scope script
    version 3.1.1  Fixed $logLocation initialization
    version 3.1

.PARAMETER Message
	The text to show to the screen and save in a file.
	
.PARAMETER LogPath
	A log file of the start, stop, and maybe progress details is created. 
    You may specify the full path name of the file you want to log to, otherwise it will create a default in the same directory as the script.
  
.PARAMETER Start
	Switch to write a standard 'start script' message. If this is specified, the -Message parameter does nothing.

.PARAMETER End
	Switch to write a standard 'end script' message. If this is specified, the -Message parameter does nothing.

.PARAMETER NoNewLine
	Switch to prevent a new line from being written at the end of the text written to the screen. In this version, the text written to a file still wrapps.
	
.PARAMETER ForegroundColor
	Color of the text.
	
.PARAMETER BackgroundColor
	Color of shading next to (behind) the text.

.PARAMETER OnlyLog
    Switch to only write to the log and not the screen.
	
.EXAMPLE
if ($LogPath) { Write-Log -Start -LogPath $LogPath } else { Write-Log -Start }
╔═2024-10-14 14:48:24Z-07 This-Script-Name has started═╗

.EXAMPLE
Write-Log -End
╚═2024-10-14 14:48:42Z-07 This-Script-Name has ended═══╝
#>
FUNCTION Write-Log {
    [CmdletBinding()]
    param ( 
        # Undeclared variables will generate error with strictmode on. So, include these defaults.
        [string]$Message = $null,
        [switch]$Start = $null,
        [switch]$End = $null,
        [string]$LogPath = $null,
        [switch]$NoNewline,
        [string]$ForegroundColor = $null,
        [string]$BackgroundColor = $null,
        [switch]$OnlyLog
    )
    Set-StrictMode -Version 2.0
    if (! ($start -or $end -or $message) ) {
        Write-Warning "Write-Log called with nothing to write"
        return
    }
    $dateFormat = "yyyy-MM-dd HH:mm:ss\Zzz"
    # Determine if this was called from a script. That information is used in multiple sections of this script.
    #$invocation = (get-variable MyInvocation -scope script).value
    if ($MyInvocation.ScriptName) {
        $script = $true
        $scriptPath = $MyInvocation.PSScriptRoot
        $scriptName = [system.io.path]::GetFilenameWithoutExtension($MyInvocation.ScriptName)
        # Note: system.io.path works with strings (as opposed to file system objects)
    }
    else { $script = $false }

    ## Establish current log location
    # if log not specified, use default
    if (!$LogPath) {
        # if the global variable logLocation has been set, use that
        if (Test-Path variable:global:LogLocation) {
            $LogPath = $global:logLocation
        }
        # default log location within script
        elseif ($script) {	
            # Log is created in the same location as the script that called write-log and with the same name plus .log.txt suffix
            $LogPath = "$scriptPath\$scriptName.log.txt"
        }
        else {
            # default log location when not running from within script
            $currentPath = (Get-Location).Path
            $resultName = "Write-Log"
            $resultExt = "log.txt"
            $count = 0
            $num = $null
            While (test-path ("$currentPath\" + "$resultName" + "$num" + ".$resultExt")) {
                $count++
                $num = $count
            }
            $LogPath = "$currentPath\" + "$resultName" + "$num" + ".$resultExt" 
        }
    } # if not log
    else {
        # log file path was specified, but we need to make sure that we have the full path
        $pathPortion = [IO.Path]::GetDirectoryName( $LogPath )
        if ( ($pathPortion -notmatch ":") -and ($pathPortion -notmatch "\\\\") ) {
            # if the path does not contain a colon or two backslashes, then it is not a full path
            $currentPath = (Get-Location).Path
            $LogPath = "$currentPath\" + "$LogPath"
        }
    } # log was specified
    ## $LogPath does exist from here

    # Determine existing file's encoding.
    If (test-path $LogPath) {
        # Create a stream reader to get the file's encoding and contents.
        $sr = New-Object System.IO.StreamReader($LogPath, $true)
        $buffer = new-object -TypeName char[] -argumentlist 4
        $sr.Read($buffer, 0, 4) | Out-Null
        $encoding = $sr.CurrentEncoding
        $sr.Close()
    }
    else {
        # Unicode is compatible with Powershell Out-File. "Default" is not.
        $encoding = [System.Text.Encoding]::Unicode
        $LogFolder = [IO.Path]::GetDirectoryName( $LogPath )
        Ensure-Folder -path "$LogFolder\" -ErrorAction Stop        
    }
    
    # Which kind of operation are we doing? start, end, or message? They are mutually exclusive.
    if ($start) {
        $global:logLocation = $LogPath
        if ($script) {
            $message = "╔═$(get-date -format $dateFormat) $scriptName has started═╗"
        }
        else {
            $message = "╔═$(get-date -format $dateFormat) a logged function has started═╗"
        }
    }
    elseif ($end) {
        if ($script) {
            $message = "╚═$(get-date -format $dateFormat) $scriptName has ended═══╝"
        }
        else {
            $message = "╚═$(get-date -format $dateFormat) log has ended═════════════════╝"
        }
        Write-Host "Logged to file:  $LogPath"
        if (Test-Path variable:global:LogLocation) {
            remove-variable -Scope global -Name logLocation
        }
    }
    if ($NoNewline) { [string]$NoNewline = "-NoNewline" } else { [string]$NoNewline = $null }
    if ($foregroundColor) { $foregroundColor = "-foregroundColor $foregroundColor" }
    if ($BackgroundColor) { $BackgroundColor = "-BackgroundColor $BackgroundColor" }
    if (!$OnlyLog) {
        # Be very careful about this line. If the message has single quotes in it or a $, there could be trouble if you don't get the syntax around the $message correct
        invoke-expression "Write-Host $('$message') $NoNewline $foregroundColor $BackgroundColor"
    }
    if ($NoNewline) { [io.file]::AppendAllText($LogPath, $message, $encoding) }
    else { [io.file]::AppendAllText($LogPath, ($message + [System.Environment]::NewLine), $encoding) }
    if ($Start) {
        Write-Host "Logging to file: $LogPath"
    }
}
Export-ModuleMember -Function Write-Log