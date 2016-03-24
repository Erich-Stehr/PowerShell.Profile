param ($logfile)
#import-csv -Delimiter " " -Header "date","time","s-ip","cs-method","cs-uri-stem","cs-uri-query","s-port","cs-username","c-ip","csUser-Agent","sc-status","sc-substatus","sc-win32-status","time-taken" -path $logfile | ? { !($_.Date.StartsWith('#')) }
# Generalized 2013/01/11 to select the first header in the first log file and to trim out padding NUL 'lines'
$headerMatch = select-string -path $logfile -Pattern "^\#Fields\: " -List
$header = $headerMatch.Line.Substring($headerMatch.Matches[0].Length).Split(" ",[StringSplitOptions]::RemoveEmptyEntries)
gc $logfile | ? { !$_.StartsWith("#") -and ($_.Trim("`0").Length -gt 0) } | ConvertFrom-CSV -Delimiter " " -Header $header