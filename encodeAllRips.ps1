# 2007/11/17 encode all .wav files below the directory of the script to .wma
$thisScript = Get-Item $MyInvocation.MyCommand.Path
Get-ChildItem $thisScript.DirectoryPath -filter *.wav -recurse |
? { !(new-object IO.FileInfo "$($_.Directory.FullName)\$($_.BaseName).wma").Exists } |
% {	$wav = $_
	$album = $wav.Directory
	$author = $album.Parent
	cscript.exe //nologo "C:\Program Files\Windows Media Components\Encoder\WME9.vbs" -a_setting 96_44_2 -a_mode 1 -title """""""$($wav.BaseName)""""""" -album """""""$($album.name)""""""" -author """""""$($author.name)""""""" -input $wav.Fullname -output """""""$($album.FullName)\$($wav.BaseName).wma"""""""

}