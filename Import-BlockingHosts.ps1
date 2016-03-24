# import/replace http://someonewhocares.org/hosts/hosts into end of XP/Vista hosts

$hostsPath = "$env:systemroot\system32\drivers\etc\hosts"
if (!(test-path $hostsPath)) {throw "Can't find hosts file"; Stop}

$wc = new-object System.Net.WebClient
$swcHosts = $wc.DownloadString('http://someonewhocares.org/hosts/hosts')
if (0 -le $swcHosts.count) {throw "Couldn't download new hosts"; Stop}
$swcHosts = $swcHosts.Split([char]0xa)

copy $hostsPath "$hostsPath.$([datetime]::Now.ToString('yyyyMMddTHHmmss'))"

$line = select-string '^\# begin http://someonewhocares.org/hosts/' -path $hostsPath

if (0 -le $line.count) {
	set-content -literalPath $hostsPath -value (gc -literalPath $hostsPath -totalCount ([int]($line[0].LineNumber) - 1)) -encoding ASCII -force
}
add-content -literalPath $hostsPath -value '# begin http://someonewhocares.org/hosts/' -force
add-content -literalPath $hostsPath -value $swcHosts -force

"Done"