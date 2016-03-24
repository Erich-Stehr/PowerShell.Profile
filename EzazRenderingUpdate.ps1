param (
	[string[]] 
	# names of WSP packages to update (defaults to UI, Rendering, and Authoring)
	$packageName=("MS.IT.MBS.CMS.UI.wsp","MS.IT.MBS.CMS.Rendering.wsp","MS.IT.MBS.CMS.Authoring.wsp"),
	[string] 
	# literal path of directory holding the packages (defaults to .\drop\WSP from the script location)
	$literalPath="$(&{Split-Path $MyInvocation.ScriptName})\drop\WSP",
	[switch] 
	# whether or not to IISReset following the updates
	$postReset=$false,
	[switch] 
	# whether or not to -force the Update-SPSolution
	$force=$false)
Add-PSSnapIn Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue  

function WaitForUpdate($identity, $literalPath="$(&{Split-Path $MyInvocation.ScriptName})\drop\WSP\$identity") {
	$sol = Get-SPSolution -Identity $identity
	Update-SPSolution -Identity $sol -LiteralPath $literalPath -GACDeployment -FullTrustBinDeployment -force:$force
	while ($sol.DeploymentState -eq 'Deploying') { 
		new-object PSObject |
		add-member -pass NoteProperty Identity $identity |
		add-member -pass NoteProperty Now ([DateTime]::Now) |
		add-member -pass NoteProperty DeploymentState $sol.DeploymentState
		sleep 10 
	}
	new-object PSObject |
	add-member -pass NoteProperty Identity $identity |
	add-member -pass NoteProperty Now ([DateTime]::Now) |
	add-member -pass NoteProperty DeploymentState $sol.DeploymentState
}

#iisreset

$packageName | % { WaitForUpdate $_ "$literalPath\$_"}

if ($postReset) {iisreset}

<#
.SYNOPSIS
	Updates the named solution packages in place
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	status messages: which WSP is being updated, the time of the status message, and the current status of the update
.NOTES
	from a set of command lines by Ezaz.Khan@microsoft.com

	copy into drop's parent directory (e.g. CMS_Package5) for correct defaulting while not being deleted during build
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	#from the drop\scripts directory holding your Deploy.ps1
	..\..\EzazRenderingUpdate.ps1

	# updates UI, Authoring, and Rendering packages
.EXAMPLE
	#from the drop\scripts directory holding your Deploy.ps1
	..\..\EzazRenderingUpdate.ps1 MS.IT.MBS.CMS.Rendering.wsp

	# updates just the Rendering package
#>
