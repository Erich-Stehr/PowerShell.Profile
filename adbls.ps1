# uses adb.exe -d to get object directory listing from connected Android device

# 2012/04/03 edited from http://get-spscripts.com/2011/02/finding-site-template-names-and-ids-in.html
# example: $ht = @{"foo"="bar", "baz"="quuz"}; New-PSObjectFromHashtable $ht
# 2012/04/25: reedited as filter
filter New-PSObjectFromHashtable([Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]$templateValues, $keys=$(@($templateValues.Keys)))
{
	New-Object PSObject -Property $templateValues | Select @($keys)
}

# ("-rw-rw---- root     sdcard_r  1531650 2014-07-20 14:48 IMG_20140720_144801.jpg")
# length in field 4 empty if directory, breaks fixed formatting at [math]::pow(10,9)
# name in field 7 may have whitespace, but (assumption) not leading whitespace
$script:re = [regex]"^(\S+)\s+(\S+)\s+(\S+)\s{1,8}(\d*)\s+(\S+)\s+(\S+)\s+(.*)$"
$androidPlatformTools = "h:\users\erichs\Development\Android\android-sdk-windows\platform-tools"
if ($args[0].Contains(' ')) {
	$a = $args[0]
} else {
	$a = ([regex]"([ ()])").Replace($args[0], '\$0') # mksh takes "\ " to quote space
}

start-process -wait -WindowStyle Hidden "$androidPlatformTools\adb.exe" start-server # keeps daemon from hanging script
& "$androidPlatformTools\adb.exe" -d shell ls -l $a |
% {
	$x = $_ 
	if (![string]::IsNullOrEmpty($x)) {
		if (($x.Length -lt 56) -or ($x.StartsWith("/"))) {
			write-warning $x
		} else {
			$y = @{}
			$m = $re.Match($x)
			if (!$m.Success) {
				Write-Warning "Couldn't parse input line '$x'"
			} else {
				$y.Add("modeUnix",$m.Groups[1].Value)
				$y.Add("Owner",$m.Groups[2].Value)
				$y.Add("Group",$m.Groups[3].Value)
				$y.Add("Length",[int]$m.Groups[4].Value)
				$t = $null; try { $t = [DateTime]"$($m.Groups[5].Value) $($m.Groups[6].Value)" } catch { }
				$y.Add("LastWriteTime",$t)
				if ($x.Length -le 55) { Write-Warning "Short line:$x"}
				$y.Add("Name",$m.Groups[7].Value)
				New-Object PSObject -Property $y  # New-PSObjectFromHashtable
			}
		}
	}
}

# adbls.ps1 /mnt/sdcard/Download/Judas* | ? { !(New-Object IO.FileInfo "C:\Multimedia Files\MP3\Judas Priest\The Essential Judas Priest\$($_.Name)").Exists }
# $artist="BonnieRaitt"; $subpath="Bonnie Raitt\Slipstream" ; adbls.ps1 "/mnt/sdcard/Download/$artist*" | ? { !(New-Object IO.FileInfo "C:\Multimedia Files\MP3\$subpath\$($_.Name)").Exists } | % { $_; h:\users\erichs\Development\android\android-sdk-windows\platform-tools\adb.exe pull ("/mnt/sdcard/Download/$($_.Name)") "C:\Multimedia Files\MP3\$subpath" }
# dir 'H:\users\erichs\stuff\inept epubs\*.epub','H:\users\erichs\stuff\inept epubs\*.pdf' | WrittenDuringLastSpan -span 3.0:0 | ? { !((adbls.ps1 "/mnt/sdcard/Books/$($_.Name)").LastWriteTime) } | % { $_.Name ; H:\users\erichs\Development\android\android-sdk-windows\platform-tools\adb.exe push "$($_.FullName)" /mnt/sdcard/Books }