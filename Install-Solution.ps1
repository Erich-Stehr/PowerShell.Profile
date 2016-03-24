param (
	[string] 
	# Path to .wsp file being installed
	$path=$(throw "Requires path to .wsp to install"),
	[string] 
	# (local) web application to install to (default: http://<machinename>:80)
	$webApplication=$null,
	[string] 
	# (local) SPweb to enable features at (default: $webApplication)
	$url=$null,
	[switch] 
	# Whether or not to install to all webapplications
	$allWebApplications=$false,
	[switch] 
	# Whether or not to prevent enabling at $url
	$noEnable=$false,
	[switch] 
	# Whether or not to prevent enabling at $url
	$onlyEnable=$false
)

#check for SP addin (from SharePoint 2010's Registration.ps1 without set-location)
if (!(get-pssnapin Microsoft.SharePoint.PowerShell -ea SilentlyContinue)) {
	$ver = $host | select version
	if ($ver.Version.Major -gt 1)  {$Host.Runspace.ThreadOptions = "ReuseThread"}
	Add-PsSnapin Microsoft.SharePoint.PowerShell -ea Stop
}

function TrimUrlToFeatureScope([string] $url, $identity, $prefix="")
{
	$gc = Start-SPAssignment 
	try {
		$feature = Get-SPFeature -AssignmentCollection $gc -Identity $identity -ErrorAction Stop
		$web = Get-SPWeb $url -AssignmentCollection $gc -ErrorAction Stop
		if ($feature.Scope -eq "Web") {
			return "$prefix$($web.Url)"
		} elseif ($feature.Scope -eq "Site") {
			return "$prefix$($web.Site.Url)"
		} else {
			return "" # not needed for feature handling
		} 
	} finally {
		Stop-SPAssignment $gc
	}
}

$sleepseconds = 15

$path = Resolve-path $path
$identity = split-path -leaf $path

if (!$onlyEnable) {
	$gc = Start-SPAssignment 
	Add-SPSolution $path -ea Stop -AssignmentCollection $gc
	while (!(Get-SPSolution -Identity $identity -ea SilentlyContinue -AssignmentCollection $gc)) {
		"Sleeping $sleepseconds seconds on solution add..."
		Start-Sleep $sleepseconds
	}
	if ((Get-PSSnapin microsoft.sharepoint.powershell).Version.major -lt 15) {
		$installCommand = "Install-SPSolution -Identity $identity -CASPolicies -GACDeployment -ea Stop -AssignmentCollection `$gc"
	} else {
		# -CASPolicies go away with 2013 aka v15
		$installCommand = "Install-SPSolution -Identity $identity -GACDeployment -ea Stop -AssignmentCollection `$gc"
	}
	if ($allWebApplications) {
		$installCommand = $installCommand + " -AllWebApplications"
	} elseif (![string]::IsNullOrEmpty($webApplication)) {
		$installCommand = $installCommand + " -WebApplication " + $webApplication.ToString()
	}
	write-debug $installCommand
	Invoke-expression $installCommand
	while ($($sln = (Get-SPSolution -Identity $identity -ea SilentlyContinue -AssignmentCollection $gc); !($sln.Deployed) -or $sln.JobExists)) {
		"Sleeping $sleepseconds seconds on solution install..."
		Start-Sleep $sleepseconds
	}
	Stop-SPAssignment $gc
	iisreset /noforce
}
""
if ([string]::IsNullOrEmpty($url)) {
	if ($null -ne $WebApplication) { 
		$url = $webApplication.ToString() 
	} else { 
		$url = "http://$([Environment]::MachineName)" 
	} 
}
if (!$noEnable) {
	$gc = Start-SPAssignment 
	Get-SPFeature -AssignmentCollection $gc | 
		where { $_.SolutionID -eq (Get-SPSolution -id "$identity" -AssignmentCollection $gc).ID } | 
		%{ $exp = "Enable-SPFeature -Identity $($_.ID) -AssignmentCollection `$gc $(TrimUrlToFeatureScope $url $_.ID ' -Url ')"; Write-Debug $exp ; Invoke-Expression $exp }
	'Features enabled!'
	Stop-SPAssignment $gc
} else {
"Solution installed but features not enabled."
"To enable features:"
""
"Get-SPFeature | where { `$_.SolutionID -eq (Get-SPSolution -id '$identity').ID } |"
"`tEnable-SPFeature -Url ${Url}..."
}
""
"Completed $([DateTime]::Now.ToString())"
<#
.SYNOPSIS
	Install .wsp SharePoint solution file to local farm
.DESCRIPTION
	.wsp files contain Features, so it's necessary to Add the solution, Install
	it to the appropriate web application, then enable the contained Features
	at the correct locations.  This script consolidates that collection of
	commands to one or two, depending on -noEnable.
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Powershell -nologo -noprofile -command "& {& '$(split-path $profile)\Install-Solution.ps1' -path '$(ScriptRoot)\ffcdatabase.wsp' -url http://erichstehr/sites/devtesting/ffc}"
#>
