param (
	[Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
	[Object]
	# either SPDocumentLibrary, string Title or GUID id
	$list,
	[string]
	# URL of parent SPWeb to (if $list is GUID or Title string); reset if SPDocumentLibrary passed
	$webUrl=$null,
	[string]
	# root of directory storing documents
	$docRoot=$(join-path $pwd "$(([DateTime]::Now).ToUniversalTime().ToString("s") -replace ':','')Z")
)
# check for error causing states
begin {
	[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
	$web = $null
	if (![string]::IsNullOrEmpty($webUrl)) {
		$web = Get-SPWeb $webUrl
	}
	$tz = $null # $web.RegionalSettings.TimeZone

	$spNamespace = "http://schemas.microsoft.com/sharepoint/"
	$exportDoc = [xml]'<Elements xmlns="http://schemas.microsoft.com/sharepoint/" xmlns:spf="http://schemas.microsoft.com/sharepoint/"></Elements>'
	$nt = $exportDoc.NameTable
	$wc = New-Object System.Net.WebClient
	$wc.UseDefaultCredentials = $true
	# fixedFieldList holds the 'unmodifiable' internal field names that can be included on file creation
	$fixedFieldList = New-Object 'System.Collections.Generic.List[String]'
	$fixedFieldList.Add("ID")
	$fixedFieldList.Add("Created_x0020_By")
	$fixedFieldList.Add("Created")
	$fixedFieldList.Add("Modified_x0020_By")
	$fixedFieldList.Add("Modified")
	

	function VerifyDirectory([string]$path, [switch]$isFile=$false)
	{
		if ($isFile) {
			$path = Split-Path -Parent $path
		}
		if (!(Test-Path $path)) {
			[void](md $path)
		}
	}
	
	function ExportListItem($li, [Xml.XmlElement] $rows)
	{
		$row = $rows.AppendChild($exportDoc.CreateElement("File", $spNamespace))
		
		$url = $li.Url # contains versionId for SPListItemVersion
		$dest = ($url -replace '/','\')
		[Void]$row.SetAttribute("Path", $dest)
		[Void]$row.SetAttribute("Url", ($url -replace '_vti_history/\d*/',''))
		[Void]$row.SetAttribute("Type", "GhostableInLibrary")
		if ($li -is [Microsoft.SharePoint.SPListItemVersion]) {
			[Void]$row.SetAttribute("VersionId", $li.VersionId)
			[Void]$row.SetAttribute("VersionLabel", $li.VersionLabel)
		}
		
		VerifyDirectory "$docRoot\$dest" -isFile
		$wc.DownloadFile("$($web.Url)/$($li.Url)", "$docRoot\$dest")
		
		$li.Fields |
			? { ((!$_.Hidden) -and (!$_.ReadOnlyField)) -or ($fixedFieldList.Contains($_.internalName))  } |
			% {
				if (![string]::IsNullOrEmpty([Convert]::ToString($li[$_.InternalName]))) {
					$elem = $row.AppendChild($exportDoc.CreateElement("Property", $spNamespace))
					[void]$elem.SetAttribute("Name", $_.InternalName)
					$field = $li.Fields.GetFieldByInternalName($_.InternalName)
					$dataType = $field.Type
					if ([Microsoft.SharePoint.SPFieldType]::User -eq $field.Type) {
						[void]$elem.SetAttribute("Type", "string")
						[void]$elem.SetAttribute("Value", $field.GetFieldValue($li[$_.InternalName]).User)
					#} elseif ([Microsoft.SharePoint.SPFieldType]::Lookup -eq $field.Type) {
					#	#skip this: we need the multiple entries, but we must remember to re-process for correct ID values in dest
					#	[void]$elem.AppendChild($exportDoc.CreateTextNode($field.GetFieldValue($li[$_.InternalName]).LookupValue))
					} elseif ([Microsoft.SharePoint.SPFieldType]::File -eq $field.Type) {
						[Void]$elem.ParentNode.RemoveChild($elem) # name already handled
					} elseif ([Microsoft.SharePoint.SPFieldType]::Attachments -eq $field.Type) {
						[Void]$elem.ParentNode.RemoveChild($elem) # attachments not allowed in doclib
					} elseif ([Microsoft.SharePoint.SPFieldType]::Computed -eq $field.Type) {
						[Void]$elem.ParentNode.RemoveChild($elem) # skip it
					} elseif (([Microsoft.SharePoint.SPFieldType]::Integer -eq $field.Type) -or
							([Microsoft.SharePoint.SPFieldType]::Counter -eq $field.Type)
							) {
						[void]$elem.SetAttribute("Type", "int")
						[void]$elem.SetAttribute("Value", $field.GetFieldValue($li[$_.InternalName]))
					} elseif ([Microsoft.SharePoint.SPFieldType]::DateTime -eq $field.Type) {
						[void]$elem.SetAttribute("Type", "DateTime")
						if ($li.Fields[$_.InternalName].DisplayFormat -eq [Microsoft.SharePoint.SPDateTimeFieldFormatType]::DateOnly) {
							[void]$elem.SetAttribute("Value",  "$($li[$_.InternalName]).ToString('yyyy-MM-dd'))")
						} else {
							[void]$elem.SetAttribute("Value",  "$($tz.LocalTimeToUTC($li[$_.InternalName]).ToString('s'))Z")
						}
					} else {
						[void]$elem.SetAttribute("Type", "string")
						[void]$elem.SetAttribute("Value", [Convert]::ToString($li[$_.InternalName]))
					}
				}
			}
	}

	function ExportListInstance([Microsoft.SharePoint.SPDocumentLibrary] $list)
	{
		if ($null -eq $list) { return "Not a document library" }
		$tz = $web.RegionalSettings.TimeZone
		$listinstance = $exportDoc.DocumentElement.AppendChild($exportDoc.CreateElement("Module", $spNamespace))
		[void]$listinstance.SetAttribute("List", 101)
		[void]$listinstance.SetAttribute("Name", $list.Title)
		#[void]$listinstance.SetAttribute("Url", $list.RootFolder.Url)
		if ($list.DataSource -ne $null) {
			write-warning "Script does not yet handle lists with datasources, $($list.Title) has versioning active and will not be handled" 
			[void]$listinstance.AppendChild($exportDoc.CreateComment("Can't handle lists with datasources yet!"))
		} else {
			if ($list.EnableVersioning) { 
				$list.Items |
					% { 
						$vers = @($_.Versions) # $vers is, at this point, in reverse chronological order (newest to oldest)
						[Array]::Reverse($vers)
						$vers # now ordered correctly, pass along
					} |
					% { ExportListItem ([Microsoft.SharePoint.SPListItemVersion]$_) $listinstance }
			} else {
				$list.Items | % { ExportListItem $_ $listinstance }
			}
		}
	}
}
process {
	if ($list -is [Microsoft.SharePoint.SPDocumentLibrary]) {
		$web = $list.ParentWeb
		ExportListInstance $list
	} elseif ($web -ne $null) {
		ExportListInstance $web.Lists[$list]
	}
}
end {
	$exportDoc.Save("$docRoot\Elements.xml")
	$exportDoc
}
<#
.SYNOPSIS
	Export-SPDocumentLibraryToModule: Outputs document library contents as Module Elements.xml file
.DESCRIPTION
	Creates XmlDocument in SharePoint Feature schema's Module format
	for each passed SPDocumentLibrary (slightly extended for versioned library)
.INPUTS
	stream of SPDocumentLibrary's or library names
.OUTPUTS
	[xml] object. If no lists provided, document contains empty Elements element.
	[xml] object is saved to $docRoot\Elements.xml as well as all downloaded files
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Export-SPDocumentLibraryToModule.ps1 "FFCDocuments" -webUrl 'http://erichstehr/sites/development/FFCDatabase' | tidy-xml
	Export-SPDocumentLibraryToModule.ps1 "Documents" -webUrl 'http://erichstehr/sites/devtesting' | tidy-xml
#>
