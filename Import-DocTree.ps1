param (
	[Parameter(Mandatory=$true)]
	[string]
	# URL of parent SPWeb
	$webUrl="http://ffc.loudtechinc.com",
	[Parameter(Mandatory=$true)]
	[string]
	# root of directory storing documents/attachments
	$docRoot=$null
)
function ScriptRoot { Split-Path $MyInvocation.ScriptName }

# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
$x = Get-Content "$(ScriptRoot)\Import-SPDocumentLibraryFromModule.ps1" -ErrorAction Stop
$x = Get-Content "$(ScriptRoot)\Import-SPListFromListInstance.ps1" -ErrorAction Stop
$web = Get-SPWeb $webUrl -ErrorAction Stop

& "$(ScriptRoot)\Import-SPListFromListInstance.ps1" -webUrl $webUrl -xml "$docRoot\ListInstanceElements.xml" -docRoot $docRoot
& "$(ScriptRoot)\Import-SPDocumentLibraryFromModule.ps1" -webUrl $webUrl -xml "$docRoot\Elements.xml" -docRoot $docRoot

<#
.SYNOPSIS
	Import-DocTree.ps1: Imports contents of $docRoot for restoration
.DESCRIPTION
	Calls Import-SPDocumentLibraryFromModule.ps1 and Import-SPListFromListInstance.ps1 
	(both in same directory as this script) to import the lists and document 
	libraries from the $docRoot directory (ListInstanceElements.xml from 
	Export-SPListToListInstance passed the lists in order, Elements.xml and 
	subtrees from Export-SPDocumentLibraryToModule passed doclibs in order.)
.INPUTS
	no pipeline input accepted
.OUTPUTS
	2 completion messages with timestamps
.COMPONENT	
	Microsoft.SharePoint.PowerShell
	Import-SPDocumentLibraryFromModule.ps1
	Import-SPListFromListInstance.ps1
#>
