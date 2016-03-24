param (
	[Parameter(Mandatory=$true)]
	[string] 
	# (local) site url to work with
	$webUrl,
	[Parameter(Mandatory=$true)]
	[string] 
	# web page in $webUrl to work with
	$pageName,
	[Parameter(Mandatory=$true)]
	[string] 
	# path to .webpart/.dwp
	$webPartPath,
	[Parameter(Mandatory=$true)]
	[string] 
	# ID of web part zone to place part into
	$ZoneID,
	[int] 
	# index within web part zone to place part at (default: 0 (first))
	$ZoneIndex=0,
	[switch] 
	# prevents deleting prior web parts with same name
	$NoWipe=$false
	)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
$assignment = Start-SPAssignment -Global
$web = Get-SPWeb $webUrl -ErrorAction Stop 

function FakeContext([Microsoft.SharePoint.SPWeb]$contextWeb)
# create fake SPContext to allow CQWP to be inserted programmatically, returns original
# from <http://solutionizing.net/2009/02/16/faking-spcontext/>
{
	$ctx = [System.Web.HttpContext]::Current
	if ($ctx -eq $null) {
		$request = New-Object System.Web.HttpRequest ("", ($contextWeb.Url), "")
		[System.Web.HttpContext]::Current = New-Object System.Web.HttpContext @($request, (New-Object System.Web.HttpResponse @([System.IO.TextWriter]::Null)))
	}
    # SPContext is based on SPControl.GetContextWeb(), which looks here 
    if ([System.Web.HttpContext]::Current.Items["HttpHandlerSPWeb"] -eq $null) {
        [System.Web.HttpContext]::Current.Items["HttpHandlerSPWeb"] = [Microsoft.SharePoint.SPWeb]$contextWeb;
	}
	return $ctx
}

$ctx = $null;
try {
	$ctx = FakeContext $web
	$webpart = [string]::Concat((Get-Content $webPartPath))
	$mgr = $web.GetLimitedWebPartManager($pageName.ToString(), [System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
	
	# wipe current parts with same title
	$title = $null
	if (!$NoWipe) {
		$xmlWebPart = [xml]$webpart
		$title = ($xmlWebPart.webParts.webPart.data.properties.property | 
				? { $_.Name -eq 'Title' }).InnerText
		Write-Verbose "Title: $title"
		if ([string]::IsNullOrEmpty($title)) { Write-Warning "No title found in $webPartPath!" }
		$parts = @($mgr.WebParts | 
			? { $_.Title -eq $title })
		# separated out to prevent smashing the collection iterator
		Write-Verbose "$($parts.Count) matching parts found"
		$parts | % { $mgr.DeleteWebPart($_) }
	}
	# process ~SiteCollection/, ~Site/ replaceable tokens for parts that don't (CQWP)
	$webPart = $webPart -replace '$spurl:~sitecollection/',($web.Site.ServerRelativeUrl.TrimEnd('/') + '/')
	$webPart = $webPart -replace '$spurl:~site/',($web.ServerRelativeUrl.TrimEnd('/') + '/')
	$webPart = $webPart -replace "~sitecollection/",($web.Site.ServerRelativeUrl.TrimEnd('/') + '/')
	$webPart = $webPart -replace "~site/",($web.ServerRelativeUrl.TrimEnd('/') + '/')
	# import from string
	$ErrorMessage = ""
	$stream = New-Object System.IO.StringReader $webPart
	try {
		$reader = [Xml.XmlReader]::Create($stream)
		$objWebPart = $mgr.ImportWebpart($reader, ([ref]$ErrorMessage))
		if ($ErrorMessage) { Write-Verbose $ErrorMessage }
		$mgr.AddWebPart($objWebPart, $ZoneID, $ZoneIndex)
		Write-Verbose "Added part '$title' to $ZoneID index $ZoneIndex"
	} catch {
		throw "Exception adding '$title' with message '$ErrorMessage': $_"
	}
} finally {
	if ($null -ne $mgr) {$mgr.Dispose()}
	[System.Web.HttpContext]::Current = $ctx
	Stop-SPAssignment -Global $assignment
}

<#
.SYNOPSIS
	Installs serialized .webpart/.dwp file into SharePoint web part page
.DESCRIPTION
	Installs serialized .webpart/.dwp file into SharePoint web part page,
	removing any identically titled web parts from the page unless -NoWipe
	switch is set. Creates fake HttpContext for CQWP installation.
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Install-SPWebPart.ps1 -webUrl http://erichstehr/sites/devtesting/blog -pageName default.aspx -webPartPath "$env:USERPROFILE\Documents\LocalBlogDefault.aspx.Posts.uncached.webpart" -ZoneId Left -verbose
#>
