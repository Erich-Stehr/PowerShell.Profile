[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Target='gcm|ft|dir|\?|select|\%|sort|copy|gp|gv|where|foreach|sleep', Justification="if you're changing standard aliases, folks...")]
[CmdletBinding()]
param([string] $path=("$PWD\app.config"),
  # name of the template, usually the original file basename
  [string] $tName,
  [string] $tAuthor,
  [string] $tShortdesc,
  # just the date in 'yyyy-MM-dd'
  [DateTime] $tDate,
  # template keywords are space separated
  [string] $tKeywords,
  # BaseName of (preferred) 64x64 .svg in ./icons for template icon in UI
  [string] $tIcon 
)
if (!(Test-Path (Resolve-Path $path))) {
	Write-Error "$path doesn't exist!" -ErrorAction Stop
}
$doc = New-Object xml
$doc.PreserveWhitespace = $true # keep what we can of the formatting, XML doesn't consider between-attribute whitespace to possibly be significant
$doc.Load($path)
if ($null -eq $doc.svg) {
	Write-Error "$path isn't an SVG document" -ErrorAction Stop
}
$nsmgr = new-object System.Xml.XmlNamespaceManager $doc.NameTable
# translated from <https://stackoverflow.com/questions/767541/how-i-can-list-out-all-the-namespace-in-xml>
$nav = $doc.CreateNavigator()
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

function CreateElementAtNode($node, $tag) {
    trap {break;}
	$node.AppendChild($node.OwnerDocument.CreateElement($tag))
}

function CreateNsElementAtNode($node, $tag, $nsUrl) {
    trap {break;}
	$node.AppendChild($node.OwnerDocument.CreateElement($tag, $nsUrl))
}

function VerifyElementExists($node, $tag) {
	if ($null -eq $node."$tag") {
		CreateElementAtNode $node $tag
	} else {
		$node."$tag"
	}
}

function VerifyNsElementExists($node, $tag, $nsUrl) {
	$n = $node.SelectSingleNode($tag, $nsmgr)
	if ($null -eq $n) {
		CreateNsElementAtNode $node $tag $nsUrl
	} else {
		$n
	}
}

function VerifyAttributeExists($elem, $name, $defaultValue) {
	if (!$elem.HasAttribute($name)) {
		$elem.SetAttribute($name, $defaultValue)
	}
}

function VerifyNsAttributeExists($elem, $name, $nsUrl, $defaultValue) {
	if (!$elem.HasAttribute($name, $nsUrl)) {
		$elem.SetAttribute($name, $nsUrl, $defaultValue)
	}
}

$root = $doc.ChildNodes | ? { $_.NodeType -eq [System.Xml.XmlNodeType]::Element } # we want the root element, not the XML declaration or String.Empty; if the root is empty, .configuration is String.Empty

if ($root.Name -ne 'svg')
{
	Write-Error "$path root isn't SVG, it's $($root.Name)" -ErrorAction Stop
}
$inkNsUrl = "http://www.inkscape.org/namespaces/inkscape"
#$svgNsUrl = "http://www.w3.org/2000/svg"

Write-Verbose "inkscape:templateinfo"
$templateInfo = VerifyNsElementExists $root "inkscape:templateinfo" $inkNsUrl
Write-Verbose ($null -eq $templateInfo)
Write-Verbose $templateInfo.get_OuterXml()

# Write-Verbose "test attributes"
# VerifyAttributeExists $templateInfo "data-test1" "1"
# $null = VerifyNsAttributeExists $templateInfo "data-script2" $svgNsUrl "2"
# Write-Verbose $templateInfo.get_OuterXml()

$xName = VerifyNsElementExists $templateInfo "inkscape:name" $inkNsUrl
if ([string]::IsNullOrEmpty($xName.get_InnerText())) {$xName.set_InnerText($tName)}
$xAuthor = VerifyNsElementExists $templateInfo "inkscape:author" $inkNsUrl
if ([string]::IsNullOrEmpty($xAuthor.get_InnerText())) {$xAuthor.set_InnerText($tAuthor)}
$xShortDesc = VerifyNsElementExists $templateInfo "inkscape:shortdesc" $inkNsUrl
if ([string]::IsNullOrEmpty($xShortDesc.get_InnerText())) {$xShortDesc.set_InnerText($tShortDesc)}
$xDate = VerifyNsElementExists $templateInfo "inkscape:date" $inkNsUrl
if ([string]::IsNullOrEmpty($xDate.get_InnerText())) {$xDate.set_InnerText(([DateTime]$tDate).ToString('yyyy-MM-dd'))}
$xKeywords = VerifyNsElementExists $templateInfo "inkscape:keywords" $inkNsUrl
if ([string]::IsNullOrEmpty($xKeywords.get_InnerText())) {$xKeywords.set_InnerText($tKeywords)}
$xIcon = VerifyNsElementExists $templateInfo "inkscape:icon" $inkNsUrl
if ([string]::IsNullOrEmpty($xIcon.get_InnerText())) {$xIcon.set_InnerText($tIcon)}


Write-Verbose $doc.get_OuterXml()
move $path "$path.bak" -ea SilentlyContinue
$doc.Save($path)

<#
.SYNOPSIS
	Verifies the inkscape:templateinfo element contents in an Inkscape .svg file
.DESCRIPTION
	Takes the arguments and uses those to fill in _missing_ elements in an
	Inkscape template file's inkscape:templateinfo element, especially the
	inkscape:icon element.

	Almost a throwaway, but does demonstrate XML namespace handling in PoSH.
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Verify-InkscapeTemplateinfo.ps1 -v '.\with pen strokes.svg' -tIcon "with pen strokes"
#>
