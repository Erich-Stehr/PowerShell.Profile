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
	function CreateNsElementAtNode($node, $tag, $nsUrl) {
		trap {break;}
		$node.AppendChild($node.OwnerDocument.CreateElement($tag, $nsUrl))
	}

	function VerifyNsElementExists($node, $tag, $nsUrl) {
		$n = $node.SelectSingleNode($tag, $nsmgr)
		if ($null -eq $n) {
			CreateNsElementAtNode $node $tag $nsUrl
		} else {
			$n
		}
	}
	function VerifyNsAttributeExists($elem, $name, $nsUrl, $defaultValue) {
		if (!$elem.HasAttribute($name, $nsUrl)) {
			$elem.SetAttribute($name, $nsUrl, $defaultValue)
		}
	}
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
				@($xdoc.SelectNodes($key, $nsmgr)) | % $block
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

	PS> $inkNsUrl = "http://www.inkscape.org/namespaces/inkscape"
	PS> $svgNsUrl = "http://www.w3.org/2000/svg"
	PS> cd $env:APPDATA\Inkscape\templates ; [Environment]::CurrentDirectory=$pwd
	PS> copy ${ExampleTemplate}.svg icons\${ExampleTemplate}.svg
	PS> dir icons\${ExampleTemplate}.svg | Edit-XmlByXpath.ps1 -IncludeXPath "/svg:svg" -Changes @{"/svg:svg"={$_.SetAttribute("width", $svgNsUrl, "64"); $_.SetAttribute("height", $svgNsUrl, "64"); $_.SetAttribute("viewBox", $svgNsUrl, "0 0 63 63"); }} -force
	PS> dir ${ExampleTemplate}.svg | Edit-XmlByXpath.ps1 -IncludeXPath "/svg:svg/inkscape:templateinfo" -Changes @{"/svg:svg/inkscape:templateinfo"={$icon=VerifyNsElementExists $_ "inkscape:icon" $inkNsUrl; $icon.set_InnerText(${ExampleTemplate})}} -force

	sets up namespace urls, copies an example template into the icons subdirectory, clips the new icon width, height, and viewBox to a 64x64 icon from the upper corner (though not changing the viewBox scales the whole image to the width/height), and verifies the template will use the new icon file in the 'New from Template...' dialog box in Inkscape.
	Reminder: an empty inkscape:icon element may break 'New from Template...'.
#>
