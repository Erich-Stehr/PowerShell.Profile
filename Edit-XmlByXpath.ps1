[CmdletBinding(ConfirmImpact='None',SupportsShouldProcess=$true)]
#[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
param (
    [Parameter(Mandatory=$true)]
    [string]
    # XPath required to allow file changes
    $IncludeXPath=$("/"),
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [IO.FileInfo]
	# file(s) to be changed
    $file,
	[Parameter(Mandatory=$true)]
    [HashTable]
	# Keys are XPaths, Values are ScriptBlocks to be executed on the matching XML nodes (passed as $_)
    $Changes,
	[switch]
	$force=$false
	)
Begin {
	$xdoc = [xml]"<root/>"
	$yesToAll = $false
	$noToAll = $false
}
Process {
 	try {
		if ($_ -ne $null) {$file = $_}
		Write-Verbose $file.FullName
		$xdoc.Load($file.FullName)
		if ($xdoc.SelectSingleNode($IncludeXPath)) {
			$Changes.Keys | %{
				$key = $_
				$block = $Changes[$key];
				$xdoc.SelectNodes($key) | % $block
			}
		   if ($pscmdlet.ShouldProcess($file.FullName)) {
				if ($force -or $pscmdlet.ShouldContinue("Edit?", $file.Name, [ref]$yesToAll, [ref]$noToAll)) {
					$name = $file.FullName
					$file.MoveTo($name+".bak")
					$xdoc.Save($name)
				}
			}
		}
	} catch {
		write-Output $_
	}
}
End {
}

<#
.SYNOPSIS
	Edit XML documents per XPath changes
.DESCRIPTION
	
.INPUTS
	System.IO.FileInfo
.OUTPUTS
	changes in specified files
.COMPONENT	
	Microsoft.PowerShell
.EXAMPLE
	PS> dir *-scr-req.xml | Edit-XmlByXpath.ps1 -IncludeXPath "//Engine[text()='Monarch.EQSBS']" -Changes @{"/Batch/Jobs/Job/JobOptions"={$_.InnerText = $_.InnerText -replace 'nretryunstable=1','nretryunstable=0'}} -confirm:$false -force

	Takes the *-scr-req.xml files from the current directory, and only in the files that have <Engine>Monarch.EQSBS</Engine> changes the JobOptions where nretryunstable=1 to =0. Doesn't request confirmations.
#>
