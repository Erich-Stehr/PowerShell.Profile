############################################################################
# Show-WmiClass - Show WMI classes
# Author: Microsoft <http://blogs.msdn.com/powershell/comments/4659761.aspx>
# Version: 1.0
# NOTE: Notice that this is uses the verb SHOW vs GET. That is because it
# combines a Getter with a format. SHOW was added as a new "official
# verb to deal with just this case.
############################################################################
param(
$Name = ".",
$NameSpace = "root\cimv2",
[Switch]$Refresh=$false
)

# Getting a list of classes can be expensive and the list changes infrequently. 
# This makes it a good candidate for caching.

$CacheDir = Join-path $env:Temp "WMIClasses"
$CacheFile = Join-Path $CacheDir ($Namespace.Replace("\","-") + ".csv")
if (!(Test-Path $CacheDir))
{
$null = New-Item -Type Directory -Force $CacheDir
}

if (!(Test-Path $CacheFile) -Or $Refresh)
{
Get-WmiObject -List -Namespace:$Namespace |
Sort -Property Name |
Select -Property Name |
Export-csv -Path $CacheFile -Force
}

Import-csv -Path $CacheFile | 
where {$_.Name -match $Name} |
Format-Wide -AutoSize
###### EOF ###########
# Examples 
# PS> show-wmiclass account
# MSFT_NetBadAccount Win32_Account Win32_AccountSID Win32_SystemAccount Win32_UserAccount
# PS> show-wmiclass account -namespace root\cimv2\terminalservices
# Win32_TSAccount
# PS> show-wmiclass -namespace root\cimv2\terminalservices
# __AbsoluteTimerInstruction __ACE [....]
