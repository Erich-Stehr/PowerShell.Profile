# from <http://jtruher.spaces.live.com/Blog/cns!7143DA6E51A2628D!792.entry>  2009/07/28
$PCounter = "System.Diagnostics.PerformanceCounter"
$counter = new-object $PCounter System,"System Up Time"
$value = $counter.NextValue()
$uptime = [System.TimeSpan]::FromSeconds($counter.NextValue())
"Uptime: $uptime"
"System Boot: " + ((get-date) - $uptime)
