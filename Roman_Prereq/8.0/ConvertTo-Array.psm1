Function ConvertTo-Array {
    <#
.SYNOPSIS
Create Powershell array from a string.
 
.DESCRIPTION
This script should take a string and create various types of lists or arrays. See examples for the types of input and output.
It was initially created to convert a multi-line string into an array, but I also added options that can convert an array into a string. See last example.
Note: spaces/unprintable characters are always removed off of the ends after separating items.
Note: if you input an array, the only input processing is to do a trim operation on each array item to remove blank spaces at the ends and whatever strings you input to the -SeparateInput argument.
Note: you may only input an array with the -Array parameter. If you pipe in an array, it effectively only processes the last item as a string. Piping is meant for only a single string.

.NOTES
    Script: ConvertTo-Array
    Module: Roman_Prereq
    Author: Roman Revell
    Requirements: PowerShell 7.x, (5.1 untested)

    History: 
    version 2.1  2026-09-04 Enable multiple delimiters in the input instead of only accepting a multiline string. Enable input of a Powershell array or string.
    version 1    2024-12-31

.PARAMETER String
Multiline string that you want converted into an array.

.PARAMETER Array
An array of strings. If you enter this, each item in the array is trimmed. Also, you can convert it to a one-line string with -OneLine.

.PARAMETER Delim
The character (or string) that you want to place between each item. 
Don't forget that you might need to quote this character on the command line to avoid PowerShell misinterpreting it.

.PARAMETER Quote
The character (or string) that you want to surround each item with. This becomes part of the item with respect to any delimiter specified.
Don't forget that you might need to quote this character on the command line to avoid PowerShell misinterpreting it.

.PARAMETER OneLine
Switch to tell the script to create the array as one item with everything concatinated onto one line.

.PARAMETER SeparateInput
Characters or strings that can be used to separate the input to create the array. Consecutive separators will effectively act as one separation and not include the separators in the output string of the array item. So, for example, if the separators are comma & quote mark, this input "192.168.0.1","192.168.0.2","192.168.0.3" will give this output 
192.168.0.1
192.168.0.2
192.168.0.3

Note: if you have a multi-line string created like so
@"
192.168.0.1
192.168.0.2
192.168.0.3
"@
The separator to convert each line to its own item is "`n" . That is the default.

If you input an array, the argument for -SeparateInput is merely trimmed from the ends of each array item.

.EXAMPLE
# convert to Powershell array
@"
192.168.0.1
192.168.0.2
192.168.0.3
"@ | ConvertTo-Array

192.168.0.1
192.168.0.2
192.168.0.3

.EXAMPLE
# convert to array with each item separated by a delimiter, each item on one line
@"
192.168.0.1
192.168.0.2
192.168.0.3
"@ | ConvertTo-Array -delim ','

192.168.0.1,
192.168.0.2,
192.168.0.3

.EXAMPLE
# convert to array with each item surrounded by the quote character/string and each separated by a delimiter
@"
192.168.0.1
192.168.0.2
192.168.0.3
"@ | ConvertTo-Array -delim ',' -quote '"'

"192.168.0.1",
"192.168.0.2",
"192.168.0.3"

.EXAMPLE
# output onto one line
@"
192.168.0.1
192.168.0.2
192.168.0.3
"@ | ConvertTo-Array -OneLine

192.168.0.1192.168.0.2192.168.0.3

.EXAMPLE
# output onto one line with delimiter separators and text qualifier/quote - could be used for an array on a command line
@"
192.168.0.1
192.168.0.2
192.168.0.3
"@ | ConvertTo-Array -delim ',' -quote '"' -OneLine

"192.168.0.1","192.168.0.2","192.168.0.3"

.EXAMPLE
# input string uses custom separator to form the array
'"192.168.0.1","192.168.0.2","192.168.0.3"' | ConvertTo-Array -SeparateInput ",",'"' # This includes two separators: comma and quote mark

192.168.0.1
192.168.0.2
192.168.0.3

.EXAMPLE
# input string uses custom separator and changes to a different delimiter and quote character
'"192.168.0.1","192.168.0.2","192.168.0.3"' | ConvertTo-Array -delim ';' -quote '|' -OneLine -SeparateInput ",",'"'

|192.168.0.1|;|192.168.0.2|;|192.168.0.3|

.EXAMPLE
# input array to trim unwanted characters and cast into a one-line string
"192.168.0.1#","192.168.0.2#","192.168.0.3#" | Set-Variable MyArray
ConvertTo-Array -Array $MyArray -SeparateInput '#' -Delim ', ' -Quote '"' -OneLine

"192.168.0.1", "192.168.0.2", "192.168.0.3"
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "StringInput")][string]
        $String,
        [Parameter(Mandatory, ParameterSetName = "ArrayInput")][string[]]
        $Array,
        [string]
        $Delim,
        [string]
        $Quote,
        [switch]
        $OneLine,
        [string[]]
        $SeparateInput = "`n" # new line as default
    )
    Set-StrictMode -Version Latest

    switch ($PSCmdlet.ParameterSetName) {
        "StringInput" {
            # convert to multiple items
            $pattern = '(?:' + ((
                    $SeparateInput |
                    Sort-Object Length -Descending |
                    ForEach-Object { [regex]::Escape($_) }
                ) -join '|') + ')+'

            Write-Verbose "`$pattern = $pattern"

            # Always cast as an array after the split
            @([regex]::Split($String, $pattern) | 
            # Remove spaces/non-printing characters at the ends of each item
            ForEach-Object { $_.trim() } | 
            # Only keep the items that are not empty or just a space
            Where-Object { $_ }) | 
            # Capture result for possible additional processing before return
            Set-Variable MyList

            break
        }
        "ArrayInput" {
            $MyList = $Array | foreach-object { $_.trim() }
            $MyList = $MyList | foreach-object { $_.trim($SeparateInput) }
            break
        }
    }

    If ($OneLine) {
        $MyList2 = $null
        # Concatinate with the delimiter
        $MyList | ForEach-Object { $MyList2 = $MyList2 + $Quote + $_ + $Quote + $Delim }
        If ($Delim) {
            # Remove the delimiter from the end of the list
            $MyList2 = $MyList2.substring(0, $MyList2.length - $Delim.length)
        }
        $MyList2
    }
    else {
        # surround with (for example) quotes and a comma
        $MyList = @($MyList | foreach-object { $Quote + $_ + $Quote + $Delim })
        If ($Delim) {
            # remove the delimiter at the end of the last item with the substring method. Start at 0 and go to the length of the item minus the length of the delimiter.
            $MyList[-1] = $MyList[-1].substring(0, $MyList[-1].length - $Delim.length)
        }
        $MyList
    }
}