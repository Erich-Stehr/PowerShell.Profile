param (
	[string] 
	# (local) web url to work with
	$webUrl=$(throw "Requires (local) web URL to work with"),
	[string] 
	# list name on siteUrl
	$listName=$(throw "Requires name of list on `$webUrl"),
	[switch] 
	# prevent include of functions header (allows directly appending outputs for multiple lists in single script)
	$noheader=$False
	)
# check for error causing states
#requires -Version 2.0
Set-StrictMode -Version 2.0
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
$web = Get-SPWeb $webUrl -ea Stop
$list = $web.Lists[$listName]
if (($list.BaseType -ne [Microsoft.SharePoint.SPBaseType]::GenericList) -and ($list.BaseType -ne [Microsoft.SharePoint.SPBaseType]::DocumentLibrary)) {
	trap { break; }
	throw "GenerateList is not yet able to handle anything but GenericList or DocumentLibrary. $($list.DefaultViewUrl) is of SPBaseType.$($list.BaseType)"
}

# Generate header and working functions
# TODO: much more generic work....
if (!$noheader) {
@'
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


'@
}
#	list.Fields.CreateNewField("TaxonomyFieldType", columnName) -as TaxonomyField

# local generation functions
function EscapeSingleQuotes([string]$s) { $s -replace "'","''" }
function Format-StringCollection() {
	begin { $ret = "@(" }
	process { if ($null -ne $_) { $ret = "$ret '$(EscapeSingleQuotes $_.ToString())'," } }
	end { "$($ret.Trim(',')))" }
}

function ConvertGuidToList([Guid]$guid) {
	$list = $null
	# check local
	try { $list = $web.Lists[$guid] } catch {}
	# if not there, check the rootweb
	if ($null -eq $list) { try { $list = $web.Site.RootWeb.Lists[$guid] } catch {} }
	# BUGBUG: if not there either, loop through the AllWebs 
	return $list
}

function ConvertGuidToWebUrl([Guid]$guid) {
	# check local
	if ($web.Id -eq $guid) { return $web.Url }
	# if not there, check the rootweb
	$newWeb = $null ; try { $newWeb = $web.Site.AllWebs[$guid] } catch {}
	if ($null -ne $newWeb) { return $newWeb.Url } 
	return $guid.ToString("B")
}

function FindLookupNames ($field) {
# returns @(), @("Field name", "list title"), or @("Field Name", "list title", "url to target list's web")
    trap { break; }
	if (!($field -is [Microsoft.SharePoint.SPFieldLookup])) { return @() } # not a lookup, nothing to do
	if ($field -is [Microsoft.SharePoint.SPFieldUser]) { return @() } # not a lookup we should handle
    $ret = @()
    if ($field.LookupWebId -ne $web.Id) { $ret = @(ConvertGuidToWebUrl $field.LookupWebId) }
    $listID = $field.LookupList
    . {
        trap { break; }
        $listID = [Guid]$listID
    }
    if ($listID -is [Guid]) {
		$targetList = ConvertGuidToList $listId
		$ret = @($(if ($null -eq $targetList) {$listID} else {$targetList.Title})) + $ret
	} else { 
		$ret = @($listID) + $ret
	}
    return @($field.LookupField) + $ret
}

# Generation of script
#$DebugPreference = [System.Management.Automation.ActionPreference]::Continue
"`$list = VerifyListBasicSettings `$web '$(EscapeSingleQuotes $list.Title)' '$(EscapeSingleQuotes $list.Description)' '$($list.BaseTemplate)' `$$($list.ContentTypesEnabled)"
"`$collectedFields = @("
$list.Fields |
	? { ! ($_.Hidden -or $_.ReadOnlyField) } |
	% { Write-Debug "Field $($_.StaticName)/$($_.Title)"; "`t(VerifySingleField `$list '$($_.InternalName)' '$($_.Title)' `$$($_.Required) `$$($_.EnforceUniqueValues) '$($_.TypeAsString)' $(FindLookupNames $_  | Format-StringCollection))," }
"`$null )"

<#
.SYNOPSIS
	Generates script to create duplicate of named list
.DESCRIPTION
	Pointed at a list by URL of local SharePoint web and name of list,
	the output run given a different URL regenerates a list with matching
	schema and settings.  Does not move documents/list items.
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	.ps1 code
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
#>
