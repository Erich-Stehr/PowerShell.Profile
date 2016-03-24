$targetDir = "\\relemeas17\scraperservice\requestsout"
$wc = new-object Net.WebClient
dir "$targetdir\SWS*-scr-dat.xml" | 
    ? {($_.LastWriteTime.Date -ge ([DateTime]'2015/12/12')) -and ($_.LastWriteTime.Date -le ([DateTime]'2015/12/14'))} | 
    ? { select-string -InputObject (gc -TotalCount 100 $_) -Quiet -List -Pattern "<Engine>.*\.EQ.*</Engine>" } | 
    % {
	$x = $_.Name -match "SWS(.*)-scr-dat.xml"
	$jobId = $Matches[1]
	$swsStat = $wc.DownloadString("http://prod.ares.binginternal.com:82/ScraperService/v1/rest/scrapestatuses/$($jobId.ToLower())?currentuser=redmond\kopoleta")
    $staFileName = "$targetDir\SWS$jobId-scr-sta.xml"
	if (!(([IO.FileInfo]$staFileName).Exists) -and (([xml]$swsStat).Status.Code -eq 'InProgress')) {
		Set-Content -Value "<Status JobID=`"$jobId`" Status=`"Completed`" Message=`"Done`"></Status>" -Path $staFileName -pass
	}
}