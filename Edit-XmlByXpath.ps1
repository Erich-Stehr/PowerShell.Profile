[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Target='\?|\%', Justification="if you're changing standard aliases, folks...")]
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
	$nsmgr = new-object System.Xml.XmlNamespaceManager $xdoc.NameTable
	$yesToAll = $false
	$noToAll = $false
}
Process {
 	try {
		if ($_ -ne $null) {$file = $_}
		Write-Verbose $file.FullName
		$xdoc.Load($file.FullName)
		$nsmgr = new-object System.Xml.XmlNamespaceManager $xdoc.NameTable
		# translated from <https://stackoverflow.com/questions/767541/how-i-can-list-out-all-the-namespace-in-xml>
		$nav = $xdoc.CreateNavigator()
		while ($nav.MoveToFollowing([Xml.XPath.XPathNodeType]::Element)) {
			$nav.GetNamespacesInScope([Xml.XPath.XPathNamespaceScope]::Local) |
			# filter out empty namespace collections
			? { $_.Count -gt 0 } | %{ 
				# pipeline the collection contents through AddNamespace
				$_.GetEnumerator() | %{ 
					$prefix = $_.Key 
					if ([string]::IsNullOrEmpty($prefix)) {
						$prefix = "DEFAULT"
					}
					$nsmgr.AddNamespace($prefix, $_.Value)
					#Write-Debug "$prefix,$($_.Value)"
				}
			}
		}
		if ($xdoc.SelectSingleNode($IncludeXPath, $nsmgr)) {
			$Changes.Keys | %{
				$key = $_
				$block = $Changes[$key];
				$xdoc.SelectNodes($key, $nsmgr) | % $block
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
	The XPath targets 
.INPUTS
	System.IO.FileInfo
.OUTPUTS
	changes in specified files
.COMPONENT	
	Microsoft.PowerShell
.EXAMPLE
	PS> dir *-scr-req.xml | Edit-XmlByXpath.ps1 -IncludeXPath "//Engine[text()='Monarch.EQSBS']" -Changes @{"/Batch/Jobs/Job/JobOptions"={$_.InnerText = $_.InnerText -replace 'nretryunstable=1','nretryunstable=0'}} -confirm:$false -force

	Takes the *-scr-req.xml files from the current directory, and only in the files that have <Engine>Monarch.EQSBS</Engine> changes the JobOptions where nretryunstable=1 to =0. Doesn't request confirmations.

	PS> (@($null, 1, 2, 3, "what?") | ConvertTo-Xml).Save(".\testobjects.xml")
	PS> dir .\testobjects.xml | Edit-XmlByXpath.ps1 -IncludeXPath "/Objects/Object[1][not(@*)]" -Changes @{"/Objects/Object[3]"={$_.set_InnerText("second")}}

	Creates a testobjects.xml, edits only if the first object has no attributes ($null), and after confirming makes the third object (text 2) now have text "second". An alternate change key would be "/Objects/Object[@Type='System.Int32'][2]", the second Int32 Object of the collection
#>
