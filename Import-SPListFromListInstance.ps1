param (
	[Parameter(Mandatory=$true)]
	[string]
	# URL of SPWeb to check if list is GUID or Title string
	$webUrl,
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
	[Object]
	# either [xml], [IO.FileInfo], [string] (path)
	$xml,
	[string]
	# root of directory storing documents/attachments (optional)
	$docRoot=$null
)
# check for error causing states
begin {
	trap { if ($gc) { stop-spassignment $gc }; break; }
	[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
	$gc = Start-SPAssignment
	$web = Get-SPWeb $webUrl -ErrorAction Stop -AssignmentCollection $gc
	. {
		trap { break; }
		if ($web -eq $null) { 
			throw "No web returned from $webUrl"
		}

		if (($web.Lists -eq $null) -or ($web.Lists.Count -eq 0)) { 
			throw "No lists in web $webUrl"
		}
	}

	$spNamespace = "http://schemas.microsoft.com/sharepoint/"
	$nsmgr = New-Object Xml.XmlNamespaceManager (New-Object Xml.NameTable)
	$nsmgr.AddNamespace("sp", $spNamespace)

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
	
	function ImportListItem([Microsoft.SharePoint.SPList]$list, [Xml.XmlElement] $row)
	{
		# attempt to match ID number if present
		$id = ($row.Field | ? { $_.Name -eq "ID" }).InnerText
		$li = $null
		Do {
			$li = MatchOrNewListItem $list $id
			# fill fields from Row element
			$row.Field |
				? { ($_.Name -ne "ID") } |
				% {
					$name = $_.Name
					try {
						$destField = $li.Fields.GetFieldByInternalName($name)
						$stored = $_.InnerText
						if (![string]::IsNullOrEmpty($stored)) {
							if ([Microsoft.SharePoint.SPFieldType]::User -eq $destField.Type) {
								if ( $destField.TypeAsString -ne 'UserMulti') {
									$li[$name] = $web.EnsureUser((CleanUser $stored))
								} else {
									$userNames = $stored.Split("`n");
									$valColl = New-Object Microsoft.SharePoint.SPFieldUserValueCollection
									$userNames | 
										% {
											if (-not [string]::IsNullOrEmpty($_)) {
												$spuser = $web.EnsureUser((CleanUser $_))
												$userVal = New-Object Microsoft.SharePoint.SPFieldUserValue @($web, $spuser.ID, $spUser.Name)
												$valColl.Add($userVal)
											}
										}
									$li[$name] = $valColl
								}
							} elseif ([Microsoft.SharePoint.SPFieldType]::Lookup -eq $destField.Type) {
								$li[$name] = FieldLookupValuesFromValue $stored $destField
							} elseif ([Microsoft.SharePoint.SPFieldType]::DateTime -eq $destField.Type) {
								$li[$name] = [DateTime]$stored
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
				$li.Update()
				if ($list.EnableModeration) {
					$t = $li["Created"]
					$li.ModerationInformation.Status = [Microsoft.SharePoint.SPModerationStatusType]::Approved
					$li["Created"]=$t
					$li.UpdateOverwriteVersion()
				}
				# handle versioning, if present, by deleting all but first on first version
				if (($list.EnableVersioning) -and ($row.VersionId -eq 512)) {
					$li.Versions.DeleteAll()
				}
			} catch {
				Write-Warning "$($list.Title)[ID = $id] threw on Update() $_"
			}
			if ($li["ID"]+0 -lt $id) {
				$li.Delete() # purge non-matching line for retry until match or past
			}
		} While (![string]::IsNullOrEmpty($id) -and ($li["ID"]+0 -lt $id))
		if ($li["ID"]+0 -ne $id) {
			Write-Warning "$($list.Title)[ID = $id] shifted ID to $($li['ID'])"
		}
	}

	function ImportListInstance([Xml.XmlElement] $listInstance)
	{
		Write-Verbose "ImportListInstance $($listInstance.Title)"
		$lists = new-object "System.Collections.Generic.Dictionary[string,[Microsoft.SharePoint.SPList]]"
		0..$($web.Lists.Count-1) | % { $list = $web.Lists[$_]; $lists[$list.Title]=[Microsoft.SharePoint.SPList]$list }
		Write-Verbose "List count: $($lists.Count)"
		#$list = $web.Lists.TryGetList([Convert]::ToString($listInstance.Title))
		$list = $lists[$listInstance.Title]
		if ($list -eq $null) {
			Write-Warning "Could not locate a list titled '$($listInstance.Title)'"
			return
		}
		$rows = @($listInstance.Data.Rows.Row)
		if ($rows[0] -eq $null) { # $rows will always have at least one element, $null if no Row exists
			Write-Warning "$($listInstance.Title) has no data to be added"
		} else {
			$rows | % { ImportListItem $list $_ }
		}
	}
}
process {
	if ($xml -is [xml]) {
		foreach ($node in $xml.SelectNodes("/sp:Elements/sp:ListInstance", $nsmgr)) {
			ImportListInstance $node
		}
	} elseif ($xml -is [IO.FileInfo]) {
		$xmlDoc = New-Object Xml.XmlDocument
		$xmlDoc.Load($xml.FullName)
		foreach ($node in $xmlDoc.SelectNodes("/sp:Elements/sp:ListInstance", $nsmgr)) {
			ImportListInstance $node
		}
	} elseif ($xml -is [string]) {
		$xmlDoc = New-Object Xml.XmlDocument
		$xmlDoc.Load($xml)
		foreach ($node in $xmlDoc.SelectNodes("/sp:Elements/sp:ListInstance", $nsmgr)) {
			ImportListInstance $node
		}
	}
}
end {
	Write-Host "Completed $([DateTime]::Now)"
	Stop-SPAssignment $gc
}
<#
.SYNOPSIS
	Import-SPListFromListInstance: Adds list contents in ListInstance format to lists
.DESCRIPTION
	Fills list(s) per XmlDocument in SharePoint Feature schema's ListInstance format.
	Expects that ID's in Xml (if present) are in sorted order if matching is
	desired.
	Expects lists already exist and match, will error stop if not able to locate field.
.INPUTS
	[xml] document
.OUTPUTS
	none
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Import-SPListFromListInstance.ps1 'http://server/web' .\Elements.xml
	dir *Elements.xml | Import-SPListFromListInstance.ps1 'http://server/web'
	& 'c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\Import-SPListFromListInstance.ps1' 'http://erichstehr/sites/development/FFCDatabase' 'c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\LocalElements.xml'
	& 'c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\Import-SPListFromListInstance.ps1' 'http://erichstehr/sites/development/FFCDatabase' 'c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\LocalWebElements.xml' 'c:\Users\erich Stehr\Documents\Visual Studio 2010\Projects\FFCDatabase\exportAttachments'
#>
