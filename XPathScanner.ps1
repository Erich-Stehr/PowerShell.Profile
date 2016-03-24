param (
    [Parameter(Mandatory=$true)]
    [string[]]
    # XPath(s) to locate
    $xpath=$(throw "Requires XPath(s) to locate"),
    [HashTable]
    # Namespaces keyed on prefix to use in XPath(s), needed if files are namespaced
    $Namespaces=@{},
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [IO.FileInfo]
    $file,
	[switch]
	# Whether or not to attach a property FilePath (containing the source file's FullName) to the XmlNode's being output 
	$attachFilePath=$false
    )
Begin {
	$xdoc = [xml]"<root/>"
}
Process {
	try {
		if ($_ -ne $null) {$file = $_}
		Write-Verbose $file.FullName
		$xdoc.Load($file.FullName)
		$nsm = new-object Xml.XmlNamespaceManager $xdoc.NameTable
		if ($Namespaces.Count -gt 0) {
			$Namespaces.GetEnumerator() |
				% { [void]$nsm.AddNamespace($_.Key, $_.Value) }
		}
		$xpath |
			% { 
				$xdoc.SelectNodes($_, $nsm) |
					% {
						if ($attachFilePath) {
							$_ | Add-Member -NotePropertyName FilePath -NotePropertyValue $file.FullName -PassThru
						} else {
							$_
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
        Given stream of xml files and xpath(s), return the selected nodes
.INPUTS
        FileInfo
.OUTPUTS
        XmlNode
		On Verbose, filenames
.EXAMPLE
		dir -rec -filter ScraperService.exe.* | ? { $_.Fullname -notmatch 'obj|test|bin' } | XpathScanner.ps1 -verbose '//Engine[contains(@title,".EQ")][@scraper="WebScraper"]','//Engine[contains(@title,".EQ")][@scraper="ExternalScraper"][./ExternalScraper[@protocol!="EQ"]]'

	Find all ".EQ" Engine's with either scraper=WebScraper or both scraper=ExternalScraper and protocol is not 'EQ' with full file path on verbose stream

.EXAMPLE
		dir -rec -filter ScraperService.exe.* | ? {$_.FullName -notmatch "test|obj|bin" } | XpathScanner.ps1 -attachFilePath -verbose -xpath '//Engine[contains(@title,''Bing'') or contains(@Title,''Monarch'')][.//WebSource[not(contains(@urlPattern,''relehelp'') or contains(@urlPattern,''.svc'') or contains(@urlPattern,''IGNORE''))]]' | select title,@{n='path';e={(split-path -Leaf $_.FilePath)}}

	Find all Bing or Monarch Engine's without relehelp in the urlPattern of the WebSource (unless the urlPattern is for an inflexible service endpoint or to be IGNOREd), show engine title and file name with full file path on verbose stream

.EXAMPLE
		dir "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\ItemTemplates" -rec -filter *.vstemplate | XpathScanner.ps1 -attachFilePath '//vs:*[contains(text(),".ts")]' -Namespaces @{'vs'='http://schemas.microsoft.com/developer/vstemplate/2005'} | fl FilePath,OuterXml

	Find the elements controlling .ts files in the VS2013 ItemTemplates *.vstemplate files
#>