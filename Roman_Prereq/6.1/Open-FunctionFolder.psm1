function Open-FunctionFolder {
    <#
    .SYNOPSIS
    Opens the folder containing the script file of a specified function.

    .DESCRIPTION
    This function finds the location of a function's script file within a module or if dot-sourced and opens that folder in File Explorer. This is helpful if you are editing functions (especially in modules) and need quick access to the file folder in order to replace it with the updated script file.

    .PARAMETER Function
    The name of the function whose script file's folder you want to open.

    .EXAMPLE
    Open-FunctionFolder -Function MyFunction
    Opens the folder containing the script file for 'MyFunction'.

    .NOTES
    Requires PowerShell 5.0 or later.
    #>

    # Find the location of a function's script file within a module and open that folder so that I can edit the file.
    param (
        [parameter(mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("FunctionName")]
        [string]$Function
    )

    process {
        Get-Command -Name $Function -ErrorAction Stop | ForEach-Object {
            if ($_.ScriptBlock.File) {
                $scriptFile = $_.ScriptBlock.File
                $scriptFolder = Split-Path -Path $scriptFile -Parent
                if (Test-Path -Path $scriptFolder) {
                    Start-Process "explorer.exe" -ArgumentList $scriptFolder
                }
                else {
                    Write-Error "The script folder does not exist: $scriptFolder"
                }
            }
            else {
                Write-Error "The function '$Function' does not have an associated script file."
            }
        }
    }
}
Export-ModuleMember -Function Open-FunctionFolder