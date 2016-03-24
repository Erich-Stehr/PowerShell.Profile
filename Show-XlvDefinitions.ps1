param (
	[string] 
	# (local) web url to work with
	$webUrl=$(throw "Requires (local) web URL to work with"),
	[string] 
	# (web-local) page url to work with
	$pageUrl=$(throw "Requires (web-local) page URL to work with")
	)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)

try
{
	$script:web = Get-SPWeb $webUrl
	$script:file = $web.GetFile($pageUrl)
	$script:mgr = $file.GetLimitedWebPartManager([System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
	if ($file.RequiresCheckout) {Write-Warning "File requires checkout!"}
	foreach ($part in $mgr.WebParts) {
		if ($part -is [Microsoft.SharePoint.WebPartPages.XsltListViewWebPart]) {
			$part | select Title,XmlDefinition,ID,ViewGuid
		}
	}
}
finally
{
	$mgr.Web.Dispose()
	$mgr.Dispose()
	$web.Dispose()
}

<#
.SYNOPSIS
	returns XmlDefinition from the XsltListViewWebPart's in the selected page
.DESCRIPTION
	x
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	Warning if file needs to be checked out
	stream of Selected...XLV's with Title,XmlDefinition
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Show-XlvDefinitions.ps1 http://server Pages/default.aspx | fl *
#>
