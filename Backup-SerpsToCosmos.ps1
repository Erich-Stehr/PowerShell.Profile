[CmdletBinding(ConfirmImpact=[System.Management.Automation.ConfirmImpact]::Medium,SupportsShouldProcess=$true)]
#[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
param (
	[string] 
	# Directory to be backed up 
	$source="\\relemeas12\Archive\ScraperOutputFiles",
	[string] 
	# Cosmos stream to be backed up to 
	$destination="https://cosmos09.osdinfra.net/cosmos/relevance/projects/measurement/SerpsBackup",
	[switch]
	$force=$false
	)

    $latestCosmos = (Get-CosmosStream https://cosmos09.osdinfra.net/cosmos/relevance/projects/measurement/SerpsBackup | measure -Maximum -Property PublishedUpdateTime).Maximum

    # ShouldProcess provides -Confirm/-WhatIf, $action is optional, additional arguments change semantics 
    if ($pscmdlet.ShouldProcess($target, $action)) {
		# cmdlets within need `-Confirm:$false` since we've already asked
		# ShouldContinue is optional secondary confirmation, controlled only by $force as here; prints caption/args[1], then query/args[0] ("" for default)
		if ($force -or $pscmdlet.ShouldContinue($query, $caption, [ref]$yesToAll, [ref]$noToAll)) {
	        Write "Deleting..."
		}
    }

<#
.SYNOPSIS
	Backs up source directory to destination Cosmos stream
.DESCRIPTION
	x
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
#>
