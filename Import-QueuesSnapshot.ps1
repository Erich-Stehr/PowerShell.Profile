param ($server=$("relemeas17"), [switch]$inProgress=$false)
$columns = "JobID","Priority","CreationTime","Status","Owner","Description","ScrapeDepth","QueriesCount","StatusMessage","Engine","Market","MiniSet","UrlAugmentation","QueryAugmentation","JudgeDepth"
$l = $columns.length - 1
$addedColumns = "EntitySetId","SubmitTime"
if ($env:COMPUTERNAME -eq 'relemeas35') {
	$logPath = 'd:\data'
} elseif ($env:UserName -eq 'ReleInfra') {
	$logPath = 'c:\data'
} else { 
	$logPath = "\\$server" 
}
$snapshot = "${logPath}\ScraperService\Dumps\queues_snapshot.tsv"

# can't use Import-CSV due to mixed format (queue lines, data)
get-content $snapshot | %{
	$line = $_.Split("`t")
	if ($line.length -le $l) {
		# not enough fields, must be queue name
		$queue = $line[0]
	} else {
		$obj = @{'Queue'=$queue}
		# add historical columns
		0..$l | %{
			[void]$obj.Add($columns[$_], $line[$_])
		}
		# if we have them, add extended columns
		if ($line.length -gt ($l + $addedColumns.Length)) {
			0..($addedColumns.Length-1) | %{
				[void]$obj.Add($addedColumns[$_], $line[$_+$l+1])
			}
		}
		New-Object PSObject -Property $obj |
			? { !$inProgress -or $_.Status -eq 'InProgress' }
	}
}
