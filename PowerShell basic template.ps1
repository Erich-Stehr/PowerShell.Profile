param (
	[Parameter(Mandatory=$true)]
	[string] 
	# (local) site url to work with
	$siteUrl=$(throw "Requires (local) site URL to work with"),
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
	)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)



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
