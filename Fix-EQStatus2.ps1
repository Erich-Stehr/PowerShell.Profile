$targetDir = "\\relemeas17\scraperservice\requestsout"
$wc = new-object Net.WebClient
dir "$targetdir\SWS*-scr-dat.xml" | 
    ? {($_.LastWriteTime.Date -ge ([DateTime]'2015/12/12')) -and ($_.LastWriteTime.Date -le ([DateTime]'2015/12/14'))} | 
    ? { select-string -InputObject (gc -TotalCount 100 $_) -Quiet -List -Pattern "<Engine>.*\.EQ.*</Engine>" } | 
    ? { !([IO.FileInfo]($_.FullName -replace '-dat','-sta')).Exists}