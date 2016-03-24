param (
	[Parameter(Mandatory=$true)]
	[string]
	# URL of SPWeb to check if list is GUID or Title string
	$webUrl,
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
	[Object]
	# either [xml], [IO.FileInfo], [string] (path)
	$xml,
	[Parameter(Mandatory=$true)]
	[string]
	# root of directory storing documents/attachments
	$docRoot=$null
)
# check for error causing states
begin {
	[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
	$gc = Start-SPAssignment
	$web = Get-SPWeb $webUrl -ErrorAction Stop -AssignmentCollection $gc
	$tz = $web.RegionalSettings.TimeZone

	$spNamespace = "http://schemas.microsoft.com/sharepoint/"
	$nsmgr = New-Object Xml.XmlNamespaceManager (New-Object Xml.NameTable)
	$nsmgr.AddNamespace("sp", $spNamespace)
	# fixedFieldList holds the 'unmodifiable' internal field names that can be included on file creation
	$fixedFieldList = New-Object 'System.Collections.Generic.List[String]'
	$fixedFieldList.Add("ID")
	$fixedFieldList.Add("Created_x0020_By")
	$fixedFieldList.Add("Created")
	$fixedFieldList.Add("Modified_x0020_By")
	$fixedFieldList.Add("Modified")

	$metadataDictionary = New-Object 'System.Collections.Generic.Dictionary[String,String]'
	$metadataDictionary.Add("Created_x0020_By","vti_author")
	$metadataDictionary.Add("Created","vti_timecreated")
	$metadataDictionary.Add("Modified_x0020_By","vti_modifiedby")
	$metadataDictionary.Add("Modified","vti_timelastmodified")
	
	function CleanUser([string]$stored)
	{
		# remove pipe terminated provider location from user name if present, may not port between machines
		if ($stored.Contains("|")) { $stored = $stored.Split("|",2)[1] }
		return $stored		
	}

	function FieldLookupValueFromSingleValue([string]$storedValue, [Microsoft.SharePoint.SPFieldLookup]$field)
	{
		$targetList = $web.Lists[[Guid]$field.LookupList]
		$query = New-Object Microsoft.SharePoint.SPQuery
		$query.Query = "<Where><Eq><FieldRef Name=""Title""/><Value Type=""Text"">${storedValue}</Value></Eq></Where><OrderBy><FieldRef Name=""ID""/></OrderBy>"
		$items = $targetList.GetItems($query)
		if (($items -eq $null) -or ($items.Count -eq 0)) {
			Write-Warning "Unable to find items in $($targetList.Title).$($field.LookupField) for value '${storedValue}'"
			return $null
		}
		if ($items.Count -gt 1) {
			Write-Warning "Multiple items ($($items.Count)) in $($targetList.Title).$($field.LookupField) for value '${storedValue}'"
			return $null
		}
		New-Object Microsoft.SharePoint.SPFieldLookupValue ($items[0]["ID"]),($items[0]["Title"])
	}
	
	function FieldLookupValuesFromValue([string]$storedValue, [Microsoft.SharePoint.SPFieldLookup]$field)
	{
		$pairs = $storedValue.Split(@(';#'), [StringSplitOptions]::None)
		# ignore even offsets (source ID's) and use odd offsets (values) for generating collection
		if ($pairs.Count -band 1) {
			trap {break;}
			throw "Unpaired values in $storedValue"
		}
		if ($pairs.Count -eq 2) {
			FieldLookupValueFromSingleValue $pairs[1] $field
		} else {
			$i = 0
			$coll = New-Object Microsoft.SharePoint.SPFieldLookupValueCollection
			$pairs |
				%{
					if ($i -band 1) {
						$newVal = FieldLookupValueFromSingleValue $_ $field
						$coll.Add($newVal)
					}
					++$i
				}
			,$coll
		}
	}
	
	function MatchOrNewListItem([Microsoft.SharePoint.SPList]$list, $id)
	{
		$query = New-Object Microsoft.SharePoint.SPQuery
		$query.Query = "<Where><Eq><FieldRef Name=""ID""/><Value Type=""Text"">${id}</Value></Eq></Where>"
		$items = $list.GetItems($query)
		if (($items -eq $null) -or ($items.Count -eq 0)) {
			return $list.Items.Add()
		}
		return $items[0]
	}
	
	function EnsureFolderInDocLib([Microsoft.SharePoint.SPDocumentLibrary]$doclib, [string]$libUrl)
	{
		$libUrl = $doclib.ParentWeb.GetFile($libUrl).Url;
		$i = $libUrl.LastIndexOf("/");
		$parentFolder = $docLib.ParentWeb.RootFolder;
		if ($i -gt -1) {
			$parentFolderUrl = $libUrl.Substring(0,$i)
			$parentFolder = $docLib.ParentWeb.GetFolder($parentFolderUrl)
			if (!$parentFolder.Exists) {
				$current = $parentFolder
				$parentFolderUrl.Split("/") |
					% { $current = $current.SubFolders.Add($_) }
			}
		}
		return $parentFolder
	}
	
	function UploadFile([Microsoft.SharePoint.SPDocumentLibrary]$doclib, [Xml.XmlElement] $fileXml, [int]$id)
	{
		# Try to force ID, or is the name the game? Assuming latter for now
		$nodeUrl = $fileXml.ParentNode.Url
		if ([String]::IsNullOrEmpty($nodeUrl)) {
			$nodeUrl = ""
		} else {
			$nodeUrl = "$nodeUrl/"
		}
		$sourcePath = "$docRoot\$($fileXml.Path)"
		$destUrl = "$nodeUrl$($fileXml.Url)"
		#try {
		#	$file = $web.GetFile($destUrl)
		#	if ($file.CheckOutType -eq [Microsoft.SharePoint.SPFile+SPCheckOutType]::None) {
		#		$file.CheckOut();
		#	}
		#} catch [IO.FileNotFoundException] { } 
		#catch [Microsoft.SharePoint.SPFileCheckOutException] {
		#	write-warning "File $destUrl already checked out ($($_.CheckOutType)) by $($_.CheckedOutBy)"
		#}
		[Void]($destUrl -match "(.*)/([^/]*?)$") ; $destName = $Matches[2]
		Write-Verbose "Pushing `"$sourcePath`" to `"$destUrl`""
		$dataStream = [IO.File]::OpenRead($sourcePath)
		$props = @{}
		$fileXml.Property | % { 
			[Void]$props.Add($_.Name, $_.Value) 
			if ($metadataDictionary.ContainsKey($_.Name)) {
				[Void]$props.Add($metadataDictionary[$_.Name], $_.Value) 
			}
		}
		$folder = EnsureFolderInDocLib $doclib $destUrl
		if (!$props.ContainsKey("Created_x0020_By") -or !$props.ContainsKey("Modified_x0020_By") -or !$props.ContainsKey("Created") -or !$props.ContainsKey("Modified")) {
			$file = $folder.Files.Add($destUrl, $dataStream, $true)
		} else {
			$file = $folder.Files.Add($destUrl, $dataStream, $props, $web.EnsureUser((CleanUser $props["Created_x0020_By"])), $web.EnsureUser((CleanUser $props["Modified_x0020_By"])), [DateTime]$props["Created"], [DateTime]$props["Modified"], "Import-SPDocumentLibraryFromModule", $true)
		}
		$dataStream.Close()
		if ($list.EnableVersioning -and $fileXml.VersionId) {
			$isMajor = $fileXml.VersionLabel.EndsWith(".0")
			# translated from http://jeff-sharepoint-note.blogspot.com/2011/07/publish-and-approve-file.html, major/minor added
	        if ($file.Level -eq [Microsoft.SharePoint.SPFileLevel]::Checkout) {
				if ($isMajor) {
					$file.CheckIn("", [Microsoft.SharePoint.SPCheckinType]::MajorCheckIn)
				} else {
					$file.CheckIn("", [Microsoft.SharePoint.SPCheckinType]::MinorCheckIn)
				}
			}
			if ($file.Level -eq [Microsoft.SharePoint.SPFileLevel]::Draft)  {
				if ($isMajor) {
					if ($file.DocumentLibrary.EnableModeration) { 
						$file.Approve(""); 
					} else { 
						$file.Publish(""); 
					}
				}
			}
		}
		return $file.ListItemAllFields
		
	}
	
	function ImportFileXml([Microsoft.SharePoint.SPDocumentLibrary]$doclib, [Xml.XmlElement] $fileXml)
	{
		# attempt to match ID number if present
		$id = (@($fileXml.Property) | ? { $_.Name -eq "ID" }).Value
		$li = $null
		Do {
			$li = UploadFile $doclib $fileXml $id
			if ($li -eq $null) { Write-Warning "Unable to upload $($fileXml.Url)"; return }
			$liid = 0+$li["ID"] #$li.SystemUpdate() clears the SPListItem
			# fill fields from Row element
			@($fileXml.Property) |
				? { ($_.Name -ne "ID") } |
				% {
					$name = $_.Name
					try {
						$destField = $li.Fields.GetFieldByInternalName($name)
						$stored = $_.Value
						if ($destField -eq $null) {
							$li.File.SetProperty($name, $stored)
						} elseif (![string]::IsNullOrEmpty($stored)) {
							if ([Microsoft.SharePoint.SPFieldType]::User -eq $destField.Type) {
								$li[$name] = $web.EnsureUser((CleanUser $stored))
							} elseif ([Microsoft.SharePoint.SPFieldType]::Lookup -eq $destField.Type) {
								$li[$name] = FieldLookupValuesFromValue $stored $destField
							} elseif ([Microsoft.SharePoint.SPFieldType]::DateTime -eq $destField.Type) {
								$li[$name] = $tz.UtcToLocalTime([DateTime]$stored)
							} elseif (([Microsoft.SharePoint.SPFieldType]::Attachments -eq $destField.Type) -or ($Name -eq 'Attachments')) {
								if (![string]::IsNullOrEmpty($docRoot)) {
									$xAttach = $_
									$sourcePrefix = Join-Path $docRoot $xAttach.UrlPrefix
									$xAttach.Attachment |
										% {
											$t  = $_.InnerText
											if (![string]::IsNullOrEmpty($t)) {
												$p = Join-Path $sourcePrefix $t
												if (!(Test-Path $p)) {
													Write-Warning "Couldn't find file-to-attach $p"
												} else {
													$content = [IO.File]::ReadAllBytes($p)
													try { $li.Attachments.Add($t, $content) } catch { Write-Warning "$($list.Title).$Name ID $id attachment $t threw $_" }
												}
											}
										}
								}
							} else {
								$li[$name] = $stored
							}
						}
					} catch {
						Write-Warning "$($list.Title).$Name assignment in ID $id threw error $_"
					}
				}
			try {
				$li.UpdateOverwriteVersion() # keep version from $file.Update(), just change the metadata
			} catch {
				Write-Warning "$($list.Title)[ID = $id] threw on Update() $_"
			}
			if ((![string]::IsNullOrEmpty($li["ID"])) -and ($li["ID"]+0 -lt $id)) {
				$li.Delete() # purge non-matching line for retry until match or past
			}
		} While (![string]::IsNullOrEmpty($id) -and ($liid -lt $id))
		if ($liid -ne $id) {
			Write-Warning "$($list.Title)[ID = $id] shifted ID to $liid"
		}
	}

	function ImportModuleXml([Xml.XmlElement] $modulexml)
	{
		Write-Verbose "ImportModuleXml $($modulexml.Name)"
		$list = $web.Lists.TryGetList([Convert]::ToString($modulexml.Name))
		if ($list -eq $null) {
			Write-Warning "Could not locate a list titled '$($modulexml.Name)'"
			return
		}
		if (($list -as [Microsoft.SharePoint.SPDocumentLibrary]) -eq $null) {
			Write-Warning "'$($modulexml.Name)' is a list, not a document library"
			return
		}
		$files = @($modulexml.File)
		if ($files[0] -eq $null) { # $rows will always have at least one element, $null if nothing else
			Write-Warning "$(moduleXml.Name) has no data to be added"
		} else {
			$files | % { ImportFileXml $list $_ }
		}
	}
}
process {
	if ($xml -is [xml]) {
		foreach ($node in $xml.SelectNodes("/sp:Elements/sp:Module", $nsmgr)) {
			ImportModuleXml $node
		}
	} elseif ($xml -is [IO.FileInfo]) {
		$xmlDoc = New-Object Xml.XmlDocument
		$xmlDoc.Load($xml.FullName)
		foreach ($node in $xmlDoc.SelectNodes("/sp:Elements/sp:Module", $nsmgr)) {
			ImportModuleXml $node
		}
	} elseif ($xml -is [string]) {
		$xmlDoc = New-Object Xml.XmlDocument
		$xmlDoc.Load($xml)
		foreach ($node in $xmlDoc.SelectNodes("/sp:Elements/sp:Module", $nsmgr)) {
			ImportModuleXml $node
		}
	}
}
end {
	Write-Host "Completed $([DateTime]::Now)"
	Stop-SPAssignment $gc
}
<#
.SYNOPSIS
	Import-SPDocumentLibraryFromModule: Adds doclib contents in Module format to doclib
.DESCRIPTION
	Fills list(s) per XmlDocument in SharePoint Feature schema's Module format.
	Expects lists already exist and match, will error stop if not able to locate field.
.INPUTS
	[xml] document
.OUTPUTS
	none
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Import-SPDocumentLibraryFromModule.ps1 'http://server/web' .\Elements.xml
	dir *Elements.xml | Import-SPDocumentLibraryFromModule.ps1 'http://server/web'
	& 'c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\Import-SPDocumentLibraryFromModule.ps1' 'http://erichstehr/sites/development/FFCDatabase' 'c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\2012-05-04T015941Z\Elements.xml' 'c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\2012-05-04T015941Z'
	Import-SPDocumentLibraryFromModuel.ps1 http://erichstehr/sites/devtesting h:\2012-10-29T163234Z\Elements.xml h:\2012-10-29T163234Z
#>
