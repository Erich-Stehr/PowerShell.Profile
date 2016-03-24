param ([Parameter(Mandatory=$true,ValueFromPipeline=$true)]$source, $target='/sdcard/Books/Webscriptions')
process {
	$f = $source 
	if ($source -isnot [IO.FileSystemInfo]) {
		$f = New-Object IO.FileInfo $source
	}
	$f.FullName; 
	adb -d push "`"$($f.FullName)`"" "`"$target`"" # "`"`"" to cover spaces
}
