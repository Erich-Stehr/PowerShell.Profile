param ([string]$logfile="~\Documents\QPS partial output.txt")
$re = [Regex]'(?<Timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}[-+]\d{2}:\d{2})\: (?<Operation>.*) query \#(?<QueryId>\d+) \<(?<QueryText>.*?)\>$'
#$logEntries = select-string -path '.\Documents\QPS partial output.txt' -pattern $re
$logEntries = (gc -ReadCount 1 $logfile).Split([Environment]::NewLine[1]) |
    & { # merge broken lines assuming output of 120 column window
        begin { $s = "" } 
        process { if ($_.Length -eq 121) { $s += $_ } elseif ($_.Length -eq 120) { $s += $_ + ' ' } else { "$s$_"; $s = "" } } 
        end { if ($s -ne "") { $s } } 
    } |
    Get-Matches $re
$logentries | 
	Group-Object -Property QueryId | 
#	? { $_.Count -gt 2} | 
	? { $_.Group[0].Operation -eq "Begin processing"} | 
	select @{n='QueryId';e={$_.Name}},@{n='Duration';e={(([DateTime]$_.Group[0].TimeStamp)-([DateTime]$_.Group[-1].Timestamp)).Duration()}},@{n='QueryText';e={$_.Group[0].QueryText}} | 
	sort QueryId |
	ft -auto -wrap


