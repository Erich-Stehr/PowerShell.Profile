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
	[ScriptBlock] 
	# ScriptBlock to select web part(s) from page collection
	$selectBlock={$_.Title -eq ''},
	[Parameter(Mandatory=$true)]
	[ScriptBlock] 
	# ScriptBlock to update selected web part
	$updateBlock
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
	$mgr = $web.GetLimitedWebPartManager($pageName.ToString(), [System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
	
	# update
	$title = ""
	try {
		$mgr.WebParts |
			? $selectBlock |
			% { 
				$title = $_.Title
				& $updateBlock
				$mgr.SaveChanges($_)
				Write-Verbose "modified part '$title'"
			}
	} catch {
		throw "Exception on '$title' : $_"
	}
} finally {
	if ($null -ne $mgr) {$mgr.Dispose()}
	[System.Web.HttpContext]::Current = $ctx
	Stop-SPAssignment -Global $assignment
}

<#
.SYNOPSIS
	Updates existing webparts on SharePoint web part page
.DESCRIPTION
	Selects among the pages web parts, then executes $updateBlock on each before
	saving the changes.  Creates fake HttpContext for CQWP/XLV operations.
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Update-SPWebPart.ps1 -webUrl http://erichstehr/sites/devtesting/blog -pageName default.aspx -selectBlock {$_.Title -eq 'Posts'} -updateBlock {$_.CacheXslStorage = $false} -verbose
#>
