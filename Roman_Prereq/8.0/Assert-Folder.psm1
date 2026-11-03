Function Assert-Folder {
    [Alias('Ensure-Folder')]
    <#
    .SYNOPSIS
    When a folder or file name is passed to this function, ensure that the folder exists.
     
    .DESCRIPTION     
    This script should check if the path exists and if not, get the folder portion and create that. Then, return the folder path.
    If the thing to be checked is just a letter:\, then if that does not exist, then we must return an error as obviously we can't create a 
    new drive.
    If you just pass a string with no backslashes, it is interpreted as just a file name, which would apply to the current working directory.
    So, the current working directory is returned.
    !!Do NOT try to use a construction like 'c:' with no back-slashes!! Powershell/.Net does not interpret that as the current working directory
    on the C: drive like some cmdlets do. So, you will likely not get what you expected.
    
    .NOTES
    Script: Assert-Folder.ps1
    Author: Roman Revell
    Requirements: PowerShell v.5.1
    
    History: 
    version 1.5  2026-08-24  Added "-Force" to Get-Child command so that it will work when this script is passed an extant yet hidden folder. (line 70)
    version 1.4  2026-03-20  Renamed to approved verb with alias to avoid harrassment.
    version 1.3  2025-05-30  Fixed so that if the path is on a remote machine, it will still work and not fail to a subfolder of the current working directory. Also, fixed so that if there is a file at the end of the path where there should be a folder, it will return a fail.
    version 1.2  2024-12-15  Fixed so that paths with no back-slashes will correctly interpret that as a file in the current working directory.
    version 1.1  2024-01-25  Fixed return string.
    version 1    2023-04-04
    
    .PARAMETER Path
    Input should be System.IO.DirectoryInfo, System.IO.FileInfo, or a string representing the path to a folder or file.
    #>
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("FullPath")]
        $Path
    )
    Begin {
        function normalize-path {
            <# A pretty good file system normalization function.
            This script will return the full path to a folder or file that you specify without having to verify that the path exists.
            It will not work if you try to use a construction like "c:some_file.ext". With some cmdlets that identifies the current folder on the c: drive and then appends "some_file.ext" to the end. 
            But Split-Path identifies that as an absolute path. If it didn't, the next line wouldn't work anyway. So then, you'd expect [System.io.path]::GetFullPath("$Path") to properly resolve that
            as described. But, it doesn't. It returns the home folder with some_file.ext appended as a path to the end. That is because the current working directly aka present working directory ($PWD) 
            does not register as the same as the device's current directory. This is one of the problems with the Windows system of having a drive letter (device) as a drive designator rather than
            having just one integral file system addressing scheme where you append hardware storage devices onto folder names or otherwise abstract them.
            This also will not validate that the path can be a valid path. You could have a path like "C:\scripts\temp\invalidchar:|.xls" and it will not raise any error.
            #>
            param(    
                $path
            )
            if (! (Split-Path -Path $Path -IsAbsolute)) {
                # The -IsAbsolute fails to recognize a UNC path, so we have to check for that.
                if (!($Path -match "^\\\\.+")) {
                    # If the path starts with two backslashes, then it is a UNC path and thus absolute. If not, it is a relative path and we need to append the current working directory.
                    # Note: The quotes on the next two lines are necessary
                    $path = "$PWD\$path"
                }
            }
            return [System.io.path]::GetFullPath("$Path")
        }    
    }
    Process {
        [System.IO.FileInfo]$Path = normalize-path $Path
        
        # Whether a full path or relative, if this works, then there's no missing folder; so, just pass on the string.
        # This test will correctly fail if you put something like F: or F:\ if there is no F: drive. This will only return an error.
        if ($Path.DirectoryName) {
            if (test-path $Path.DirectoryName) {
                If ((Get-Item $Path.DirectoryName -Force).PSIsContainer) {
                    # If the path is a directory, then return the directory name. If not, then there is a file with the path name of the folder that we need to create and thus, we can't create it. So, we need to return a failure.
                return $Path.DirectoryName
                }
                else {
                    Write-Error "A file with the same name as the desired folder already exists: $($Path.DirectoryName)" -ErrorAction Stop
                }
            }
            else {
                return (mkdir $Path.DirectoryName | Select-Object -ExpandProperty FullName)
            }   
        }
        # If the DirectoryName property was not defined in spite of the string being a valid path, that means it is a drive root.
        elseif (test-path $Path) {
            return $Path
        }
        else {
            Write-Error "Drive does not exist: $Path"
        }
    }
    end {   

    }
}