param (
	[string] 
	# (local) web url to work with
	$webUrl=$(throw "Requires (local) web URL to work with")
	)
# check for error causing states
#requires -Version 2.0
Set-StrictMode -Version 2.0
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
$web = Get-SPWeb $webUrl -ea Stop

$list = $null

function VerifyListBasicSettings(
	[Microsoft.SharePoint.SPWeb] $web,
	[string] $listName,
	[string] $listDescription,
	[Microsoft.SharePoint.SPListTemplateType] $baseTemplate,
	[Boolean] $contentTypesEnabled
)
{
	trap { break; } # Just stop on unhandled exceptions
	$list = $web.Lists.TryGetList($listName)
	if ($null -eq $list) {
		# Add the list
		$guid = $web.Lists.Add($listName, $listDescription, $baseTemplate)
		$list = $web.Lists[$guid]
	} else {
		# Verify list set correctly
		if ($list.BaseTemplate -ne $baseTemplate) { throw "Incorrect template on $listName ($list.BaseTemplate) doesn't match required ($baseTemplate)" }
		$list.Description = $listDescription
		$list.Update()
	}
	$list.ContentTypesEnabled = $contentTypesEnabled
	$list.Update()
	return $list
}

#function VerifyContentType($list, $ctName)
#{
#	$ct = $null ; try { $ct = $list.ContentType[$ctName] } catch { $ct = $null }
#}

function VerifySingleField($list, $internalName, $title, $required, $unique, $type, $lookupList) {
	trap { break; } # Just stop on unhandled exceptions
	$field = $null ; try { $field = $list.Fields.GetFieldByInternalName($internalName) } catch { $field = $null }
	if ($null -eq $field) {
		if ('Lookup' -eq $type) {
			$fieldName = ""
			if ($lookupList.Length -gt 2) {
				$newWeb = Get-PSWeb $lookupList[2]
				$fieldName = $list.Fields.AddLookup($internalName, $newWeb.Lists[$lookupList[1]].Id, $newWeb.Id, $required)
			} else {
				$fieldName = $list.Fields.AddLookup($internalName, $list.Lists[$lookupList].Id, $required)
			}
            if ($fieldName -ne $internalName) {
                throw "Couldn't create a field with the correct internal name '$internalName', got '$fieldName'"
            }
            $field = $list.Fields.GetFieldByInternalName($fieldName) 
			$field.LookupField = $lookupList[0]
			try { $field.Update() } catch { throw "Couldn't set LookupField on $internalName/$($field.Title): $($_.ToString())" }
		} else {
			$field = $list.Fields.CreateNewField($type, $internalName)
			if ($null -eq $field) { throw "Couldn't create new field $internalName of type $type" }
            $list.Fields.Add($field)
            $field = $list.Fields.GetFieldByInternalName($internalName)
			if ($null -eq $field) { throw "Couldn't locate new field $internalName of type $type" }
		}
	} else {
		if ($field.TypeAsString -ne $type) { throw "Field $internalName/$($field.Title) has type $($field.TypeAsString) instead of $type." }
	}
	if (($field.Title -ne $title) -or ($field.Required -ne $required) -or ($field.EnforceUniqueValues -ne $unique)) {
		$field.Title = $title
		$field.Required = $required
		$field.EnforceUniqueValues = $unique
		try { $field.Update() } catch { throw "Couldn't update $internalName/$($field.Title): $($_.ToString())" }
	}
	if (('Lookup' -eq $type) -and (($field.LookupField -ne $lookupList[0]))) {
		$field.LookupField = $lookupList[0]
		try { $field.Update() } catch { throw "Couldn't set LookupField on $internalName/$($field.Title): $($_.ToString())" }
	}
}


$list = VerifyListBasicSettings $web 'CollectionOwnership' '' 'GenericList' $False
$collectedFields = @(
	(VerifySingleField $list 'Title' 'Title' $True $False 'Text' @()),
	(VerifySingleField $list 'Owner' 'Owner' $False $False 'User' @( 'Title', 'User Information List')),
	(VerifySingleField $list 'SecondaryContact' 'SecondaryContact' $False $False 'User' @( 'Title', 'User Information List')),
	(VerifySingleField $list 'ContentType' 'Content Type' $False $False 'Computed' @()),
	(VerifySingleField $list 'Attachments' 'Attachments' $False $False 'Attachments' @()),
$null )
