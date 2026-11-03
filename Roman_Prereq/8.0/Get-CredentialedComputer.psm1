Function Get-CredentialedComputer {
    <#
.SYNOPSIS
Get credential for computers from foreign domains and create objects with all the necessary information to pipeline computer objects.
 
.DESCRIPTION 
Input list file or array of computers with fully qualified domain names. It will create an object with host name, domain name, fully qualified computer name, and credential in some cases. One can then send these objects through the pipeline into other functions.
	
.NOTES
Script: Get-CredentialedComputer.ps1
Author: Roman Revell
Requirements: PowerShell v.5.1 or 7+

History: 
    version 3       2026-08-13 Change the Get-Credential process such that if the script prompts for a credential, it will first ask for the user ID because in PowerShell 7+, it does not bring up the graphical user interface and thus there is no way to change the user ID. Fix up some prompting logic and simplify.
    version 2.6     2025-07-23 Added check for PowerShell ISE, in which case, use Read-Host to get user input instead of console readkey.
    version 2.5     2025-06-10 When failing to get the IP address, it was returning an object for the error that was being captured as a data object. Fixed that so it only reports as an error object.
    version 2.4     2025-03-11 Added the ability to accept a credential object or a user name into one parameter that replaces the user parameter.
    version 2.3     2025-03-02 Fixed user credential collection to also work in Powershell 7 where the GUI credential popup does not occur.
    version 2.2.3   2024-09-15 Fixed extra object in pipeline caused by read-host.
    version 2.2.2   2024-09-09 Added command for module member export and saved as .psm1.
    version 2.2.1   2024-01-22 Fix to prevent collecting multiple IPs for a machine. Just take the first one.
    version 2.2     2023-06-08 Clean-up some text and allow a specified user to force credential collection even if it is the same Id as the current user. Also, fix the domain name addtion to credentials part.
    version 2.1     2023-05-04 Create options to specify domain name in the user parameter or no credentials at all.
	version 1.3     2023-01-26 The -unique function of sort was not working right and only returning one domain
    version 1.2     2023-01-24 The output to the pipeline is wrong. Fix line 108, etc.
    version 1.1     2022-12-12 Add IP address as a property so that I can use it to call remote sessions as they seem to only work with IP address.
    version 1.0.1   2022-11-28
    version 1		2022-11-27

Terms:
logon ID = domain and user ID in the form or either domain\userId or userId@domainFQDN, which can be used with a password for a logon credential
user ID = just the user logon name part without domain
PsCredential = special object type used in PowerShell when logging on to machines, a full logon credential

The default assumption is that you are logged on currently with a domain account and all of the machines that you are creating objects for are in that same domain. If that is not the case, then we have to start asking questions.

1. if either a. the machine domains differ or b. any machine's domain differs from the logged on user's domain, then we need to ask what logon ID to use (domain\userID), unless -Credential was specified with a string (as opposed to PsCredential object) in a format like "*\*" or "*@*" with domain and user name. Then, just use that.
2. if just option -SeparateCreds was used, then ask for a logon ID regardless and ask for one for each machine domain. So, for machines in this domain, what account do you want to use to logon?
For 1. or 2. the current account will be made available as a default and then whichever account was last specified if more than one needs to be asked about.
3. if -SeparateCreds and -Credential (as a logon ID) were specified, then we prompt for credentials using the specified ID as the default.
4. if -Credential was supplied as a PsCredential object, then just use that for all machines, unless
5. if -SeparateCreds was also specified, then automatically substitute in the domain name of each machine into the supplied credential.

output object properties:
.HostName
.DomainName
.ComputerName (fully qualified name, but it is called this because this name is the standard name used for cmdlets; so, it is what needs to be passed by default)
.Credential
.IPv4Address

.PARAMETER ComputerList
    Text file with a list of fully qualified computer names.

.PARAMETER ComputerName
    One or more fully qualified computer names.

.PARAMETER Credential
    (optional) This option can be used in one of two formats: 1. a PsCredential object 2. a user Id or logon ID.
    1. a PsCredential object will be used as-is for all machines, unless -SeparateCreds is specified. In that case, the domain of each machine will be substituted in automatically.
    2. if logon ID is specified, then the script will prompt for password and a PsCredential will be created and used for all machines, unless -SeparateCreds is specified. In that case, the script will prompt for logon ID and password for each machine domain and only use this as the default.
    If just user ID is specified, then that will be used as the default and a logon ID and password will be collected for each machine domain.

.PARAMETER SeparateCreds
    Switch to tell this function to ask for credentials for each domain rather than assuming they are all the same. That overrides the logic of using -Credential without this option as specified in the -Credential notes. Also, this option will cause a prompt for credentials even if there's only one domain in the list and it is our user account's current domain. The current user or user parameter will just be used as a suggestion.

.PARAMETER NoCreds
    Do not ask for any credentials. The computer object "credential" property will be NULL in this case.

.OUTPUTS
[System.Management.Automation.PSObject] aka. [PSCustomObject]
See desription.
#>
    [CmdletBinding()]
    param (
        [parameter(mandatory = $true, parameterSetName = "ListFileNoCreds")]
        [parameter(mandatory = $true, parameterSetName = "ListFile")]
        [string]
        [alias("List")]
        $ComputerList,
        
        [parameter(Mandatory = $true, parameterSetName = "ComputerNameNoCreds")]
        [parameter(Mandatory = $true, parameterSetName = "ComputerName")]
        [string[]]
        [alias("Name")]
        $ComputerName,

        [parameter(parameterSetName = "ListFile")]
        [parameter(parameterSetName = "ComputerName")]
        [ValidateScript({ ($_ -is [string]) -or ($_ -is [pscredential]) })]
        [alias("user")]
        $Credential,
        
        [parameter(parameterSetName = "ListFile")]
        [parameter(parameterSetName = "ComputerName")]
        [switch]
        $SeparateCreds,
        
        [parameter(mandatory, parameterSetName = "ListFileNoCreds")]
        [parameter(mandatory, parameterSetName = "ComputerNameNoCreds")]
        [switch]
        $NoCreds
    )
    Set-StrictMode -Version Latest
    
    # If credential was not specified, then $Credential and $UserID will be $null. If $Credential was a string (as opposed to pscredential), then convert that to the variable $UserID and set $Credential to $null. Otherwise, $Credential is a pscredential; so set $UserID to $null. This is because later in the code, I will use checks for either $Credential or $UserID and expect the other to be $null.
    if ($Credential -is [pscredential]) {
        $PSCredential = $Credential
        Remove-Variable Credential
        $LogonID = $null
    }
    elseIf ($Credential -is [string]) {
        $LogonID = $Credential
        $PSCredential = $null # so that if ($PSCredential) will evaluate as false
        Remove-Variable Credential
    }
    elseif (!$Credential) { 
        $PSCredential = $null
        $LogonID = $null
        Remove-Variable Credential
    }

    switch ($PsCmdlet.ParameterSetName) {
        { $_ -in "ListFile", "ListFileNoCreds" } { [array]$Computers = get-content $computerList }
        { $_ -in "ComputerName", "ComputerNameNoCreds" } { [array]$Computers = $computerName }
    }
    ## Create computer collection
    [System.Collections.Generic.List[PSCustomObject]]$computerCollection = @()
    # Get list of all fully qualified computer names and save as collection of objects with properties: hostName, domainName, computername, credential, IPv4Address
    foreach ($computer in $computers) {
        $computer = $computer.trim() # remove white space at the ends of the entry in case someone accidentally left a space after the name, for example.
        # computer name should be letters, numbers, underscore or dash followed by a dot and then domain name with same constraints. (not sure if those are exactly the right constraints)
        if ($computer -match "^(?<host>[0-9a-zA-Z\-_]+)\.(?<domain>[0-9a-zA-Z\-_\.]+)") {
            # The type accelerator [PSCustomObject] requires Powershell v.3+
            write-verbose "Getting IP address of $computer"
            try { $IPv4Address = [System.Net.Dns]::GetHostAddresses("$computer") }
            catch {
                Write-Error "Error obtaining IP address of $computer : $($_.exception.ToString()). Skipping computer."
                continue
            }
            $computerCollection.Add( 
                [PSCustomObject]@{
                    "hostName"     = $matches.host
                    "domainName"   = $matches.domain
                    "ComputerName" = $matches.host + '.' + $matches.domain
                    "credential"   = $null
                    "IPv4Address"  = $IPv4Address[0].IPAddressToString # capturing only the first IP because some commands will otherwise try to run multiple times if there are multiple IPs
                }
            )
        } # create computer object
        elseif ($computer -match "^(?<host>[0-9a-zA-Z\-_]+)$") {
            write-verbose "Getting IP address of $computer"
            try { $IPv4Address = [System.Net.Dns]::GetHostAddresses("$computer") }
            catch {
                Write-Error "Error obtaining IP address of $computer : $($_.exception.ToString()). Skipping computer."
                continue
            }
            $computerCollection.Add( 
                [PSCustomObject]@{
                    "hostName"     = $matches.host
                    "domainName"   = "localhost"
                    "ComputerName" = $null
                    "credential"   = $null
                    "IPv4Address"  = $IPv4Address[0].IPAddressToString # capturing only the first IP because some commands will otherwise try to run multiple times if there are multiple IPs
                }
            )
        } # create object; use 'localhost' for domain
        else {
            Write-Error "Invalid computer name: $computer. Skipping computer."
            continue
        } # error
    } # foreach computer, define PSObject
        
    if ($computerCollection) {
        # Note: Sort-Object -unique is case insensitive, thus we must use this instead of -unique on Select-Object, which is not.
        # The -ExpandProperty parameter makes the output simply the value rather than keeping the property-name/key
        [array]$domainList = $computerCollection | Select-Object -ExpandProperty domainName | Sort-Object -unique
               
        # If not $noCreds, then get credentials unless nothing was sent in the credential argument and we only have computers in one domain and that domain is the current user's domain.
        if (! $noCreds) {
            ## Do we need to add a credential object to each computer? 
            ## We do if a credential is specified OR 
            ## if any machine domain does not match the logged on user domain (if there is more than one machine domain, that will obviously be the case) OR 
            ## -SeparateCreds was specified
            if ($PSCredential -or $LogonID -or ($domainList.Count -gt 1) -or (-not ($env:USERDNSDOMAIN -in $domainList)) -or $separateCreds) {

                function PromptForCredential {
                    param ($UserName, $DomainName)
                    
                    Write-Host "Specify the logon ID (domain\password) that you'd like to use for machine domain " -NoNewline
                    Write-Host -ForegroundColor Yellow "$domain" -NoNewline
                    Write-Host ". Enter for default '" -NoNewLine
                    Write-Host -ForegroundColor Yellow "$DomainName\$UserName" -NoNewline
                    Write-Host "' : " -NoNewline
                    $UserInput = $null
                    $UserInput = read-host

                    if ($UserInput -eq "") {
                        $UserInput = "$DomainName\$UserName"
                    }
                    if ($UserInput -eq $null) {
                        break
                    }
                    Get-Credential -UserName $UserInput
                }
                function SeparateLogonID {
                    # Separate user ID from domain name in a logon ID and return user ID
                    param($LogonID)
                    Set-StrictMode -Off
                    if ($LogonID -match "^(?<domain>[^\\@]+)\\(?<user>[^\\@]+)$|^(?<user>[^\\@]+)@(?<domain>[^\\@]+)$|^(?<user>[^\\@]+)$") {
                        return $matches.user, $matches.domain
                    }
                    else {
                        Write-Error "Could not separate the logon ID '$LogonID' into user and domain (or either)."
                    }
                }
                
                
                if ($separateCreds) {
                    # -separateCreds = collect different credentials for each domain found in the computer list of fully qualified domain names

                    $domainCred = @{} # Hash for domain/credential pairs

                    Foreach ($domain in $domainList) {
                        If ($PSCredential) {
                            $UserID, $DomainID = SeparateLogonID -LogonID $PSCredential.UserName
                            If ($UserID) {
                                $PSCredential = PromptForCredential -UserName $UserID -DomainName $domain
                            }
                            else {
                                Write-Error "Credential collection failed. The credential specified did not have valid user name format."
                                return
                            }
                        }
                        elseif ($LogonID) {
                            $UserID, $DomainID = SeparateLogonID -LogonID $LogonID
                            $PSCredential = PromptForCredential -UserName $UserID -DomainName $domain
                        }
                        else {
                            # Use currently logged on user since no user ID was specified
                            $PSCredential = PromptForCredential -UserName $env:USERNAME -DomainName $domain
                        }
                        
                        # Add each domain/credential pair to the hash
                        $domainCred.Add($domain, $PSCredential)
                    }
                    Foreach ($computerObj in $computerCollection) {
                        $computerObj.credential = $domainCred[$computerObj.domainName]
                    }
                }
                
                # not using separate credentials; so only one will be applied to all computers
                elseif ($PSCredential) {
                    Foreach ($computerObj in $computerCollection) {
                        $computerObj.credential = $PSCredential
                    }
                }

                elseif ($LogonID) {                    
                    # If a logon ID was specified...
                    $UserID, $DomainID = SeparateLogonID -LogonID $LogonID
                    if ($DomainID) {
                        $PSCredential = PromptForCredential -UserName $UserID -DomainName $DomainID
                        Foreach ($computerObj in $computerCollection) {
                            $computerObj.credential = $PSCredential
                        }
                    }
                    else {
                        #-Credential was specified as just a user ID (no domain), so prompt for a credential for each machine domain using that domain as the default
                        Foreach ($domain in $domainList) {
                            $PSCredential = PromptForCredential -UserName $UserID -DomainName $domain
                            $computerCollection | Where-Object domainName -eq $domain | ForEach-Object {
                                $_.Credential = $PSCredential
                            }
                        }
                    }                                     
                }
                elseif (($domainList.Count -gt 1) -or (-not ($env:USERDNSDOMAIN -in $domainList))) {
                    Foreach ($domain in $domainList) {
                        # Use currently logged on user since no user ID was specified
                        $PSCredential = PromptForCredential -UserName $env:USERNAME -DomainName $domain
                        $computerCollection | Where-Object domainName -eq $domain | ForEach-Object {
                            $_.Credential = $PSCredential
                        }
                    }
                }                
            } ## Do we need to get credentials?
        }
        return $computerCollection
    }
}
Export-ModuleMember -Function Get-CredentialedComputer