param (
	[parameter(Mandatory=$true)]
	[string]
	# location of the .wsp file to be installed
	$path=$(throw "Requires path to the .wsp file to be installed"),
	[parameter(Mandatory=$true)]
	[string] 
	# solution webapplication URL to install/uninstall at
	$WebApplication=$(throw "Requires webapplication URL to install/uninstall at"),
	[switch] 
	# perform all operations
	$force=$false,
	[switch] 
	# Just remove the solution, not reinstall
	$remove=$false,
	[switch] 
	# Before removing, find and delete the .webpart and .dwp files installed by the features
	$PurgeWebparts=$false,
	[switch] 
	# Before removing, find and delete all files installed by the features (will damage lists/sites based on any contained definitions)
	$PurgeAll=$false
	)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
if (!$WebApplication.StartsWith("http://") -and !$WebApplication.StartsWith("https://")) {
	trap { break;}
	throw "WebApplication needs to be a URL, starting with http:// or https://"
}

$script:sleepseconds = 15

function PurgeSolutionFiles($solution)
{
	# algorithm from http://msdn.microsoft.com/en-us/library/ff899327(office.12).aspx
	# expanded to occur before removal, handle multiple features, and tweaks for -purge* switches
	if (!$PurgeWebparts -and !$PurgeAll) { return } # Nothing to do....

	Get-SPFeature | where { $_.SolutionID -eq $solution.ID } |
	ForEach-Object {
		$feature = $_
		foreach ($webapp in $solution.DeployedWebApplications)
		{
			foreach ($site in $webapp.Sites)
			{
				$featureXml = $feature.GetXmlDefinition($site.RootWeb.Locale)
				$featureXml.ElementManifests.ElementManifest |
					ForEach-Object { $_.Location } |
					ForEach-Object { [IO.Path]::Combine($feature.RootDirectory, $_) } |
					ForEach-Object { 
						$elementXml = new-object Xml.XmlDocument
						$elementXml.Load($_)
						# note that def:File is always contained in a def:Module, and def:Module's aren't self-containing in the module.xml schema used for the elements
						Select-Xml -xml $elementXml -xpath "//def:Module" -namespace @{def='http://schemas.microsoft.com/sharepoint/'} |
							ForEach-Object { 
								$moduleXml = $_.Node
								$baseUrl = new-object Uri @((new-object Uri $site.RootWeb.Url), "$($moduleXml.Url)\")
								Select-Xml -xml $moduleXml -xpath "//def:File" -namespace @{def='http://schemas.microsoft.com/sharepoint/'} |
									ForEach-Object { 
										$fileXml = $_.Node
										if ($PurgeAll -or 
											($PurgeWebparts -and ($fileXml.Url -match '\.(dwp|webpart)$'))
											) {
											$fileUrl = new-object Uri @($baseUrl, $fileXml.Url)
											[string]$fileUrl
											$file = $site.RootWeb.GetFile([string]$fileUrl)
											if ($file.Exists) { $file.Delete() }
										}
									}
							}
					}
			}
			Disable-SPFeature -Identity $feature -Url $WebApplication

		}
	}
}
# PurgeSolutionFiles($solution)

function RemoveSolution($identity)
{
	$solution = (Get-SPSolution -identity $identity -ea SilentlyContinue)
	if ($null -eq $solution) { return; } # nothing to be removed.... 

	PurgeSolutionFiles($solution)
	$errCount = $Error.Count

	Uninstall-SPSolution -Identity $identity -WebApplication $WebApplication -ea Continue
	while ((Get-SPSolution -Identity $identity).Deployed) { "Sleeping $sleepseconds seconds on solution uninstall...."; Start-Sleep $sleepseconds }
	
	Remove-SPSolution -Identity $identity -force:$force -ea Continue
	while ((Get-SPSolution -Identity $identity -ea SilentlyContinue)) { "Sleeping $sleepseconds seconds on solution removal...."; Start-Sleep $sleepseconds }
	
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
	while (!(Get-SPSolution -Identity $identity -ea SilentlyContinue)) { "Sleeping $sleepseconds seconds on solution add...."; Start-Sleep $sleepseconds }
	Install-SPSolution -Identity $identity -WebApplication $WebApplication -force:$force -GACDeployment -ea Stop
	while (!(Get-SPSolution -Identity $identity -ea SilentlyContinue).Deployed) { "Sleeping $sleepseconds seconds on solution install...."; Start-Sleep $sleepseconds }
	iisreset /noforce
	"Solution installed but features are not enabled!"
	"To enable all features from this solution:"
	"`n`rGet-SPFeature | where { `$_.SolutionID -eq (Get-SPSolution -identity '$identity').ID } | Enable-SPFeature -Url '$WebApplication'"
}



<#
.SYNOPSIS
	Install an MSIT-IS solution to the SharePoint farm
.DESCRIPTION
	Installs an MSIT-IS solution to the selected SharePoint WebApplication.  Removes
	existing solution and features beforehand if they are present.
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
#>
