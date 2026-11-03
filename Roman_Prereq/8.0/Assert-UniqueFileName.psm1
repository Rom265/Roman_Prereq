function Assert-UniqueFileName {
    [Alias('Ensure-UniqueFileName')]
    <#
.SYNOPSIS
Modify a file path and name such that an appendage is added to the file name.
 
.DESCRIPTION
This should generally make the file name unique so that you don't have to contend with a file name that already exists. Input the path, it outputs the new path.
There are two uniquifying options: 1. add the date and time 2. add a number to the end to make the file name unique (like Windows does automatically in some cases). The default is to do both (date, then number). 
Note: date alone is not guaranteed to be unique since it only adds the time to the minute. So, doing both (or not specifying either option) is usually better as the number option will not add a number if the name is already not in existence.

.NOTES
Script: Assert-UniqueFileName.ps1
Author: Roman Revell
Requirements: PowerShell v.7.x

History: 
version 1    2026-11-03

.PARAMETER FilePath
Full or relative file path & name.

.PARAMETER Date
(switch) Add the current date and time (to the minute) to the end of the file name (before the extension).

.PARAMETER Number
(switch) Add a unique number to the end of the file name (before the extension) in this manner "fileName (1).txt" if a file with the specified name already exists.

.PARAMETER ForceExtension
Specify a file extension without the leading dot (.). It will replace the existing (or nonexistent) extension.

.EXAMPLE
Assert-UniqueFileName $env:temp\test.txt

#>
    Param (
        [string]
        $FilePath,
        [switch]
        $Date,
        [switch]
        $Number,
        [string]
        $ForceExtension
    )
    function AddDate {
        param ($FileName)
        $dateFormat = "yyyy-MM-dd_HH-mm"
        $today = get-date -format $dateFormat
        $FileName + "_$today" # Return file name with date & time
    }

    function AddNumber {
        param (
            $FileFolder,
            $FileName
        )

        $num = 2
        $NewFileName = $FileName
        $NewFilePath = $FileFolder + '\' + $NewFileName + $FileExtension
        While (Test-Path $NewFilePath) {
            $NewFileName = $FileName + " ($num)"
            $NewFilePath = $FileFolder + '\' + $NewFileName + $FileExtension
            $num ++
        }
        $NewFileName # return file name
    }

    $FileFolder = split-path -Path $FilePath
    $FileName = [system.io.path]::GetFilenameWithoutExtension($FilePath)
    if ($ForceExtension) {
        $FileExtension = '.' + $ForceExtension
    }
    else {
        $FileExtension = [system.io.path]::GetExtension($FilePath) # Returns extension including leading dot (.)
    }

    if ($Date -and $Number) {
        $Mode = "both"
    }
    elseif ($Date) {
        $Mode = "date"
    }
    elseif ($Number) {
        $Mode = "number"
    }
    else { $Mode = "both" }

    switch ($Mode) {
        "date" {
            $FileName = AddDate $FileName
            break
        }
        "number" {
            $FileName = AddNumber $FileFolder $FileName
            break
        }
        "both" {
            $FileName = AddDate $FileName
            $FileName = AddNumber $FileFolder $FileName
            break
        }
    }

    if ($ForceExtension) {
        $FullFileName = $FileName + '.' + $ForceExtension
    }
    else {
        $FullFileName = $FileName + $FileExtension
    }

    $FileFolder + '\' + $FullFileName
}