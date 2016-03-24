gc 'Seattle Department of Transportation - home.mht' | 
select-string -pattern "Content-Location: " | 
? { $_ -like '*.gif' -or $_ -like '*.jpg' } | 
% { $url = [uri](($_.ToString().Split((,' '), 2))[1])
	$fname = "C:\Documents and Settings\esteur\My Documents\My Pictures\SDOT\$($url.Segments[-1])"
	$wc.DownloadFile($url, $fname)
}