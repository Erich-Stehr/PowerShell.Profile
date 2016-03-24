<#
.SYNOPSIS
    Reset the search service application
.DESCRIPTION
	Does the same thing as the "Index Reset" option in Central Admin Search Service
.LINK
http://gallery.technet.microsoft.com/ScriptCenter
http://gallery.technet.microsoft.com/office/Reset-the-search-service-3663e13d
.NOTES
  File Name : Reset-SPEnterpriseSearchServiceApplication.ps1
  Original Author : Matthew King
  Author : Erich Stehr (added CmdletBinding, give proper default for $searchapp)

#>

[CmdletBinding()]
param (
	[Microsoft.Office.Server.Search.Cmdlet.SearchServiceApplicationPipeBind] 
	# search application to work with
	$searchapp=(@(Get-SPEnterpriseSearchServiceApplication)[0]),
	  [switch]$disableAlerts = $true,
	  [switch]$ignoreUnreachableServer = $true)

$ssa = Get-SPEnterpriseSearchServiceApplication -Identity $searchapp

Write-Host "Resetting '$($ssa.name)'..." -NoNewLine
$ssa.reset($disableAlerts, $ignoreUnreachableServer)
if (-not $?) {
	Write-Host "Failed"
	return
}
Write-Host "OK"
