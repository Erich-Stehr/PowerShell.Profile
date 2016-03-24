[CmdletBinding(ConfirmImpact=[System.Management.Automation.ConfirmImpact]::Medium,SupportsShouldProcess=$true)]
#[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string] 
	# (local) site url to work with
	$siteUrl=$(throw "Requires (local) site URL to work with"),
	[switch]
	$force=$false
	)
Begin {
	#check for SP addin (from SharePoint 2010's Registration.ps1 without set-location, checking core PS version instead of host)
	if (!(get-pssnapin Microsoft.SharePoint.PowerShell -ea SilentlyContinue)) {
			$ver = $PSVersionTable
			if ($ver -eq $null) {
				trap {break;} # old style stop-on-throw-within-this-scriptblock
				throw "PowerShell version 1 can't access SharePoint"
			}
			if ($ver.PSVersion.Major -gt 1)  {$Host.Runspace.ThreadOptions = "ReuseThread"}
			Add-PsSnapin Microsoft.SharePoint.PowerShell -ea Stop
	}
	# include CSOM assemblies
	#Add-Type -Path "$sphive\ISAPI\Microsoft.SharePoint.Client.dll" -ea Stop
	[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client")
	[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client.Runtime")
}
Process {
    # ShouldProcess provides -Confirm/-WhatIf, $action is optional, additional arguments change semantics 
    if ($pscmdlet.ShouldProcess($target, $action)) {
		# cmdlets within need `-Confirm:$false` since we've already asked
		# ShouldContinue is optional secondary confirmation, controlled only by $force as here; prints caption/args[1], then query/args[0] ("" for default)
		if ($force -or $pscmdlet.ShouldContinue($query, $caption, [ref]$yesToAll, [ref]$noToAll)) {
	        Write "Deleting..."
		}
    }
}
End {
}

<#
.SYNOPSIS
	x
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
