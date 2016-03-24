param (
	[string] 
	# Path to .wsp file being uninstalled
	$path=$(throw "Requires path to .wsp to uninstall"),
	[string] 
	# (local) web application to uninstall from (default: http://<machinename>:80)
	$webApplication=$null,
	[string] 
	# (local) SPweb to disable features at (default: $webApplication)
	$url=$null,
	[switch] 
	# Whether or not to uninstall from all webapplications
	$allWebApplications=$false,
	[switch] 
	# Whether or not to remove the solution
	$onlyDisable=$false
)

#check for SP addin (from SharePoint 2010's Registration.ps1 without set-location)
if (!(get-pssnapin Microsoft.SharePoint.PowerShell -ea SilentlyContinue)) {
	$ver = $host | select version
	if ($ver.Version.Major -gt 1)  {$Host.Runspace.ThreadOptions = "ReuseThread"}
	Add-PsSnapin Microsoft.SharePoint.PowerShell -ea Stop
}

$sleepseconds = 15

function TrimUrlToFeatureScope([string] $url, $identity, $prefix="")
{
	$gc = Start-SPAssignment 
	try {
		$feature = Get-SPFeature -AssignmentCollection $gc -Identity $identity -ErrorAction SilentlyContinue
		if ($null -eq $feature) { write-verbose "Couldn't find Feature $identity" ; return "" }
		$web = Get-SPWeb $url -AssignmentCollection $gc -ErrorAction SilentlyContinue
		if ($null -eq $web) { write-verbose "Couldn't find Web $url for Feature $identity" ; return "" }
		if ($feature.Scope -eq "Web") {
			return "$prefix$($web.Url)"
		} elseif ($feature.Scope -eq "Site") {
			return "$prefix$($web.Site.Url)"
		} else {
			return "" # not needed for feature handling
		} 
	} finally {
		$gc | Stop-SPAssignment
	}
}

$path = Resolve-path $path
$identity = split-path -leaf $path
if ([string]::IsNullOrEmpty($url)) {
	$url = $webApplication.ToString()
	if ([string]::IsNullOrEmpty($url)) {
		$url = "http://$([Environment]::MachineName)" 
	}
}

$webAppSuffix = ""
if ($allWebApplications) {
	$webAppSuffix = " -AllWebApplications"
} elseif (![string]::IsNullOrEmpty($webApplication)) {
	$webAppSuffix = " -WebApplication $($webApplication.ToString())"
}
write-debug $webAppSuffix

$gc = Start-SPAssignment
$solution = get-SPSolution -Identity $identity -ea Stop -AssignmentCollection $gc
Get-SPFeature -AssignmentCollection $gc | where { $_.SolutionID -eq $solution.ID } | 
	% { $exp = "Disable-SPFeature -AssignmentCollection `$gc -Confirm:`$False -Identity '$($_.DisplayName)' $(TrimUrlToFeatureScope $url $_.ID '-Url ')" ; Write-Debug $exp ; Invoke-Expression $exp }
$gc | Stop-SPAssignment

if (!$onlyDisable) {
	$gc = Start-SPAssignment 
	$installCommand = "Uninstall-SPSolution -AssignmentCollection `$gc -Confirm:`$False -Identity $identity"
	Invoke-expression "$installCommand$webAppSuffix" -ea Stop
	while ($($sln = (Get-SPSolution -Identity $identity -ea SilentlyContinue -AssignmentCollection $gc); $sln.Deployed -or $sln.JobExists)) {
		"Sleeping $sleepseconds seconds on solution uninstall..."
		Start-Sleep $sleepseconds
	}

	Remove-SPSolution -AssignmentCollection $gc -Confirm:$False -Identity $identity -ea Stop
	while ((Get-SPSolution -Identity $identity -ea SilentlyContinue -AssignmentCollection $gc)) {
		"Sleeping $sleepseconds seconds on solution remove..."
		Start-Sleep $sleepseconds
	}
	$gc | Stop-SPAssignment
}
""
"Completed $([DateTime]::Now.ToString())"
<#
.SYNOPSIS
	Uninstall .wsp SharePoint solution file from local farm
.DESCRIPTION
	.wsp files contain Features, so it's necessary to Disable the contained
	features from their SPWebs / SPSites / SPWebApplications / SPFarms, 
	Uninstall the solution from the appropriate web application, and
	Remove the solution.  This script consolidates that collection of
	commands.
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Powershell -nologo -noprofile -command "& {& '$(split-path $profile)\Uninstall-Solution.ps1' -path '$(ScriptRoot)\ffcdatabase.wsp' -url http://erichstehr/sites/devtesting/ffc}"
#>

