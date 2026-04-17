Function ConvertTo-Array {
    <#
.SYNOPSIS
Create Powershell array from a multiline string.
 
.DESCRIPTION
This script should take a string and create various types of lists or arrays. See examples for the types of output.
You can either modify the script by replacing the text between the @""@, or you can input a string at the command line.

.NOTES
    Script: ConvertTo-Array.ps1
    Author: Roman Revell
    Requirements: PowerShell 7.x, (5.1 untested)

    History: 
    version 1      2024-12-31

.PARAMETER String
Multiline string that you want converted into an array.

.PARAMETER Delim
The character (or string) that you want to place between each item. 
Don't forget that you might need to quote this character on the command line to avoid PowerShell misinterpreting it.

.PARAMETER Quote
The character (or string) that you want to surround each item with. This becomes part of the item with respect to any delimiter specified.
Don't forget that you might need to quote this character on the command line to avoid PowerShell misinterpreting it.

.PARAMETER OneLine
Switch to tell the script to create the array as one item with everything concatinated onto one line.

.EXAMPLE
# convert to Powershell array
.\ConvertTo-Array.ps1
192.168.0.1
192.168.0.2
192.168.0.3

.EXAMPLE
# convert to array with each item separated by a delimiter, each item on one line
.\ConvertTo-Array.ps1 -delim ','
192.168.0.1,
192.168.0.2,
192.168.0.3

.EXAMPLE
# convert to array with each item surrounded by the quote character/string and each separated by a delimiter
.\ConvertTo-Array.ps1 -delim ',' -quote '"'
"192.168.0.1",
"192.168.0.2",
"192.168.0.3"

.EXAMPLE
# output onto one line
.\ConvertTo-Array.ps1 -OneLine
192.168.0.1192.168.0.2192.168.0.3

.EXAMPLE
# output onto one line with delimiter separators
.\ConvertTo-Array.ps1 -delim ',' -OneLine
192.168.0.1,192.168.0.2,192.168.0.3

.EXAMPLE
# output onto one line with delimiter separators and text qualifier/quote
.\ConvertTo-Array.ps1 -delim ',' -quote '"' -OneLine
"192.168.0.1","192.168.0.2","192.168.0.3"
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)][string]
        $string,
        [string]
        $delim,
        [string]
        $quote,
        [switch]
        $OneLine
    )
    Set-StrictMode -Version 3.0

    # convert to multiple items
    [array]$MyList = $string -split "`n"
    # Remove spaces/non-printing characters at the ends of each item
    $MyList = $MyList | foreach-object { $_.trim() }

    If ($OneLine) {
        $MyList2 = $null
        # Concatinate with the delimiter
        $MyList | ForEach-Object { $MyList2 = $MyList2 + $quote + $_ + $quote + $delim }
        If ($delim) {
            # Remove the delimiter from the end of the list
            $MyList2 = $MyList2.substring(0, $MyList2.length - 1)
        }
        $MyList2
    }
    else {
        # surround with (for example) quotes and a comma
        $MyList = $MyList | foreach-object { $quote + $_ + $quote + $delim }
        If ($delim) {
            # remove the delimiter at the end of the last item with the substring method. Start at 0 and go to the length of the item minus one.
            $MyList[-1] = $MyList[-1].substring(0, $MyList[-1].length - 1)
        }
        $MyList
    }
}