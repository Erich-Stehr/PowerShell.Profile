param (
	# search service application pipe bind (name, guid, or application object)
	$searchAppName=”Search Service Application”,
	[boolean] 
	# whether or not to leave taxonomy crawled properties mapped into index
	$isMapped=$true)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)

$searchapp = Get-SPEnterpriseSearchServiceApplication $searchAppName 
Get-SPEnterpriseSearchMetadataCrawledProperty -SearchApplication $searchApp |
	? { $_.Name.StartsWith(“ows_taxId_”) } |
	Set-SPEnterpriseSearchMetadataCrawledProperty -Identity {$_} -IsMappedToContents $isMapped

<#
.SYNOPSIS
	Sets crawled taxonomy properties to either be indexed in search or not
.DESCRIPTION
	
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
#>
