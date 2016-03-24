$wc = new-object System.Net.WebClient
pushd $env:userprofile\Desktop

gc 'Seattle Department of Transportation - home.mht' | 
select-string -pattern "Content-Location: " | 
? { $_ -like '*.gif' -or $_ -like '*.jpg' -or $_ -like '*.css'} | 
% { $url = [uri](($_.ToString().Split((,' '), 2))[1])
	$fname = "${env:userprofile}\My Documents\My Pictures\SDOT\$($url.Segments[-1])"
	$wc.DownloadFile($url, $fname)
}