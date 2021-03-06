param ($repos="${env:SystemDrive}\repos", $backPath="O:\Information Technology\Development\Subversion repository backup")
del .\repos.zip -ErrorAction SilentlyContinue
zip.exe -r9 .\repos.zip "$repos"
dir $repos -ErrorAction Stop | 
	? { $_.PSIsContainer} |
	% {
		xcopy /e/r/i/c/h/s/z/v/y "$($_.FullName)" "$backPath\$($_.Name)\"
	}