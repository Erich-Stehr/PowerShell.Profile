#http://blogs.msdn.com/powershell/archive/2008/12/02/get-everyone.aspx
#patched for run-loading
#Get-Everyone.ps1
param([switch]$fromDomain)

function global:Get-Everyone([switch]$fromDomain) {
    #.Synopsis
    #   Gets all users
    #.Description
    #   Queries WMI to get all users.  To save time, queries
    #   are local unless the -fromDomain switch is used
    #.Parameter fromDomain
    #   If set, gets domain users as well as local accounts
    #.Example
    #   # Get All Local Accounts
    #   Get-Everyone
    #.Example
    #   # Get All Local & Domain Accounts
    #   Get-Everyone -fromDomain
    $query = "Win32_UserAccount"
    if (-not $fromDomain) {
        $query+= " WHERE LocalAccount='True'"
    }
    Get-WmiObject $query
}

Get-Everyone -fromDomain:$fromDomain
