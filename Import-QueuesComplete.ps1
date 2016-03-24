param(
	[string]
	$serverName="relemeas17",
	[DateTime]
	$day=([DateTime]::Today),
	[string]
	$queueRegex=".*"
)
if ($env:COMPUTERNAME -eq 'relemeas35') {
	$logPath = 'd:\data'
} elseif ($env:UserName -eq 'ReleInfra') {
	$logPath = 'c:\data'
} else { 
	$logPath = "\\$serverName" 
}
Write-Debug $logPath
Import-Csv "${logPath}\ScraperService\Dumps\completed_log_$($day.ToString('MMddyyyy')).tsv" -Header 'Queue', 'JobID', 'Priority', 'StartTime', 'LastWriteTime', 'Owner', 'Description', 'ScrapeDepth', 'QueriesSent', 'Engine', "EntitySetId","SubmitTime", 'QueriesCount', 'QueriesWithInstabilityCount' -Delimiter "`t" |
	? {$_.Queue -match $queueRegex} | 
	Add-Member -Passthru -MemberType ScriptProperty -Name CalculatedQPS -Value {$this.QueriesCount/((([DateTime]($this.LastWriteTime))-([DateTime]($this.StartTime))).TotalSeconds)}

