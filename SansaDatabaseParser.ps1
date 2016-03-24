$script:H10DB_MAX_DAT_ENTRIES = 5000

function ScriptRoot { Split-Path $MyInvocation.ScriptName }

if (0) {
	$global:data.count
	$global:data[0]
	$global:data[534]
	$data | % { $ratings = @{} } { ++($ratings[$_.popm])} { "popm"; $ratings }
	$data | % { $playcount = @{} } { ++($playcount[$_."PlayCount"]) } { "Playcount"; $playcount }
	$data | % { $YearQ = @{} } { ++($YearQ[$_."YearQ"]) } { "YearQ"; $YearQ }
	$data | % { $Format = @{} } { ++($Format[$_."Format"]) } { "Format"; $Format }
	$data | group-object -property YearQ
}

function global:TestSansaDatabase
{
	[System.Reflection.Assembly]::LoadFrom("$(scriptroot)\SansaDatabase.dll") | ft
	#$targetDir = "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070523b"
	#$targetDir = "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070719"
	#$targetDir = "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20071015"
	#$targetDir = "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20080207"
	$targetDir = "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20081019"
	"Loading $targetDir into `$db, `$dbExample"
	$global:db = new-object SansaDatabase
	$db.Load("$targetDir\PP5000.hdr", "$targetDir\PP5000.dat")
	$db	| fl
	$global:dbExample = new-object SansaDatabase
	$dbExample.Load("$targetDir\PP5000.hdr", "$targetDir\PP5000.dat")

	#$db.fd | select-object id,field_type,max_length,idx_pathname
	#0..32 | %{$db.dat_field_offset[0,$_]}; ""
	$db.Save("$targetDir\PP5001.hdr", "$targetDir\PP5001.dat")
	#0..32 | %{$db.dat_field_offset[0,$_]}; ""
	
	"Comparing hdr"	
	cmp -l "$targetDir\PP5000.hdr" "$targetDir\PP5001.hdr" | select-object -first 15
	"Comparing dat"	
	cmp -l "$targetDir\PP5000.dat" "$targetDir\PP5001.dat" | select-object -first 15
	
	#0..32 | %{"$_`t$($dbOrig.dat_record_offset[497]+$dbOrig.dat_field_offset[497,$_])`t$($db.dat_record_offset[497]+$db.dat_field_offset[497,$_])"}

	if (test-path 'e:\SYSTEM\DATA\PP5000.hdr'
)
	{
		'Loading $global:dbCurrent from Sansa'
		$global:dbCurrent = new-object SansaDatabase
		$dbCurrent.Load('e:\SYSTEM\DATA\PP5000.hdr', 'e:\SYSTEM\DATA\PP5000.dat')
	}

	
	#$db.data | % { $ratings = @{} } { ++($ratings[$_["UserRating"]])} { "UserRating"; $ratings } | ft
	#$db.data | % { $playcount = @{} } { ++($playcount[$_["PlayCount"]]) } { "Playcount"; $playcount } | ft
	#$db.data | % { $YearQ = @{} } { ++($YearQ[$_["YearQ"]]) } { "YearQ"; $YearQ } | ft
	#$db.data | % { $wasplayed = @{} } { ++($wasplayed[$_["142"]]) } { "142/wasplayed"; $wasplayed } | ft
	#$db.data | % { $Format = @{} } { ++($Format[$_."Format"]) } { "Format"; $Format }
}

function global:new-playlist ($path=(throw "Must have -path!"))
{
	BEGIN {
		function script:n ($path) {
			"PLP PLAYLIST`r`nVERSION 1.20`r`n" | 
				% { [Text.Encoding]::Unicode.GetBytes([string]::join("`r`n", $_)+"`r`n") | 
				set-content $script:path -encoding byte -ErrorAction Stop }
			write-debug "script:n $path"
			}
		$script:path = new-object IO.FileInfo $path
		$script:dirname = $script:path.Directoryname
		$script:basename = $script:path.Basename
		$script:ext = $script:path.Extension
		$script:nsongs = 0;
		$script:nfiles = 0;
			#write-debug "$script:dirname\$script:basename$($script:nfiles)$script:ext"
			#write-debug $script:path
	}
	PROCESS {
		if ($null -ne $_)
		{
			if ($script:nsongs -eq 0)
			{
				$script:nfiles += 1;
				#write-debug "$script:dirname\$script:basename$script:nfiles$script:ext"
				$script:path = new-object IO.FileInfo "$script:dirname\$script:basename$script:nfiles$script:ext"
				script:n($script:path)
			}
			if ($_.ToString().Substring(0,7).Contains(", ")) {$line = "$_"} else {$line = "HARP, $_"}
			[Text.Encoding]::Unicode.GetBytes([string]::join("`r`n", $line)+"`r`n") |
					add-content -literalpath $script:path -encoding byte -ErrorAction Stop
			if (++$script:nsongs -eq 300)
			{
				$script:nsongs = 0
			}
		}
	}
}

filter global:CombineSansaDataToPlaylistLine
{
	"$(if ($_.dev -eq 0) {'HARP'} else {'SDMMC'}), $([IO.Path]::Combine($_.FilePath,$_.FileName))"
}

function global:GenerateDatabasePlaylists ( $dbNow, $dirPlaylists='e:\playlists' )
{
	dir "$dirPlaylists" -ErrorAction Stop
	#$FourPlus = @($dbNow.data | ? {$_.UserRating -ge 68 -and $_.Format -eq 0} | % {[IO.Path]::Combine($_.FilePath,$_.FileName)})
	$FourPlus = @($dbNow.data | ? {($_.UserRating -band -bnot 64) -ge 4} | CombineSansaDataToPlaylistLine )
	write-host "FourPlus.count = $($FourPlus.count)"	
	remove-item "$dirPlaylists\FourPlus*.plp"	
	$FourPlus | Randomize-ObjectStream | new-playlist "$dirPlaylists\FourPlus.plp"
	dir "$dirPlaylists\FourPlus*.plp" -ErrorAction Stop

	
	$Unrated = @($dbNow.data | ? { $_.UserRating -eq 0 } | CombineSansaDataToPlaylistLine | Randomize-ObjectStream )
	write-host "Unrated.count = $($Unrated.count)"	
	remove-item "$dirPlaylists\Unrated*.plp"
	$Unrated | new-playlist "$dirPlaylists\Unrated.plp"
	dir "$dirPlaylists\Unrated*.plp" -ErrorAction Stop

	$Shuffled = $dbNow.data | ? { ($_.UserRating -band -bnot 64) -ge 3 } | CombineSansaDataToPlaylistLine | Randomize-ObjectStream 
	write-host "Shuffled.count = $($Shuffled.count)"	
	remove-item "$dirPlaylists\Shuffled?.plp"	
	$Shuffled | new-playlist "$dirPlaylists\Shuffled.plp"
	dir "$dirPlaylists\Shuffled?.plp" -ErrorAction Stop

	$ShuffledCC = @($dbNow.data | ? { $_.FilePath -match 'cc365'} | CombineSansaDataToPlaylistLine | Randomize-ObjectStream) 
	write-host "ShuffledCC.count = $($ShuffledCC.count)"	
	remove-item "$dirPlaylists\ShuffledCC*.plp"
	$ShuffledCC | new-playlist "$dirPlaylists\ShuffledCC.plp"
	dir "$dirPlaylists\ShuffledCC*.plp" -ErrorAction Stop
}

function global:ConnectedDatabase([switch]$noplaylist=$false, [switch]$nozap=$false, [switch]$unratedOnly=$false)
{
	#[System.Reflection.Assembly]::LoadFrom("$(ScriptRoot)\SansaDatabase.dll") | ft
	$global:dbNow = new-object SansaDatabase
	$dbNow.Load('e:\system\data\pp5000.hdr','e:\system\data\pp5000.dat')
	$dbNow | fl

    if ($unratedOnly) {
        $dirPlaylists='e:\playlists'
    	$Unrated = @($dbNow.data | ? { $_.UserRating -eq 0 } | CombineSansaDataToPlaylistLine | Randomize-ObjectStream )
    	write-host "Unrated.count = $($Unrated.count)"	
    	remove-item "$dirPlaylists\Unrated*.plp"
    	$Unrated | new-playlist "$dirPlaylists\Unrated.plp"
    	dir "$dirPlaylists\Unrated*.plp" -ErrorAction Stop
    } else {
    	Transfer-RatingsToWmp $dbNow -verbose | tee-object "$(ScriptRoot)\$((get-date -f o) -replace ':','').transfer.txt"
    	if (!$nozap) {
    		ZapLowRatedSansaTracks $dbNow -verbose	
    	}

    	if (!$noplaylist) {
    		GenerateDatabasePlaylists $dbNow
    	}
    }
}

function global:ZapLowRatedSansaTracks ($db, [int] $starsToKeep=3, [string] $drive='E:\', 
    [scriptblock]$where={$true},
    [switch] $Verbose=$false, [switch] $WhatIf=$false, [switch] $Confirm=$false)
{
	$db.data |
        ? $where |
		#? { ($_.Format -eq 0) -and (($_.UserRating -band -bnot 64) -gt 0) -and (($_.UserRating -band -bnot 64) -lt $starsToKeep) } |
		? { (($_.UserRating -band -bnot 64) -gt 0) -and (($_.UserRating -band -bnot 64) -lt $starsToKeep) } |
		% {
			if ($_.Format -ne 0)
			{
				# removing the database item (not the file) breaks the DRM playback, wait for expire
				#$_.Add("__Sansa_Delete",$true)
			}
			$path = "$($_.FilePath)$($_.FileName)"
			remove-item -literalpath "$drive$path" -force -verbose:$Verbose -whatif:$WhatIf -confirm:$confirm
		}	
}

function global:Trim-Track ( [string] $str )
{
	# remove extensions
	if ($str.EndsWith(".wma") -or $str.EndsWith(".MP3") -or $str.EndsWith(".mp3")) {$str = $str.Substring(0,$str.Length-4)};
	# remove leading track number	
	if ( ( $str.Length -gt 3 ) -and [Char]::IsDigit($str[0]) -and [Char]::IsDigit($str[1]) -and ('-' -eq $str[2])) { $str.Substring(3) } else { $str }	
}

function global:Transfer-RatingsToWmp ( $db, [switch] $WhatIf=$false, [switch] $Confirm=$false, [switch] $Verbose=$false)
{
	$ratingLookup = 0, 1, 25, 50, 75, 99
	$player = new-object -com wmplayer.ocx
	#$player.mediaCollection.getByName()
	$db.data | 
		? { ($_.Format -eq 0) -and (($_.UserRating -band -bnot 64) -gt 0) } |
		% { 
			$datum = $_
			#write-debug "$($datum.TrackTitle), $($datum.AlbumTitle), $($datum.ArtistName)"
			$coll = $player.mediaCollection.getByName($_.TrackTitle)
			if ($coll.count -eq 0) {
				$t2 = Trim-Track $_.TrackTitle
				$coll = $player.mediaCollection.getByName($t2)
			}
			if ($coll.count -ne 0) { 
				0..($coll.count-1) | 
				% { $coll.item($_) } |
				% {
					#write-debug "$($_.GetItemInfo('Title')), $($_.GetItemInfo('WM/AlbumTitle')), $($_.GetItemInfo('WM/AlbumArtist')), $($_.GetItemInfo('UserRating'))"
					#write-debug "$($_.GetItemInfo('Title')), $($_.GetItemInfo('WM/AlbumTitle')), $($_.GetItemInfo('UserRating'))"
					if (((Trim-Track($datum.TrackTitle)) -eq (Trim-Track($_.GetItemInfo("Title")))) -and 
						($datum.AlbumTitle -eq $_.GetItemInfo("WM/AlbumTitle")) -and 
						((0+$datum["AlbumTrack"]) -eq (0+($_.getItemInfo("WM/TrackNumber")))) -and
						(($ratingLookup[$datum.UserRating -band -bnot 64] -ne $_.GetItemInfo("UserRating")) -or ($_.GetItemInfo("UserRating") -eq 0))
						) {
						if ($WhatIf) { write-output "$($_.SourceURL) was rated $($_.GetItemInfo('UserRating')) and would be $($ratingLookup[$datum.UserRating -band -bnot 64])"
						} else {
							if ($Verbose) { write-output "$($_.SourceURL) was rated $($_.GetItemInfo('UserRating')) and is now $($ratingLookup[$datum.UserRating -band -bnot 64])" }
							$_.SetItemInfo("UserRating","{0:D2}" -f ($ratingLookup[$datum.UserRating -band -bnot 64]))
						}
					}
				}
			}
		}
}

function global:Randomize-ObjectStream 
{
	$p = @($input)
	$r = new-object System.Random 
	#write-debug $p.length
	for ($i = $p.length - 1; $i -gt 0; --$i)
	{
		$n = $r.Next($i+1)
		#write-debug "$i $n"
		$t = $p[$i]
		$p[$i] = $p[$n]
		$p[$n] = $t
	}
	$p
}

function global:WMPRatingToStars([int]$rating)
{
	$ratingLookup = 0, 1, 25, 50, 75, 99
	for ($i = 0; $i -lt $ratingLookup.Length; $i++)
	{
		if ($rating -le $ratingLookup[$i])
		{
			$i; break;
		}
	}
	if ($rating -gt 99) { 5 }
}

function global:Import-WmaRatings($db)
{
	$player = new-object -com wmplayer.ocx
	foreach ($datum in $db.data) {
		$itemColl = $player.mediaCollection.getByName($datum["TrackTitle"])
		if (($null -eq $itemColl) -or (0 -eq $itemColl.count)) { continue }
		0..($itemColl.count-1) | % { $itemColl.item($_) } |
			% { if (($datum["AlbumTitle"] -eq $_.getItemInfo("WM/AlbumTitle")) -and
				($datum["ArtistName"] -eq $_.getItemInfo("Author")) -and
				([int]$datum["AlbumTrack"] -eq [int]$_.getItemInfo("WM/TrackNumber")) -and
				(($wmpUserRating = WmpRatingToStars($_.getItemInfo("UserRating"))) -ne $datum['UserRating']) ) {
				if (0 -ne $wmpUserRating
) {
					write-output "$($datum['FilePath'])$($datum['FileName']) was $($datum['UserRating']) and is now $wmpUserRating)"
					$datum["UserRating"] = $wmpUserRating
				}
			}
		}
	}
}
# Import-WMARatings $dbCurrent; $dbCurrent.Save("e:\System\DATA\PP5000.hdr", "e:\System\DATA\PP5000.dat")

function global:Transfer-PreloadRatings($dbOlder, $dbNewer, $deviceDrive="e:")
{
	# hash older preloads (where .data[].Format -ne 0)
	$ht = @{}
	$dbOlder.data | ? { $_.Format -ne 0 } | % { $ht.Add("$($_.ArtistName)¶$($_.AlbumTitle)¶$($_.TrackTitle)¶$($_.AlbumTrack)", $_) }
	write-debug "ht.count = $($ht.count)"

	# handle newer: update UserRating if already hashed, output script to remove track name if not, 	write-debug "dbNewer.data.count = $($dbNewer.data.count)"
	$coll = @($dbNewer.data | ? { $_.Format -ne 0 })
	write-debug "coll.count = $($coll.count)"
	$coll | % { 
		$hashKey = "$($_.ArtistName)¶$($_.AlbumTitle)¶$($_.TrackTitle)¶$($_.AlbumTrack)"
		if ($ht.Contains($hashKey))
		{
			$ths = $ht[$hashKey]
			write-verbose "$hashKey was $($_.UserRating), now $($ths.UserRating)"
			$_.UserRating = $ths.UserRating
		}
		else
		{
			write-output "remove-item '$deviceDrive$($_.FilePath)$($_.FileName)' #$hashKey"
		}
	}
}
#2095370240-982360064 after, before free space on e280r for my ratings

function global:DumpDataByName ([string] $name=$(throw "Must give name!"), [string] $attribute="TrackTitle", $db=$db)
{
	$db.data | ? {$_.($attribute) -match $name} | % { "$($_.ArtistName)`t$($_.AlbumTitle)`t$($_.AlbumTrack)-$($_.TrackTitle)`t$($_.UserRating -band -bnot 64)`t$($_.FileName)" }
}
#  DumpDataByName 'Police' 'ArtistName' #Every Breath You Take
#  DumpDataByName 'Breath' # Every Breath You Take, Speak To Me/Breathe

$DebugPreference = [System.Management.Automation.ActionPreference]::Continue #SilentlyContinue
TestSansaDatabase
