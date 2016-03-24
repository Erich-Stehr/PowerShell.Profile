[CmdletBinding()]
param (
	[Microsoft.Office.Server.Search.Cmdlet.SearchServiceApplicationPipeBind] 
	# search application to work with
	$searchapp=(@(Get-SPEnterpriseSearchServiceApplication)[0]),
	[Microsoft.Office.Server.Search.Cmdlet.ContentSourcePipeBind] 
	# (local) site url to work with
	$crawlsource=(@(Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $searchapp)[0]),
	[int]
	# seconds to sleep between checks
	$sleep=15,
	[switch]
	# incremental crawl (default)
	$incremental=$true,
	[switch]
	# full crawl (overrides -incremental)
	$full=$false
	)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)

if (!(dir -ea SilentlyContinue function:\New-HashObject)) {
# from PSCX.codeplex.com
filter New-HashObject {

    if ($_ -isnot [Collections.IDictionary]) {
        return $_
    }

    $result = new-object PSObject
    $hash = $_

    $hash.Keys | %{ $result | add-member NoteProperty "$_" $hash[$_] -force }

    $result
}
}

if ($crawlsource -eq $null) {
	$cs = @(Get-SPEnterpriseSearchCrawlContentSource -SearchApplication $searchapp)[0]
} else {
	$cs = @(Get-SPEnterpriseSearchCrawlContentSource  -Identity $crawlsource -SearchApplication $searchapp)[0] 
}
if ($full) {
	Write-Verbose "Starting full crawl on $($cs.Name)"
	$cs.StartFullCrawl()
} elseif ($incremental) {
	Write-Verbose "Starting incremental crawl on $($cs.Name)"
	$cs.StartIncrementalCrawl()
} else {
	Write-Verbose "waiting on current crawl on $($cs.Name)"
}

do { 
	@{Time=([DateTime]::Now);CrawlState=($cs.CrawlState)} | New-HashObject
	if ($cs.CrawlState -ne 'Idle') { sleep $sleep } else { break; }
} while (1)

<#
.SYNOPSIS
	Start a search crawl on local farm, loop with status until complete
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	PSObject (Time, CrawlState)
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	.\StartLocalCrawl.ps1

	Basic incremental crawl on first search app's first content source
.EXAMPLE
	.\StartLocalCrawl.ps1 -full

	Basic full crawl on first search app's first content source
.EXAMPLE
	.\StartLocalCrawl.ps1 -incremental:$false -verbose

	Doesn't start a crawl but does return crawl status on first search app's first content source until complete
#>
