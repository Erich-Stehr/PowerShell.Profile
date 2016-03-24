# 2007/09/28 encode Audacity created .wav files to .wma
# WME9.vbs extended version of WMCmd.vbs from Exact Audio Copy
# 	includes -album, -title, -trackno, artist/author
param($path='??-*.wav', $album=$null, $author=$null) 
dir $path | 
? { $_ -match "(\d\d)-(.*)\.wav" } | 
% { if ($album -eq $null) { $album = (split-path -leaf (convert-path -l (split-path $_ ))) }; 
	if ($author -eq $null) { $author = (split-path -leaf (convert-path -l (split-path (convert-path -l (split-path $_ ))))) } ;
	cscript.exe //nologo "C:\Program Files\Windows Media Components\Encoder\WME9.vbs" -a_setting 96_44_2 -a_mode 1 -title """""""$($Matches[2])""""""" -trackno """""""$($Matches[1])""""""" -album """""""$album""""""" -author """""""$author""""""" -input $_.Fullname -output (join-path (split-path -parent $_.Fullname) "$($Matches[1])-$($Matches[2]).wma") }

#dir ??-*.wav | ? { $_ -match "(\d\d)-(.*)\.wav" } | % { $_ ; """""""$($Matches[2])""""""" }
