function EncodeWmaFile
{
	param($inpath, $albumArtist, $album)
	#$title 
	#$track
	if (([IO.DirectoryInfo]$inpath).Exists) { $outpath = [IO.Path]::Combine([IO.Path]::Combine(([IO.DirectoryInfo]$inpath).FullName, $albumArtist), $album) } elseif (([IO.FileInfo]$inpath).Exists) { $inpath = [IO.FileInfo]$inpath ; $outpath = [IO.Path]::Combine([IO.Path]::Combine($inpath.DirectoryName, $albumArtist), $album)  } else { $outpath = [IO.Path]::Combine([IO.Path]::Combine("$pwd", $albumArtist), $album) } 
	write-host $outpath
	cscript "C:\Program Files\Windows Media Components\Encoder\wmcmd.vbs" -input "$inpath"  -output "$outpath" -a_codec WMA9STD -a_mode 0 -a_setting 96_44_2 -audioonly
}

#dir *.wav | select-object -first 10 | % { $album = "Never Surrender" ; $artist = "Triumph"; $tr = $_.Name.Substring(0,2); $ti = $_.Name.Substring(3,$_.Name.Length - 7); cscript "C:\Program Files\Exact Audio Copy\wme9.vbs" -input "$($_.Fullname)"  -output "$(split-path $_.Fullname)\$artist\$album\$tr-$ti.wma" -a_codec WMA9STD -a_mode 0 -a_setting 96_44_2 -audioonly -title "$ti" -album "$album" -author "$artist" -trackno "$([int]$tr)" -year 1983 -genre Rock }
