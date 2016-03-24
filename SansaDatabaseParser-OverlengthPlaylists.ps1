$script:H10DB_MAX_DAT_ENTRIES = 5000

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

function TestSansaDatabase
{
	[System.Reflection.Assembly]::LoadFrom("$pwd\SansaDatabase.dll") | ft
	#$targetDir = "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070523b"
	#$targetDir = "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070719"
	$targetDir = "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070719"
	$global:db = new-object SansaDatabase
	$db.Load("$targetDir\PP5000.hdr", "$targetDir\PP5000.dat")
	$db	| fl
	$global:dbOrig = new-object SansaDatabase
	$dbOrig.Load("$targetDir\PP5000.hdr", "$targetDir\PP5000.dat")

	#$db.fd | select-object id,field_type,max_length,idx_pathname
	#0..32 | %{$db.dat_field_offset[0,$_]}; ""
	$db.Save("$targetDir\PP5001.hdr", "$targetDir\PP5001.dat")
	#0..32 | %{$db.dat_field_offset[0,$_]}; ""
	
	"Comparing hdr"	
	cmp -l "$targetDir\PP5000.hdr" "$targetDir\PP5001.hdr" | select-object -first 15
	"Comparing dat"	
	cmp -l "$targetDir\PP5000.dat" "$targetDir\PP5001.dat" | select-object -first 15
	
	#0..32 | %{"$_`t$($dbOrig.dat_record_offset[497]+$dbOrig.dat_field_offset[497,$_])`t$($db.dat_record_offset[497]+$db.dat_field_offset[497,$_])"}
	
	#$db.data | % { $ratings = @{} } { ++($ratings[$_["UserRating"]])} { "UserRating"; $ratings } | ft
	#$db.data | % { $playcount = @{} } { ++($playcount[$_["PlayCount"]]) } { "Playcount"; $playcount } | ft
	#$db.data | % { $YearQ = @{} } { ++($YearQ[$_["YearQ"]]) } { "YearQ"; $YearQ } | ft
	#$db.data | % { $wasplayed = @{} } { ++($wasplayed[$_["142"]]) } { "142/wasplayed"; $wasplayed } | ft
	#$db.data | % { $Format = @{} } { ++($Format[$_."Format"]) } { "Format"; $Format }
}

function new-playlist ($path=(throw "Must have -path!"), $value)
{
	BEGIN {
		#if ( (resolve-path $path -ea SilentlyContinue).Exists ) { clear-content (resolve-path $path) }
		if ( test-path $path ) { clear-content (resolve-path $path) }
		"PLP PLAYLIST","VERSION 1.20","" | 
			% { [Text.Encoding]::Unicode.GetBytes([string]::join("`r`n", $_)+"`r`n") | 
			add-content $path -encoding byte }
	}
	END {
		if ($null -eq $value) {
		
			$v2 = new-object System.Collections.ArrayList 1000
			$input | % { if ($_.ToString().Substring(0,7).Contains(", ")) {$v2.Add("$_") | out-null } else {$v2.Add("HARP, $_") | out-null }}
			$value = new-object string[] ($v2.count)
			0..($value.count-1) | % { $value[$_] = $v2[$_] }
		} else {
			0..($value.count-1) | % { $value[$_] = "HARP, $($value[$_])" }
		}		
		
		[Text.Encoding]::Unicode.GetBytes(([string]::Join("`r`n", $value))+"`r`n") | 
			add-content $path -encoding byte
	}
}

filter CombineSansaDataToPlaylistLine
{
	"$(if ($_.dev -eq 0) {'HARP'} else {'SDMMC'}), $([IO.Path]::Combine($_.FilePath,$_.FileName))"
}

function GenerateDatabasePlaylists ( $dbNow, $dirPlaylists='e:\playlists' )
{
	dir "$dirPlaylists"
	#$FourPlus = @($dbNow.data | ? {$_.UserRating -ge 68 -and $_.Format -eq 0} | % {[IO.Path]::Combine($_.FilePath,$_.FileName)})
	$FourPlus = @($dbNow.data | ? {($_.UserRating -band -bnot 64) -ge 4} | CombineSansaDataToPlaylistLine )
	write-host "FourPlus.count = $($FourPlus.count)"	
	#$FourPlus | new-playlist "$dirPlaylists\FourPlus.plp"
	#dir e:\playlists\FourPlus.plp
	
	$Unrated = @($dbNow.data | ? { $_.UserRating -eq 0 } | CombineSansaDataToPlaylistLine | Randomize-ObjectStream )
	write-host "Unrated.count = $($Unrated.count)"	
	$Unrated | new-playlist "$dirPlaylists\Unrated.plp"
	dir "$dirPlaylists\Unrated.plp"

	'AB'.ToCharArray() | % { $FourPlus | Randomize-ObjectStream | new-playlist "$dirPlaylists\FourPlus$_.plp" ; dir "$dirPlaylists\FourPlus$_.plp" }	

	#$dbNow.data | ? { $_.Format -eq 0 -and ($_.UserRating -band -bnot 64) -ne 0 } | % {[IO.Path]::Combine($_.FilePath,$_.FileName)} | Randomize-ObjectStream | new-playlist "$dirPlaylists\ShuffledAll.plp"
#	$ShuffledAll = $dbNow.data | ? { $_.Format -eq 0 -and $_.UserRating -ne 0 } | CombineSansaDataToPlaylistLine | Randomize-ObjectStream 
	$ShuffledAll = $dbNow.data | ? { ($_.UserRating -band -bnot 64) -ge 3 } | CombineSansaDataToPlaylistLine | Randomize-ObjectStream 
	write-host "ShuffledAll.count = $($ShuffledAll.count)"	
	# 1300 can work with poking during load, 1400 causes restart, 2007/09/18 300 recommended max!
	$ShuffledAll | select-object -first 1200 | new-playlist "$dirPlaylists\ShuffledFirst.plp"
	dir "$dirPlaylists\ShuffledFirst.plp"
	$ShuffledAll | select-object -last 1200 | new-playlist "$dirPlaylists\ShuffledLast.plp"
	dir "$dirPlaylists\ShuffledLast.plp"

	$ShuffledCC = $dbNow.data | ? { $_.FilePath -match 'cc365'} | CombineSansaDataToPlaylistLine | Randomize-ObjectStream 
	write-host "ShuffledCC.count = $($ShuffledCC.count)"	
	$ShuffledCC | new-playlist "$dirPlaylists\ShuffledCC.plp"
	dir "$dirPlaylists\ShuffledCC.plp"
}

function ConnectedDatabase
{
	#[System.Reflection.Assembly]::LoadFrom("$pwd\SansaDatabase.dll") | ft
	$global:dbNow = new-object SansaDatabase
	$dbNow.Load('e:\system\data\pp5000.hdr','e:\system\data\pp5000.dat')
	$dbNow | fl

	Transfer-RatingsToWmp $dbNow -verbose | tee-object "$((get-date -f o) -replace ':','').transfer.txt"
	ZapLowRatedSansaTracks $dbNow -verbose	

	GenerateDatabasePlaylists $dbNow
}

function ZapLowRatedSansaTracks ($db, [string] $drive='E:\', [switch] $Verbose=$false, [switch] $WhatIf=$false, [switch] $Confirm=$false)
{
	$db.data |
		#? { ($_.Format -eq 0) -and (($_.UserRating -band -bnot 64) -gt 0) -and (($_.UserRating -band -bnot 64) -lt 3) } |
		? { (($_.UserRating -band -bnot 64) -gt 0) -and (($_.UserRating -band -bnot 64) -lt 3) } |
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

function Trim-Track ( [string] $str )
{
	# remove extensions
	if ($str.EndsWith(".wma") -or $str.EndsWith(".MP3") -or $str.EndsWith(".mp3")) {$str = $str.Substring(0,$str.Length-4)};
	# remove leading track number	
	if ( ( $str.Length -gt 3 ) -and [Char]::IsDigit($str[0]) -and [Char]::IsDigit($str[1]) -and ('-' -eq $str[2])) { $str.Substring(3) } else { $str }	
}

function Transfer-RatingsToWmp ( $db, [switch] $WhatIf=$false, [switch] $Confirm=$false, [switch] $Verbose=$false)
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
					if ((Trim-Track($datum.TrackTitle) -eq Trim-Track($_.GetItemInfo("Title"))) -and 
						($datum.AlbumTitle -eq $_.GetItemInfo("WM/AlbumTitle")) -and 
						($datum["AlbumTrack"] -eq $_.getItemInfo("WM/TrackNumber")) -and
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

function Randomize-ObjectStream 
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

function WMPRatingToStars([int]$rating)
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

function Import-WmaRatings($db)
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

$DebugPreference = [System.Management.Automation.ActionPreference]::Continue #SilentlyContinue
TestSansaDatabase
