param (
	[Parameter(Mandatory=$true)]
	[string] 
	# feed url (assumes WordPress API for Atom format, item order control, and paging )
	$atomUrl,
	[Parameter(Mandatory=$true)]
	[string] 
	# (local) web url of SharePoint blog to import into
	$webUrl,
	[Hashtable] 
	# translation from source author names to local user names
	$mapAuthors = @{},
	[Hashtable] 
	# translation from source Category names to local category names
	$mapCategories = @{},
	[switch] 
	# only accept Categories matching keys in mapCategories
	$requireMappedCategories = $true
	)
# check for error causing states
function ScriptRoot { Split-Path $MyInvocation.ScriptName }
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
& {
	trap {break;}
	if (![System.Reflection.Assembly]::Load("System.Web, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a")) {
		Write-Error "Can't load System.Web!"
	}
	if (!([appdomain]::currentdomain.getassemblies() | ? { $_.GetName().Name -eq "HtmlAgilityPack" })) {
		if ((!(Test-Path "$(ScriptRoot)\HtmlAgilityPack.dll")) -or (![System.Reflection.Assembly]::LoadFrom("$(ScriptRoot)\HtmlAgilityPack.dll"))) {
			Write-Error "Can't load HtmlAgilityPack!"
		}
	}
}


$wc = New-Object System.Net.WebClient
$atomUri = [Uri]$atomUrl
$web = Get-SPWeb -Identity $webUrl -ErrorAction Stop
$Categories = $web.Lists["Categories"]
$Posts = $web.Lists["Posts"]
$Comments = $web.Lists["Comments"]
$Photos = $web.Lists["Photos"]
$query = "feed=atom&order=ASC&orderby=date"

function FixUTF8([string] $s) { $str = new-object IO.MemoryStream ($s.length); $tw = new-object IO.StreamWriter ($str, [Text.Encoding]::GetEncoding(1252)); $tw.Write($s); $tw.Close(); [Text.Encoding]::UTF8.GetString($str.GetBuffer()) }

function InternetDateTime($obj)
{
	if ($obj -is [DateTime]) {
		$obj.ToString("yyyy-MM-ddTHH:mm:ssZ")
	} else {
		$obj
	}
}

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

function ApplyField([Microsoft.SharePoint.SPField]$destField, $stored)
{
	if (![string]::IsNullOrEmpty($stored)) {
		if ([Microsoft.SharePoint.SPFieldType]::User -eq $destField.Type) {
			$stored = $web.EnsureUser((CleanUser $stored))
		} elseif ([Microsoft.SharePoint.SPFieldType]::Lookup -eq $destField.Type) {
			$stored = FieldLookupValuesFromValue $stored $destField
		} elseif ([Microsoft.SharePoint.SPFieldType]::DateTime -eq $destField.Type) {
			$stored = [DateTime]$stored
		}
	}
	,$stored # preserves SPFieldLookupValueCollection if there is one
}

function XmlUnescape($string)
{
	#$string -replace '&lt;','<' -replace '&gt;','>' -replace '&quot;','"' -replace '&apos;',"'" -replace '&amp;','&'
	[System.Web.HTTPUtility]::HtmlDecode((FixUTF8 $string)) # need the literal character entities as well, and UTF8 fixes
}

filter MapUserName([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$name, [Hashtable]$map)
# return $map[$name] if there is one, or $name if there isn't
{
	if ($map[$name] -ne $null) {
		$map[$name]
	} else {
		$name
	}
	
}

function GetAtomText($atomTextConstruct)
# returns properly unescaped text of the passed atomTextConstruct element by ./@type
{
	if ($atomTextConstruct -isnot [Xml.XmlNode]) {
		return $atomTextConstruct # if it isn't an atomTextConstruct, just return it
	}
	if ($atomTextConstruct.type -eq 'xhtml') {
		# we want the innerXml of the one div child element per [RFC4287]3.1.1.3
		$atomTextConstruct.div.InnerXml
	} elseif ($atomTextConstruct.type -eq 'html') {
		# xml-unescape the innertext
		XmlUnescape $atomTextConstruct.InnerText
	} else {
		# we assume it's text, just unescape the innertext
		XmlUnescape $atomTextConstruct.InnerText
	}
}


# in $list, find/create a row matching $hashSearch and update it to $hashData
function SPListAddOrUpdate([Microsoft.SharePoint.SPList]$list, $hashSearch, $hashData)
{
	$queryXml = [xml]"<Query><Where></Where><OrderBy><FieldRef Name=`"ID`" Ascending=`"TRUE`" /></OrderBy></Query>"
	$whereNode = $queryXml.FirstChild.FirstChild
	$hashSearch.Keys | %{
		$destField = $list.Fields.GetFieldByInternalName($_)
		$value = $hashSearch[$_]
		if ($value -is [System.Xml.XmlNode]) {
			$value = GetAtomText $value
		}
		$storeType = $destField.TypeAsString
		if ($destField -is [Microsoft.SharePoint.SPFieldLookup]) {
			$stored = [int]$value # SPQuery needs @LookupId on FieldRef and just numeric value to seek
		} else {
			$stored = ApplyField $destField $value
		}

		$eq = $queryXml.CreateElement("Eq")
		$fr1 = $queryXml.CreateElement("FieldRef")
		$fr1.SetAttribute("Name", $_)
		if ($destField -is [Microsoft.SharePoint.SPFieldLookup]) {$fr1.SetAttribute("LookupId",$true)}
		[Void]$eq.AppendChild($fr1)
		$val1 = $queryXml.CreateElement("Value")
		$val1.SetAttribute("Type", $storeType) 
		$val1.InnerText = [Convert]::ToString((InternetDateTime $stored))
		[Void]$eq.AppendChild($val1)
		if (!$whereNode.FirstChild) {
			[Void]$whereNode.AppendChild($eq)
		} else {
			# wrap previous work in And
			$and = $queryXml.CreateElement("And")
			[Void]$and.AppendChild($eq)
			[Void]$and.AppendChild($whereNode.FirstChild)
			[Void]$whereNode.AppendChild($and)
		}
		Write-Debug $queryXml.get_OuterXml()
	}
	$query = New-Object Microsoft.SharePoint.SPQuery
	$query.Query = $queryXml.FirstChild.get_InnerXml()
	$query.ViewFields = "<FieldRef Name='ID'/>"
	$query.ViewFieldsOnly = $true
	$result = $list.GetItems($query)
	if ($result.Count -lt 1) {
		Write-Warning "New Item in $($list.Title) {$($list.ID)}"
		$result = $list.Items.Add()
	}
	if ($result.Count -ge 1) {
		if ($result.Count -gt 1) {Write-Warning "Search of $($list.Title) {$($list.ID)} resulted in $($result.Count) listitems"}
		$result = $result | select -First 1
		$result = $list.GetItemByIdAllFields($result.ID)
	}
	$hashData.Keys | ? { ($_ -ne $null) -and ($_ -ne 'updated') -and (!$_.StartsWith('__')) } | %{
		$data = ApplyField ($result.Fields.GetFieldByInternalName($_)) $hashData[$_]
		if (($result[$_] -ne $data) -or ($data.GetType() -ne $hashData[$_].GetType())){
			$changed = $true
			$result[$_] = $data
		}
	}
	try {
		$result.Update()
	} catch {
		Write-Error "Exception updating $($list.Title) $($hashSearch['Title']) from $($hashData['__source']): $_"
		return $null
	}
	
	return $result
}

function UpdateBodyForPhotos([string] $body, [Xml.XmlElement] $entry)
{
	#locate base URL 
	$content = $entry.content
	$baseElement = $content
	while (($baseElement.base -eq $null) -and ($baseElement.Name -ne "#document")) {
		$baseElement = $baseElement.ParentNode
	}
	$baseUri = new-object Uri $baseElement.base
	#parse out the HTML
	$html = new-object HtmlAgilityPack.HtmlDocument
	$html.LoadHtml((GetAtomText $content))
	# copy and patch the href/src	
	function UpdateAttribute([HtmlAgilityPack.HtmlNode] $node, $attName) {
		$attVal = $node.GetAttributeValue($attName, "")
		if ($attVal -ne "") {
			if ($attVal.Contains("//")) {
				$sourceUri = New-Object Uri $attVal
			} else {
				$sourceUri = New-Object Uri ($baseUri, $attVal)
			}
			if ($sourceUri.Authority -eq $baseUri.Authority) {
				# if it's not in local Photos
				$rootfld = $Photos.RootFolder
				$destName = $sourceUri.Segments[-1]
				if (![String]::IsNullOrEmpty([IO.Path]::GetExtension($destName))) {
					# only upload files, not links
					$destUrl = "$($rootfld.Url)/$destName"
					$destFile = $null
					try { $destFile = $rootfld.Files[$destUrl] } catch { }
					if ($destFile -eq $null) {
					# 	download source
						try {
							$data = $wc.DownloadData($sourceUri)
						} catch {
							Write-Error "Could not download $($sourceUri.AbsoluteUri): $_"
							return
						}
					#	upload to photos
						try {
							$destFile = $rootfld.Files.Add($destUrl, $data)
						} catch {
							Write-Error "Could not upload $($sourceUri.AbsoluteUri) to $destUrl: $_"
							return
						}
					}
				} elseif ($node.Name -eq "a") { # assuming wordpress comment/view page for photo/attachment, just link to it
					Write-Debug "Repoint: $attVal in $(GetAtomText $entry.title)"
					$imgNode = $node.SelectSingleNode(".//img");
					$destFile = $null
					if ($imgNode -ne $null) {
						$destFile = UpdateAttribute $node.FirstChild 'src'
					}
				} else {
					Write-Warning "Couldn't repoint link '$attVal' in '$(GetAtomText $entry.title)'"
					$destFile = $null
				}
				# patch the Uri to Photos
				if ($destFile -ne $null) {
					[Void]$node.SetAttributeValue($attName, $destFile.ServerRelativeUrl)
					$destFile
				}
			}
		}
	}
	
	$html.DocumentNode.SelectNodes("//*[@background or @lowsrc or @src or @href]") |
		%{
			if ($_ -ne $null) { # have to _have_ an attribute to return one...
				[void](UpdateAttribute $_ "src")
				[void](UpdateAttribute $_ "lowsrc")
				[void](UpdateAttribute $_ "background")
				[void](UpdateAttribute $_ "href")
			}
		}
	# return edited body text
	$html.DocumentNode.OuterHtml
}

# draw down pages of entries, collecting them, until no more pages return
function DrawdownEntries($atomUrl)
{
	$page = [int]1
	$pagedQuery = ""
	$entries = @()
	do {
		try { $atom = $wc.DownloadString("${atomUrl}?$query$pagedQuery") } catch { $atom = $null; break; }
		$newEntries = @(([xml]$atom).feed.entry)
		if ($entries[0] -and ($newEntries[0].id -eq $entries[0].id)) { break;}
		$entries += $newEntries | ? {$_ -ne $null} 
		Write-Debug $entries.Count
		++$page
		$pagedQuery = "&paged=$page"
		Write-Debug $pagedQuery
	} until ($newEntries.Count -le 1)
	$entries
}

function ApproveListItem([Microsoft.SharePoint.SPListItem]$listItem)
{
	if ($null -ne $listItem) {
		$listItem.Update()
		if ($listItem.ModerationInformation -ne $null) {
			$listItem.ModerationInformation.Status = [Microsoft.SharePoint.SPModerationStatusType]::Approved
			$listItem.Update()
		}
	}
}

$entries = DrawdownEntries $atomUrl

# for each entry
$entries | ? { $_ -ne $null } | %{
	$entry = $_
#	extract comparable data
	$title = $_.title
	$body = $_.content
	$published = $_.published
	$updated = $_.updated
	$__source = @($_.link)[0].href # debugging
#	set up new/existing Category
	$category = New-Object System.Collections.ArrayList
	@($_.category) | % { 
		if ($mapCategories.ContainsKey($_.term)) {
			$_.term = $mapCategories[$_.term]
			[Void]$category.Add($_) 
		} elseif (!$requireMappedCategories) {
			[Void]$category.Add($_)
		}
	}
	$storedCategory = ""
	$Category | % { 
		$hash = @{"Title"="$($_.term)"}
		$listItem = SPListAddOrUpdate $Categories $hash $hash 
		$storedCategory = "$storedCategory;#$($listItem.ID);#$($listItem.Title)"		
	}
	$storedCategory = $storedCategory.TrimStart(";#")
	Write-Debug "$(GetAtomText $title): category: ${storedCategory}"
#	set up new/existing Post
#	analyze for img/object/applets
#		copy across to Photos
	$edited = UpdateBodyForPhotos $body $_
	$hashSearch = @{"Title"=(GetAtomText $title);"PublishedDate"=$published}
	$hashData=@{"Title"=(GetAtomText $title);"Body"=$edited;"PostCategory"=$storedCategory;"PublishedDate"=$published;"Author"=(MapUserName $_.author.name $mapAuthors)<#;"Editor"#>;"__source"=$__source}
	if ($updated) {$hashData.Add("updated", ([DateTime]$updated)); }
	$listItem = SPListAddOrUpdate $Posts $hashSearch $hashData
	ApproveListITem $listItem
#	for each comment
	$commentFeedUrl = @($entry.link | ? {$_.rel -eq 'replies' -and $_.type -eq 'application/atom+xml' -and $_.count -gt 0})
	if ($commentFeedUrl.Count -gt 0) {
		DrawdownEntries $commentFeedUrl[0].href | %{
#		extract comment
			$comment = $_
			$postTitle="$($listItem.ID);#$($listItem.Title)"
			$__source = @($comment.link)[0].href
			$commentHashSearch = @{"Title"=(GetAtomText $_.title);"PostTitle"=$listItem.ID}
			$commentHashData=@{"Title"=(GetAtomText $_.title);"Body"=((GetAtomtext $_.content) -replace "<p>","" -replace "</p>","`n" -replace "<br />","`n");"PostTitle"=$postTitle;"Created"=$_.published;"Author"=(MapUserName $_.author.name $mapAuthors)<#;"Editor"#>;"__source"=$__source}
#		set up new/existing Comment
			$commentListItem = SPListAddOrUpdate $Comments $CommenthashSearch $CommenthashData
			Write-Debug $commentListItem["ID"]
			ApproveListITem $commentListItem
		}
	}
}


<#
.SYNOPSIS
	Imports WordPress blog into SharePoint blog template'd web
.DESCRIPTION
	Uses WordPress API to get Atom format feed in publish order; extracts used 
	blog categories (to Categories), entries (to Posts), comments (to Comments) 
	and contained pictures (to Photos). Attachments and other local documents 
	are warned of, but since the blog template in SharePoint doesn't support 
	attachments OOB, they are not imported.
	The SharePoint blog is then updated with the new contents, overwriting 
	entries with matching title/name (and publication date for entries). (SP
	doesn't support the ID field of Atom, using RSS 2.0 itself.)
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Import-AtomToSPBlog.ps1 http://groupvelocity.loudtechinc.com http://groupvelocity.mackie.com/news
	Import-AtomToSPBlog.ps1 http://groupvelocity.loudtechinc.com http://erichstehr/sites/devtesting/blog @{"Seia"="Seia Milin";"Simon"="Simon Pearson";"connie"="Connie He";"paul"="Paul Audi";"kristina"="Kristina Childs";"glenn"="Glenn Wilson";"Marysol R"=""}
	$mapAuthors = @{
		"Seia"="Seia Milin";
		"Simon"="Simon Pearson";
		"connie"="Connie He";
		"paul"="Paul Audi";
		"kristina"="Kristina Childs";
		"glenn"="Glenn Wilson";
		"Marysol R"=""
	}
	$mapCategories = @{
		#"Uncategorized"
		"Employee Spotlight"="Employee Spotlight" #
		#""="FROM THE LEADERSHIP";
		"CUDA Awards"="CUDA AWARDS";
		"Fast Fish Challenge"="FAST FISH CHALLENGE";
		"Service Anniversaries"="SERVICE ANNIVERSARIES";
		"Personalities"="PERSONALITIES";
		"Featured"="FEATURED";
		"EAW News"="EAW NEWS";
		"Martin Audio News"="MARTIN AUDIO NEWS";
		"Mackie / Ampeg News"="MG NEWS (MACKIE AND AMPEG)";
		"Shenzhen News"="SHENZHEN NEWS";
		#""="SINGAPORE NEWS";
		"Victoria News"="VICTORIA NEWS"
	}
	Import-AtomToSPBlog.ps1 http://groupvelocity.loudtechinc.com http://erichstehr/sites/IP/news -mapAuthors $mapAuthors -mapCategories $mapCategories -requireMappedCategories
#>
