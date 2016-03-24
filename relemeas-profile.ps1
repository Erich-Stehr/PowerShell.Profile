# useful functions for scraperservice deployment and checking, to be used as $PROFILE.CurrentUserAllHosts
function last ([int]$count=10, [Object[]]$Property=@("LastWriteTime")) { $input | sort -Property $Property | select -l $count }
function yesterday ([int]$days=1) { return [DateTime]::Today.AddDays(-$days) }
function ServiceStop([string]$command='Stop', [string]$servicename="scraperservice") {
	Invoke-Expression "net $command $servicename"
	while ((gsv $servicename).Status -eq "${command}Pending") {
		write-host '.' -NoNewLine
		sleep 5
	}
	write-host
	gps WebScraper -ea SilentlyContinue
}
function dirSeconds {
	$input | format-table -auto -wrap Mode,@{n='lastWriteTime';e={$_.LastWriteTime.ToString('s')}},length,name
}
# locate root for data/logging on DTAP and VMs, which aren't connected to corpnet
# overrides server parameter where we can't use it
if ($env:COMPUTERNAME -eq 'relemeas35') {
	$logPath = 'd:\data'
} elseif ($env:UserName -eq 'ReleInfra') {
	$logPath = 'c:\data'
}
function Import-QueuesComplete(
	[string]
	$serverName="relemeas17",
	[DateTime]
	$day=([DateTime]::Today),
	[string]
	$queueRegex=".*"
)
{
	Import-Csv "$(if ($logPath) {$logpath} else {'\\'+$serverName})\ScraperService\Dumps\completed_log_$($day.ToString('MMddyyyy')).tsv" -Header 'Queue', 'JobID', 'Priority', 'StartTime', 'LastWriteTime', 'Owner', 'Description', 'ScrapeDepth', 'QueriesSent', 'Engine', "EntitySetId","SubmitTime", 'QueriesCount', 'QueriesWithInstabilityCount' -Delimiter "`t" |
		? {$_.Queue -match $queueRegex} | 
		Add-Member -Passthru -MemberType ScriptProperty -Name CalculatedQPS -Value {$this.QueriesCount/((([DateTime]($this.LastWriteTime))-([DateTime]($this.StartTime))).TotalSeconds)}
}
function Import-QueuesSnapshot($serverName=$("relemeas17"), [switch]$inProgress=$false)
{
	$columns = "JobID","Priority","CreationTime","Status","Owner","Description","ScrapeDepth","QueriesCount","StatusMessage","Engine","Market","MiniSet","UrlAugmentation","QueryAugmentation","JudgeDepth"
	$addedColumns = "EntitySetId","SubmitTime", "FullFileName", "MiniSetClass", "MiniSetStatus", "AresExperimentId", "IsOfficial", "EvaluationId", "RecurrenceId"
	$l = $columns.length - 1
	$snapshot = "$(if ($logPath) {$logpath} else {'\\'+$serverName})\ScraperService\Dumps\queues_snapshot.tsv"

	get-content $snapshot | %{
		$line = $_.Split("`t")
		if ($line.length -le $l) {
			$queue = $line[0]
		} else {
			$obj = @{'Queue'=$queue}
			0..$l | %{
				[void]$obj.Add($columns[$_], $line[$_])
			}
			if ($line.length -gt ($l + $addedColumns.Length)) {
				0..($addedColumns.Length-1) | %{
					[void]$obj.Add($addedColumns[$_], $line[$_+$l+1])
				}
			}
			New-Object PSObject -Property $obj |
				? { !$inProgress -or $_.Status -eq 'InProgress' }
		}
	}
}
function CheckQueueComplete(
	[string]
	$serverName="relemeas17",
	[DateTime]
	$day=([DateTime]::Today),
	[string]
	$queueRegex=".*",
	[switch]
	$Raw=$false
)
{
	if ($Raw) {
		Import-QueuesComplete -serverName $serverName -day $day -queueRegex $queueRegex | last
	} else {
		Import-QueuesComplete -serverName $serverName -day $day -queueRegex $queueRegex | last | ft -auto Queue,LastWriteTime,JobId
	}
}
function CheckQueueSnapshot($serverName=$("relemeas17"), [string] $queueRegex=".*", [switch]$inProgress=$false, [switch]$Raw=$false)
{
	if ($Raw) {
		Import-QueuesSnapshot -serverName $serverName -inProgress:$inProgress | ? { $_.Queue -match $queueRegex } 
	} else {
		Import-QueuesSnapshot -serverName $serverName -inProgress:$inProgress | ? { $_.Queue -match $queueRegex } | ft -auto Queue,Status,Priority,JobId
	}
}
function LastQueueComplete(
	[string]
	$serverName="relemeas17",
	[DateTime]
	$day=([DateTime]::Today),
	[string]
	$queueRegex=".*"
)
{
	[DateTimeOffset](Import-QueuesComplete -serverName $serverName -day $day -queueRegex $queueRegex | last 1).LastWriteTime
}
function PollForFileWriteChange (
	[IO.FileInfo]$f=$(dir '\Data\Scraperservice\Dumps\queues_snapshot.tsv'),
	[int]$seconds=10
)
{
	$t = $f.LastWriteTime
	Write-Verbose $t.ToString('o')
	while ($t -eq (dir $f).LastWriteTime) {
		Write-Host "." -noNewLine
		sleep $seconds
	}
	Write-Verbose (dir $f).LastWriteTime.ToString('o')
}
function StreamLast(
	[Parameter(Mandatory=$true)]
	[ScriptBlock]
	$block,
	[Object[]]
	$Property=@("LastWriteTime"),
	[int]
	$seconds=10,
	[int]
	$initialCount=10
)
{
	$dt = [DateTime]::MinValue
	$r = @((& $block) | sort -Property $Property | select -l $initialCount)
	while ($true) {
		if ($r.Count -gt 0) {
			$r | ? { $_.($Property[0]) -gt $dt }
			$dt = $r[-1].($Property[0])
		}
		Start-Sleep $seconds
		$r = @((& $block) | sort -Property $Property | select -l $initialCount)
	}	
}
# StreamLast {Get-CosmosStream https://cosmos09.osdinfra.net/cosmos/relevance/projects/Infrastructure/ScrapeEngines/PIM/EQ.SBS/out} -property PublishedUpdateTime | ft @{n='lastWriteTime';e={$_.PublishedUpdateTime.ToString('s')};w=19},Length,@{n='Name';e={[IO.Path]::GetFileName($_.StreamName)};w=85}


