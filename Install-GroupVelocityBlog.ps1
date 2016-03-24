param (
	[Parameter(Mandatory=$true)]
	[string] 
	# (local) site url to work with
	$webUrl
)

function ScriptRoot { Split-Path $MyInvocation.ScriptName }

if (Test-Path 'C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\CONFIG\POWERSHELL\Registration\SharePoint.ps1') {
	if (!(get-pssnapin Microsoft.SharePoint.PowerShell -ea SilentlyContinue)) { & 'C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\CONFIG\POWERSHELL\Registration\SharePoint.ps1' }
	$global:sphive = [Microsoft.SharePoint.Utilities.SPUtility]::GetGenericSetupPath("").Trim('\')
}
$blog = Get-SPWeb $webUrl -ea Stop
$here = (ScriptRoot)

copy -PassThru "$here\XLV-BlogHomeFeatured.xml" "$sphive\TEMPLATE\LAYOUTS\XSL"
copy -PassThru "$here\XLV-BlogHomeLatest.xml" "$sphive\TEMPLATE\LAYOUTS\XSL"
& "$here\Install-SPWebPart.ps1" -verbose -webUrl $webUrl -pageName "default.aspx" -webPartPath "$here\CurrentFeatures.webpart" -ZoneId "Left"
$script:updateBlock = {
	$_.Title = 'Latest News'
	$_.CacheXslStorage = $true
	$_.XslLink = "/_layouts/XSL/XLV-BlogHomeLatest.xml"
	$_.ChromeType = [System.Web.UI.WebControls.WebParts.PartChromeType]::TitleOnly
	$_.Width = "680px"
}
& "$here\Update-SPWebPart.ps1"  -verbose -webUrl $webUrl -pageName "default.aspx" -selectBlock {$_.Title -eq 'Latest News'} -updateBlock $updateBlock
& "$here\Update-SPWebPart.ps1"  -verbose -webUrl $webUrl -pageName "default.aspx" -selectBlock {$_.Title -eq 'Posts'} -updateBlock $updateBlock

# take advantage of global access and the update's sweep through the parts to locate the views
$global:parts = @{} ; & "$here\Update-SPWebPart.ps1" -webUrl $webUrl -pageName "default.aspx" -selectBlock { if (($_.Title -eq 'Latest News') -or ($_.Title -eq 'Current Features')) { $global:parts.Add($_.Title, ([Guid]($_.ID.Substring(2).Replace('_','-')))) } ; $false } { }

# change the two views to pickup/deny category "Featured" and adjust row limits
$posts = $blog.Lists["Posts"]

. { 
	trap { Write-Error "Current Feature view reset failed: $_" ; break; }
	$view = $posts.Views[$parts["Current Features"]]
	$view.Query = "<Where><And><And><Leq><FieldRef Name='PublishedDate' /><Value Type='DateTime'><Today /></Value></Leq><Eq><FieldRef Name='_ModerationStatus' /><Value Type='ModStat'>Approved</Value></Eq></And><Eq><FieldRef Name='PostCategory' /><Value Type='LookupMulti'>Featured</Value></Eq></And></Where><OrderBy><FieldRef Name='PublishedDate' Ascending='FALSE' /><FieldRef Name='ID' Ascending='FALSE' /></OrderBy>"
 	$view.RowLimit = 3
	$view.Update()
}
. { 
	trap { Write-Error "Latest News view reset failed: $_" ; break; }
	$view = $posts.Views[$parts["Latest News"]]
	$view.Query = "<Where><And><And><Leq><FieldRef Name='PublishedDate' /><Value Type='DateTime'><Today /></Value></Leq><Eq><FieldRef Name='_ModerationStatus' /><Value Type='ModStat'>Approved</Value></Eq></And><Neq><FieldRef Name='PostCategory' /><Value Type='LookupMulti'>Featured</Value></Neq></And></Where><OrderBy><FieldRef Name='PublishedDate' Ascending='FALSE' /><FieldRef Name='ID' Ascending='FALSE' /></OrderBy>"
 	$view.RowLimit = 12
	$view.Update()
}
copy -PassThru "$here\GroupVelocity-SPBlog.css" "$sphive\TEMPLATE\LAYOUTS"
$blog.AlternateCssUrl = "/_layouts/GroupVelocity-SPBlog.css"
$blog.Update()