#[void] [Reflection.Assembly]::Load("System.Xml.Linq, Version=3.5.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089");
[void] [Reflection.Assembly]::Load("Microsoft.SharePoint, Version=14.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c")
[void] [Reflection.Assembly]::Load("Microsoft.Office.Server, Version=14.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c")
[void] [Reflection.Assembly]::Load("System.Web, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a")

#[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
#param
#(
#    [Parameter(Mandatory=$true)][string]$siteUrl = $(throw "Please specify the url of a SharePoint 2010 site collection to install to.")
#)

function global:CodegenListDefinition([string]$webUrl, 
		[string]$listName, 
		[string]$listType=$([Microsoft.SharePoint.SPBaseType]::GenericList.ToString()), 
		[switch]$includeHelperRoutines=$false)
{
	try
	{
		$site = new-object Microsoft.SharePoint.SPSite($webUrl)
		$web = $site.OpenWeb($webUrl.Substring($site.Url.Length))
		$list = $web.Lists.TryGetList($listName)
		if (($list -eq $null) -or ($list.BaseType.ToString() -ne $listType.ToString()))
		{
			throw "Unable to correctly access list '$list' in Url '$webUrl'; can't generate replication code"
		}
		if ($includeHelperRoutines)
		{
@'
# assumes [Microsoft.SharePoint.SPList]$list is set correctly
function VerifyListField([string]$InternalName, [string]$title, [string]$type)
{
	$field = $null
	try { $field = $list.Fields.GetFieldByInternalName($InternalName) } catch {}
	if ($null -eq $field)
	{
		$newName = $list.Fields.Add($InternalName, [Microsoft.SharePoint.SPFieldType]::Parse($type), $required)
		if ($newName -ne $InternalName)
		{
			throw "Attempt to create field '$title/$InternalName' in $($list.Title) resulted in name '$newName' instead"
		}
		$field = $list.Fields.GetFieldByInternalName($InternalName)
		$field.Title = $title
		$field.Update()
		$field = $list.Fields.GetFieldByInternalName($InternalName)
	}
	$field
}

function VerifyListComputedField([string]$InternalName, [string]$title, [string]$type)
{
	$field = $null
	try { $field = $list.Fields.GetFieldByInternalName($InternalName) } catch {}
	if ($null -eq $field)
	{
		$newName = $list.Fields.Add($InternalName, [Microsoft.SharePoint.SPFieldType]::Parse($type), $required)
		if ($newName -ne $InternalName)
		{
			throw "Attempt to create field '$title/$InternalName' in $($list.Title) resulted in name '$newName' instead"
		}
		$field = $list.Fields.GetFieldByInternalName($InternalName)
		$field.Title = $title
		$field.Update()
		$field = $list.Fields.GetFieldByInternalName($InternalName)
	}
	$field.
	$field
}

function VerifyListLookupField([string]$InternalName, [string]$title, [string]$targetListName, [string]$targetField)
{
	$field = $null
	try { $field = $list.Fields.GetFieldByInternalName($InternalName) } catch {}
	if ($null -eq $field)
	{
		$targetList = $list.ParentWeb.Lists.TryGetList($targetListName)
		if ($null -eq $targetList)
		{
			throw "Can't find list $targetListName in target $targetList!"
		}
		$newName = $list.Fields.AddLookup($InternalName, $targetList.ID, $targetList.ParentWeb.ID, $required)
		if ($newName -ne $InternalName)
		{
			throw "Attempt to create field '$title/$InternalName' in $($list.Title) resulted in name '$newName' instead"
		}
		$field = $list.Fields.GetFieldByInternalName($InternalName)
		$field.Title = $title
		$field.LookupField = $targetList.Fields.GetFieldByInternalName($targetField).InternalName
		$field.Update()
		$field = $list.Fields.GetFieldByInternalName($InternalName)
	}
	$field
}

'@
		}
@"
	# assuming `$site and `$web are pointed correctly, find/create list
	`$list = `$web.Lists.TryGetList('$listName')
	if (`$null -eq `$list)
	{
		`$list = `$web.Lists.Add('$listName', '$($list.Description)', [Microsoft.SharePoint.SPListTemplateType]::GenericList)
		`$list = `$web.Lists[`$list] #exchange Guid for list reference
	}
	# add appropriate fields
"@
		$list.Fields | 
			? { $_.Hidden -ne "FALSE" -and $_.ReadOnlyField -ne "FALSE" } | 
			% { 
				if ($_.Type -eq [Microsoft.SharePoint.SPFieldType]::Choice) { "    VerifyListChoiceField('$($_.InternalName)', '$($_.Title)', '$($_.Type.ToString())')" } 
				elseif ($_.Type -eq [Microsoft.SharePoint.SPFieldType]::Lookup) { 
				    $lookupList = $_.LookupList
					if ("" -eq $lookupList) { 
						$lookupList = ([xml]$_.SchemaXml).Field.List 
					} else {
						$lookupList = $list.ParentWeb.Lists[$lookupList].Title
					}
					"    VerifyListLookupField('$($_.InternalName)', '$($_.Title)', '$lookupList', '$($_.LookupField)')" 
				} 
				elseif ($_.Type -eq [Microsoft.SharePoint.SPFieldType]::Computed) { "    VerifyListComputedField('$($_.InternalName)', '$($_.Title)', '$($_.Type.ToString())')" } 
				else { "    VerifyListField('$($_.InternalName)', '$($_.Title)', '$($_.Type.ToString())')" } 
			}
		'    $list.Update()'
	}
	finally
	{
		if ($null -ne $web) { $web.Dispose() }
		if ($null -ne $site) { $site.Dispose() }
	}
	
}

function global:VerifyLookupFieldsInWeb ([string] $hubUrl=$(throw "requires hubUrl"), [switch]$ShowHidden=$false, [switch]$showReadonly=$false, [switch]$showEmptyLookupLists=$false)
{
	$spSite = New-Object Microsoft.SharePoint.SPSite($hubUrl)
	$spWeb = $spSite.OpenWeb((new-object Uri $huburl).LocalPath)
	try
	{
		foreach ($spList in ($spWeb.Lists | ? { $ShowHidden -or (-not $_.Hidden) }) )
		{
			foreach ($spField in ($spList.Fields | ? { $_.Type -eq [Microsoft.SharePoint.SPFieldType]::Lookup} | ? { $ShowHidden -or (-not $_.Hidden) } | ? { $ShowReadonly -or (-not $_.ReadOnly) }) )
			{
				$spLookupWebName = $spField.LookupWebId.ToString("B")
				if ($spField.LookupWebId -eq $spWeb.Id) { $spLookupWebName = "thisWeb" }
				$spLookupListName = $spField.LookupList
				try { $l = $spWeb.Lists[[guid]$spLookupListName].Title; if (![string]::IsNullOrEmpty($l)) {$spLookupListName = $l} } catch {}
				if (!$showEmptyLookupLists -and [string]::IsNullOrEmpty($spLookupListName)) { continue; }

				#write-verbose "List $($spList.Title) $(if ($spField.Hidden) {"Hidden "})$(if ($spField.ReadOnlyField) {"Read-only "})Lookup $($spField.Title)/$($spField.InternalName) points to $spLookupWebName $spLookupListName $($spField.LookupField)"
				$true | select @(
					@{n='WebUrl';e={$hubUrl}},
					@{n='ListTitle';e={$spList.Title}},
					@{n='Hidden';e={$spField.Hidden}},
					@{n='ReadOnly';e={$spField.ReadOnlyField}},
					@{n='FieldTitle';e={$spField.Title}},
					@{n='FieldInternalName';e={$spField.InternalName}},
					@{n='LookupWebName';e={$spLookupWebName}},
					@{n='LookupListName';e={$spLookupListName}},
					@{n='LookupField';e={$spField.LookupField}}
					)
			}
		}
	}
	finally
	{
		if ($null -ne $spWeb) {$spWeb.Dispose()}
		if ($null -ne $spSite) {$spSite.Dispose()}
	}
}

function global:ResetLookupField ([string] $webUrl=$(throw "requires webUrl"), [string] $listTitle=$(throw "requires listTitle"), [string] $fieldInternalName=$(throw "requires fieldInternalName"), [string] $targetWebUrl=$webUrl, [string] $targetListTitle=$listTitle, [string] $targetFieldInternalName=$(throw "requires targetFieldInternalName"))
{
	$spSite = New-Object Microsoft.SharePoint.SPSite($webUrl)
	$spWeb = $spSite.OpenWeb((new-object Uri $weburl).LocalPath)
	try
	{
		$list = $spWeb.Lists[$ListTitle]
		$field = $list.Fields.GetFieldByInternalName($fieldInternalName)

		$spTargetWeb = if ($targetWebUrl -eq $webUrl) {$spWeb} else {$spSite.OpenWeb((new-object Uri $targetWebUrl).LocalPath)}
		if (!$spTargetWeb.Exists) {throw "Couldn't get to '$targetWebUrl' through site of '$WebUrl'" }
		$spTargetList = if (($targetWebUrl -eq $webUrl) -and ($listTitle -eq $targetListTitle)) {$list} else {$spTargetWeb.Lists[$targetListTitle]}

		$field.LookupWebID = $spTargetWeb.ID
		$field.LookupField = $targetFieldInternalName
		$field.Update()
		#now that we've updated the updatables, tweak the LookupList through the SchemaXml and abandon this SPField object
		$schema = [xml]$field.SchemaXml
		$schema.Field.List = $spTargetList.ID.ToString("B")
		$field.SchemaXml = $schema.OuterXml
	}
	finally
	{
		if ($null -ne $spWeb) {$spWeb.Dispose()}
		if ($null -ne $spSite) {$spSite.Dispose()}
	}
}
#$hubUrl = "http://a-erste-vm1/sites/ProdHubTest/test"
#ResetLookupField -webUrl $hubUrl -listTitle "Content Library" -fieldInternalName "Product" -targetListTitle "Products" -targetFieldInternalName "Title"
#ResetLookupField -webUrl $hubUrl -listTitle "Get It Done" -fieldInternalName "Section" -targetListTitle "Sections" -targetFieldInternalName "Title"
#ResetLookupField -webUrl $hubUrl -listTitle "LearningRoadmaps" -fieldInternalName "Product" -targetListTitle "Products" -targetFieldInternalName "Title"
#ResetLookupField -webUrl $hubUrl -listTitle "ProductVersions" -fieldInternalName "Product" -targetListTitle "Products" -targetFieldInternalName "Title"
#ResetLookupField -webUrl $hubUrl -listTitle "QuizChoices" -fieldInternalName "Product" -targetListTitle "Products" -targetFieldInternalName "Title"
#ResetLookupField -webUrl $hubUrl -listTitle "QuizChoices" -fieldInternalName "RelatedQuestion" -targetListTitle "QuizQuestions" -targetFieldInternalName "Title"
#ResetLookupField -webUrl $hubUrl -listTitle "QuizChoices" -fieldInternalName "RelatedQuestion_x003a_ID" -targetListTitle "QuizQuestions" -targetFieldInternalName "ID"
#ResetLookupField -webUrl $hubUrl -listTitle "QuizQuestions" -fieldInternalName "Product" -targetListTitle "Products" -targetFieldInternalName "Title"

#2012/09/13
function Upload-FileToLocalSPFolder([string]$path, [Microsoft.SharePoint.SPFolder]$folder) {
	$fileStream = [System.IO.File]::OpenRead($path)
	$fileName = [IO.Path]::GetFileName($path)
	$fileRequiredCheckout=$false
	
	$targetSPFile = $null
	try { $targetSPFile = $folder.Files[$fileName]; } 
	catch [System.IO.FileNotFoundException] {} # eat error from file not found, pass rest up
	if ($targetSPFile -eq $null) {
		$targetSPFile = $folder.Files.Add($fileName, $fileStream)
	} else {
		if ($targetSPFile.RequiresCheckout) {
			$fileRequiredCheckout = $true
			$targetSPFile.CheckOut()
		}
		$targetSPFile.SaveBinary($fileStream)
	}
	$targetSPFile.Update()
	$fileStream.Close()
	if ($fileRequiredCheckout) {
		$targetSPFile.CheckIn("Install-GroupVelocityBlog.ps1 automated update", [Microsoft.SharePoint.SPCheckinType]::MajorCheckIn)
		$targetListItem = $targetSPFile.ListItemAllFields
		if ($targetListItem.ModerationInformation -ne $null) {
			#Content approval active; approve list item, then can publish and approve file
			$targetListItem.ModerationInformation.Status = [Microsoft.SharePoint.SPModerationStatusType]::Approved;
			$targetListItem.Update()
		}
		$targetSPFile.Publish("Install-GroupVelocityBlog.ps1 automated update")
		if ($targetListItem.ModerationInformation -ne $null) {
			#Content approval active; approve list item, then can publish and approve file
			$targetSPFile.Approve("Install-GroupVelocityBlog.ps1 automated update")
		}
	}
	return $targetSPFile
}
# Upload-FileToLocalSPFolder "$here\GroupVelocity-SPBlog.css" $rootWeb.GetFolder("Style%20Library/Branding/CSS")
# $masterPageFile = Upload-FileToLocalSPFolder "$here\loudBlog.master" $rootWeb.GetFolder("_catalogs/masterpage")

filter Add-SPGroupMember(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.SPGroup]
	# SPGroup to add members to
	$group,
	[Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="account names in either sAMAccountName or email format")]
	[String[]]
	$accountName
	)
{
	$user = $group.ParentWeb.EnsureUser($accountName)
	Write-Debug $user
	$group.AddUser($user)	
	$group.Update()
}
# "erich.stehr@loudtechinc.com","seia.milin@loudtechinc.com" | Add-SPGroupMember $web.SiteGroups["News Members"] 
# gc "$env:USERPROFILE\GroupVelocityNewsMembers.txt" | Add-SPGroupMember $web.SiteGroups["News Members"] 
#

#
#
