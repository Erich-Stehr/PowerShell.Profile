param (
	[Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
	[Object]
	# either SPList, string Title or GUID id
	$list,
	[string]
	# URL of SPWeb to check if list is GUID or Title string
	$webUrl=$null,
	[string]
	# root of directory storing documents/attachments (optional)
	$docRoot=$null # $(join-path $pwd (([DateTime]::Now).ToUniversalTime().ToString("s") -replace ':',''))
)
# check for error causing states
begin {
	[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
	$web = $null
	if (![string]::IsNullOrEmpty($webUrl)) {
		$web = Get-SPWeb $webUrl
	}
	$tz = $null # $web.RegionalSettings.TimeZone # once we have the $web

	$spNamespace = "http://schemas.microsoft.com/sharepoint/"
	$exportDoc = [xml]'<Elements xmlns="http://schemas.microsoft.com/sharepoint/" xmlns:spf="http://schemas.microsoft.com/sharepoint/"></Elements>'
	$nt = $exportDoc.NameTable
	$wc = New-Object System.Net.WebClient
	$wc.UseDefaultCredentials = $true
	$acceptStaticFieldNames = @{"ID"="ID";"Author"="Author"; "Editor"="Editor"; "Created"="Created"; "Modified"="Modified"} # field names to just accept
	
	function VerifyDirectory([string]$path, [switch]$isFile=$false)
	{
		if ($isFile) {
			$path = Split-Path -Parent $path
		}
		if (!(Test-Path $path)) {
			[void](md $path)
		}
	}
	
	function ExportListItem($li, [Xml.XmlElement] $rows, [bool]$isAlreadyUTC=$false)
	{
		$row = $rows.AppendChild($exportDoc.CreateElement("Row", $spNamespace))
		$li.Fields |
			? { ((!$_.Hidden) -and (!$_.ReadOnlyField)) -or ($acceptStaticFieldNames.ContainsKey($_.internalName)) } |
			% {
				$elem = $row.AppendChild($exportDoc.CreateElement("Field", $spNamespace))
				[void]$elem.SetAttribute("Name", $_.InternalName)
				$field = $li.Fields.GetFieldByInternalName($_.InternalName)
				$dataType = $field.Type
				if ([Microsoft.SharePoint.SPFieldType]::User -eq $field.Type) {
					$val = $li[$_.InternalName]
					if (-not [string]::IsNullOrEmpty($val)) {
						if ($val -isnot [Microsoft.SharePoint.SPFieldUserValueCollection]) {
							# SPField.GetFieldValue only returns the first SPFieldUserValue, 
							#  and $li.Item either string or SPFieldUserValueCollection, so 
							#  we have to generate in case there's more than one user to get.
							$val = New-Object Microsoft.SharePoint.SPFieldUserValueCollection @($web, [Convert]::ToString($val))
						}
						if ($val -isnot [Microsoft.SharePoint.SPFieldUserValueCollection]) { 
							Write-Warning "Missing user value(s) in $($li.List.Title).$($field.InternalName) ID=$($li['ID']) $($li.VersionLabel)"
						} else {
							$val | %{
								if ($elem.LastChild.NodeType -eq [Xml.XmlNodeType]::Text) {
									[void]$elem.AppendChild($exportDoc.CreateTextNode("`n"))
								}
								[void]$elem.AppendChild($exportDoc.CreateTextNode($_.User))
							}
						}
					}
				#} elseif ([Microsoft.SharePoint.SPFieldType]::Lookup -eq $field.Type) {
				#	#skip this: we need the multiple entries, but we must remember to re-process for correct ID values in dest
				#	[void]$elem.AppendChild($exportDoc.CreateTextNode($field.GetFieldValue($li[$_.InternalName]).LookupValue))
				} elseif ([Microsoft.SharePoint.SPFieldType]::Attachments -eq $field.Type) {
					if (($li.Attachments -eq $null) -or ($li.Attachments.Count -eq 0)) {
						[Void]$elem.ParentNode.RemoveChild($elem) # skip it, empty
					} else {
						$srcPrefix = $li.Attachments.UrlPrefix
						[Void]$elem.SetAttribute("UrlPrefix", $srcPrefix.Substring($web.Url.Length))
						$destPrefix = Join-Path $docRoot $elem.UrlPrefix
						$li.Attachments | 
							% {
								$attach = $elem.AppendChild($exportDoc.CreateElement("Attachment"))
								[Void]$attach.AppendChild($exportDoc.CreateTextNode([Convert]::ToString($_)))
								#$attach.SetAttribute("Name", $_)
								if (![string]::IsNullOrEmpty($docRoot)) {
									# Download to "$($elem.UrlPrefix)$($attach.Name)"
									#New-Object PSObject -Property @{source="$srcPrefix$_";dest=$(Join-Path $destPrefix $_)} | fl
									$dest = Join-Path $destPrefix $_
									VerifyDirectory $dest -isFile
									Write-Verbose $dest
									$wc.DownloadFile("$srcPrefix$_", $dest)
								}
							}
					}
				} elseif ([Microsoft.SharePoint.SPFieldType]::Computed -eq $field.Type) {
					[Void]$elem.ParentNode.RemoveChild($elem) # skip it
				} elseif ([Microsoft.SharePoint.SPFieldType]::DateTime -eq $field.Type) {
					$posted = $li[$_.InternalName]
					$converted = [Convert]::ToString($posted)
					if ($converted -ne "") {
						if ($field.DisplayFormat -eq [Microsoft.SharePoint.SPDateTimeFieldFormatType]::DateOnly) {
							$converted = ($posted.ToString('yyyy-MM-dd'))
						} else {
							if ($isAlreadyUTC) {
								$converted = "$($posted.ToString('s'))Z"
							} else {
								$converted = "$($tz.LocalTimeToUTC($posted).ToString('s'))Z"
							}
						}
					}
					[void]$elem.AppendChild($exportDoc.CreateTextNode($converted))
				} else {
					[void]$elem.AppendChild($exportDoc.CreateTextNode([Convert]::ToString($li[$_.InternalName])))
				}
			}
			if ($li -is [Microsoft.SharePoint.SPListItemVersion]) {
				$row.SetAttribute("VersionId", $li.VersionId)
				$row.SetAttribute("VersionLabel", $li.VersionLabel)
			}
	}

	function ExportListInstance([Microsoft.SharePoint.SPList] $list)
	{
			$listinstance = $exportDoc.DocumentElement.AppendChild($exportDoc.CreateElement("ListInstance", $spNamespace))
			$tz = $web.RegionalSettings.TimeZone
			[void]$listinstance.SetAttribute("Description", $list.Description)
			[void]$listinstance.SetAttribute("FeatureId", $list.TemplateFeatureId.ToString("B"))
			[void]$listinstance.SetAttribute("Hidden", $(if ($list.Hidden) { "TRUE" } else { "FALSE" }))
			[void]$listinstance.SetAttribute("ID", $list.ID.ToString("B"))
			[void]$listinstance.SetAttribute("TemplateType", [int]$list.BaseTemplate)
			[void]$listinstance.SetAttribute("Title", $list.Title)
			[void]$listinstance.SetAttribute("Url", $list.RootFolder.Url)
			[void]$listinstance.SetAttribute("VersioningEnabled", $(if ($list.EnableVersioning) { "TRUE" } else { "FALSE" }))
			
			if ($list.DataSource -ne $null) {
				[void]$listinstance.AppendChild($exportDoc.CreateComment("Can't handle lists with datasources yet!"))
			} else {
				$data = $listinstance.AppendChild($exportDoc.CreateElement("Data", $spNamespace))
				$rows = $data.AppendChild($exportDoc.CreateElement("Rows", $spNamespace))
				if (!$list.EnableVersioning) {
					$list.Items | % { ExportListItem $_ $rows }
				} else {
					$list.Items | 
						% { 
							# newest version is $versions[0], oldest is $versions[$versions.Count-1]
							$versions = New-Object "System.Collections.ArrayList"
							$_.Versions | %{ [Void]$versions.Add($_) }
							$versions.Reverse() # place in chronological order
							foreach ($ver in $versions) {
								ExportListItem $ver $rows $true
							}
							# for correctness, use versions[0] instead of $_ when versioned
						}
				}
			}
	}
}
process {
	if ($list -is [Microsoft.SharePoint.SPList]) {
		$web = $list.ParentWeb
		ExportListInstance $list
	} elseif ($web -ne $null) {
		ExportListInstance $web.Lists[$list]
	}
}
end {
	$exportDoc
}
<#
.SYNOPSIS
	Export-SPListToListInstance: Outputs list contents in ListInstance format
.DESCRIPTION
	Creates XmlDocument in SharePoint Feature schema's ListInstance format
	for each passed SPList
.INPUTS
	stream of SPLists
.OUTPUTS
	[xml] object. If no lists provided, document contains empty Elements element.
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Export-SPListToListInstance.ps1 $list | tidy-xml
	($web.Lists | ? { !$_.Hidden } | Export-SPListToListInstance.ps1).Save("$pwd\web-Elements.xml")
	($web.Lists["Employees"],$web.Lists["Achievements"],$web.Lists["Projects"],$web.Lists["Awards"],$web.Lists["Rewards"] | & 'c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\Export-SPListToListInstance.ps1' -docRoot 'c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\exportAttachments').Save('c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\LocalWebElements.xml')
#>
