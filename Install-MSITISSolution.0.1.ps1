param (
	[string]
	# location of the .wsp file to be installed
	$path,
	[string] 
	# solution (un)install to specific webapplication URL (mutually exclusive to AllWebApplication)
	$WebApplication="",
	[switch] 
	# solution (un)install to all webapplications in farm (mutually exclusive to WebApplication)
	$AllWebApplications=$false,
	[switch] 
	# perform all operations
	$force=$false,
	[switch] 
	# Just remove the solution, not reinstall
	$remove=$false
	)
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
write-debug "AllWebApplications = $AllWebApplications"
write-debug "WebApplication is $(if ('' -ne $WebApplication) {'not '})empty"
if ((("" -eq $WebApplication) -and !$AllWebApplications) -or (("" -ne $WebApplication) -and $AllWebApplications)) {
	trap { break; }
	throw "Need one of '-WebApplication `$url' or '-AllWebApplications', not neither or both!"
}
$script:sleepmilliseconds = 15000
function RemoveSolution($identity)
{
	$errCount = $Error.Count
	if ($AllWebApplications) {
		Uninstall-SPSolution -Identity $identity -AllWebApplications -ea Continue
	} else {
		Uninstall-SPSolution -Identity $identity -WebApplication $WebApplication -ea Continue
	}
	while ((Get-SPSolution -Identity $identity).Deployed) { "Sleeping $($sleepmilliseconds/1000) seconds on solution uninstall...."; [Threading.Thread]::Sleep($sleepmilliseconds) }
	Remove-SPSolution -Identity $identity -force:$force -ea Continue
	while ((Get-SPSolution -Identity $identity -ea SilentlyContinue)) { "Sleeping $($sleepmilliseconds/1000) seconds on solution removal...."; [Threading.Thread]::Sleep($sleepmilliseconds) }
	if ($errCount -eq $Error.count) { iisreset /noforce }
}

$path = resolve-path $path
$identity = (split-path -leaf $path)
#write-debug "`$identity = $identity"
if ($force -or $remove -or (Get-SPSolution -Identity $identity -ea SilentlyContinue))
{
	RemoveSolution($identity)
}
if (!$remove)
{
	Add-SPSolution $path -ea Stop
	while (!(Get-SPSolution -Identity $identity -ea SilentlyContinue)) { "Sleeping $($sleepmilliseconds/1000) seconds on solution add...."; [Threading.Thread]::Sleep($sleepmilliseconds) }
	if ($AllWebApplications) { 
		Install-SPSolution -Identity $identity -AllWebApplications -force:$force -GACDeployment -ea Stop
	} else {
		Install-SPSolution -Identity $identity -WebApplication $WebApplication -force:$force -GACDeployment -ea Stop
	}
	while (!(Get-SPSolution -Identity $identity -ea SilentlyContinue).Deployed) { "Sleeping $($sleepmilliseconds/1000) seconds on solution install...."; [Threading.Thread]::Sleep($sleepmilliseconds) }
	iisreset /noforce
}



<#
.SYNOPSIS
	Install an MSIT-IS solution to the SharePoint farm
.DESCRIPTION
	Installs an MSIT-IS solution to the selected SharePoint farm.  Removes
	existing solution and features beforehand if they are present.
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
#>
