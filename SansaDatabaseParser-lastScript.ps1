$script:expectedpredatfieldoffsetpadding = 1088
$script:H10DB_MAX_DAT_ENTRIES = 5000

function Open-EnhancedFileStream ( [string]$path=(throw "Must specify -path"), [IO.FileMode] $fm=[IO.FileMode]::Open, [IO.FileAccess]$fa=[IO.FileAccess]::Read)
{
	trap [Exception] { if ($null -ne $fs) {$fs.Close(); break;}}
	$fs = new-object System.IO.FileStream (([string]$path),$fm,$fa,[IO.FileShare]::ReadWrite)
	$fs |
		add-member -memberType ScriptMethod -name GetInt16 -value {$b = new-object byte[] 2; if (2 -ne $fs.Read($b,0,2)) {throw "GetInt16 couldn't read from $(fs.Name)"}; [BitConverter]::ToInt16($b, 0) } -passthru |
		add-member -memberType ScriptMethod -name GetInt32 -value {$b = new-object byte[] 4; if (4 -ne $fs.Read($b,0,4)) {throw "GetInt32 couldn't read from $(fs.Name)"}; [BitConverter]::ToInt32($b, 0) } -passthru |
		add-member -memberType ScriptMethod -name GetWChar -value {$b = new-object byte[] 2; if (2 -ne $fs.Read($b,0,2)) {throw "GetChar couldn't read from $(fs.Name)"}; [BitConverter]::ToChar($b, 0) } -passthru |
		add-member -memberType ScriptMethod -name GetString -value { $s = ""; while (1) {$ch = $this.GetWChar(); if ([char]0 -eq $ch) { break; } $s += $ch }; $s} -passthru
}

function ParseSansaHdr ( [string]$path=(throw "Must specify -path") )
{
	function ParseFd ($fs)
	{
		$fd = new-object System.Management.Automation.PSObject
		$fd |
		add-member -memberType NoteProperty -name id -value ($fs.GetInt32()) -passthru |
		add-member -memberType NoteProperty -name field_type -value ($fs.GetInt32()) -passthru |
		add-member -memberType NoteProperty -name max_length -value ($fs.GetInt32()) -passthru |
		add-member -memberType NoteProperty -name unknown5 -value ($fs.GetInt32()) -passthru |
		add-member -memberType NoteProperty -name unknown6 -value ($fs.GetInt32()) -passthru |
		add-member -memberType NoteProperty -name has_index -value ($fs.GetInt32()) -passthru |
		add-member -memberType NoteProperty -name unknown7 -value ($fs.GetInt32()) -passthru |
		add-member -memberType NoteProperty -name unknown8 -value ($fs.GetInt32()) -passthru |
		add-member -memberType NoteProperty -name idx_pathname -value $($pos = $fs.Position; $fs.GetString(); $fs.Position = $pos + 512) -passthru
	}

	write-debug "ParseSansaHdr"
	trap [Exception] { if ($null -ne $fs) {$fs.Close(); break;}}
	$fs = Open-EnhancedFileStream $path
	$pos = $fs.Position;

	$global:header = new-object System.Management.Automation.PSObject
	add-member -memberType NoteProperty -name unknown1 -value ($fs.GetInt32()) -inputObject $header -passthru |
	add-member -memberType NoteProperty -name unknown2 -value ($fs.GetInt32()) -passthru |
	add-member -memberType NoteProperty -name pathname_dat -value $($pos = $fs.Position; $fs.GetString(); $fs.Position = $pos + 512) -passthru |
	add-member -memberType NoteProperty -name unknown3 -value ($fs.GetInt32()) -passthru |
	add-member -memberType NoteProperty -name pathname_hdr -value $($pos = $fs.Position; $fs.GetString(); $fs.Position = $pos + 512) -passthru |
	add-member -memberType NoteProperty -name unknown4 -value ($fs.GetInt32()) -passthru |
	add-member -memberType NoteProperty -name num_dat_records -value ($fs.GetInt32()) -passthru |
	add-member -memberType NoteProperty -name num_dat_inactive_records -value ($fs.GetInt32()) -passthru |
	add-member -memberType NoteProperty -name num_dat_fields -value ($fs.GetInt32($buf, $i)) -passthru |
	add-member -memberType NoteProperty -name fd -value @() 

	for ($n = 0; $n -lt $header.num_dat_fields; ++$n)
	{	
		#write-debug $fs.Position
		$header.fd += (ParseFd($fs))
	}
	
	write-debug $fs.Position	
	$fs.Position += $script:expectedpredatfieldoffsetpadding
	write-debug "`n$($fs.Position)"	
	
	add-member -memberType NoteProperty -name max_dat_field_offsets -value @() -inputObject $header
	for ($n = 0; $n -lt $header.num_dat_fields+2; ++$n)
	{	
		$header.max_dat_field_offsets += ($fs.GetInt32())
	}
	write-debug $fs.Position	
	
	add-member -memberType NoteProperty -name dat_size -value ($fs.GetInt32()) -inputObject $header -passthru |
	add-member -memberType NoteProperty -name unknown5 -value ($fs.GetInt32())
	# expect unknown5 -eq 1
	
	# load dat_field_offset[num_dat_fields][H10DB_MAX_DAT_ENTRIES];
	$dat_field_offset = new-object object[] ($script:H10DB_MAX_DAT_ENTRIES)

	for ($m = 0; $m -lt $script:H10DB_MAX_DAT_ENTRIES; ++$m)
	{
		Write-Progress "ParseSansaHdr" "load dat_field_offset $m/$script:H10DB_MAX_DAT_ENTRIES" -percentComplete ($m/$script:H10DB_MAX_DAT_ENTRIES*100)
		$field_offset = new-object Int16[] ($header.num_dat_fields+2)
		for ($n = 0; $n -lt $header.num_dat_fields+2; ++$n)
		{
			$field_offset[$n] = $fs.GetInt16()
		}
		if ($field_offset -ne 0)
		{
			$dat_field_offset[$m] = $field_offset # NOTE: had been ,($field_offset) but [][][]
		}
	}
	Write-Progress "ParseSansaHdr" "load dat_field_offset" -completed
	write-debug $fs.Position
	add-member -memberType NoteProperty -name dat_field_offset -value @($dat_field_offset) -inputObject $header
	
	# load dat_record_offset[H10DB_MAX_DAT_ENTRIES+1]
	
	$dat_record_offset = new-object Int32[] ($script:H10DB_MAX_DAT_ENTRIES+1)

	for ($m = 0; $m -le $script:H10DB_MAX_DAT_ENTRIES; ++$m)
	{
		Write-Progress "ParseSansaHdr" "load dat_record_offset $m/$script:H10DB_MAX_DAT_ENTRIES" -percentComplete ($m/$script:H10DB_MAX_DAT_ENTRIES*100)
		$dat_record_offset[$m] = $fs.GetInt32()
	}
	Write-Progress "ParseSansaHdr" "load dat_record_offset" -completed
	write-debug $fs.Position	
	write-debug "dat_record_offset[0] = $($dat_record_offset[0])"	
	add-member -memberType NoteProperty -name dat_record_offset -value @($dat_record_offset) -inputObject $header

	$fs.Close(); $fs = $null
	$header
}

function ParseSansaDat ( $header=(throw "Must specify -header"), [string]$path=(throw "Must specify -path") )
{
	write-debug "ParseSansaDat"

	trap [Exception] { if ($null -ne $fs) {$fs.Close(); break;}}
	$fs = Open-EnhancedFileStream $path

	$n = $header.num_dat_records
	$global:data = new-object object[] ($n)
	$indexnames = ql dev fpth fnam frmt mtpf tit2 tpe1 talb tcon trck tcom du1 du2 du3 popm 61447 32 57347 57348 57349 57350 pcnt du8 57352 97 ratg 78 61449 mgen buyf 142
	$names = ql dev FilePath FileName Format mtpf TrackTitle ArtistName AlbumTitle Genre AlbumTrack TrackComposerQ du1 Yearx12MonthQ RhapsodyTrackID popm FileLength CopyrightDataQ RhapsodyArtistID RhapsodyAlbumID RhapsodyGenreID 57350 PlayCount du8 57352 97 RatingQ YearQ 61449 mgen buyf 142
	$names = ql dev FilePath FileName Format mtpf TrackTitle ArtistName AlbumTitle Genre AlbumTrack TrackComposerQ du1 Yearx12MonthQ RhapsodyTrackID UserRating FileLength CopyrightDataQ RhapsodyArtistID RhapsodyAlbumID RhapsodyGenreID 57350 PlayCount du8 57352 97 ratg YearQ 61449 mgen buyf 142
	
	for ($i = 0; $i -lt $n; ++$i)
	{
		Write-Progress "ParseSansaDat" "load dat_field_offset $i/$n" -percentComplete ($i/$n*100)
		if ((0 -eq $header.dat_record_offset) -and (0 -ne $i)) { continue; }
		$debugFilePosition = (534 -eq $i)
		$datum = new-object System.Management.Automation.PSObject
		for ($j = 0; $j -lt $header.num_dat_fields; ++$j)
		{
			$fs.Position = $header.dat_record_offset[$i] + $header.dat_field_offset[$i][$j]
			$fd = $header.fd[$j]
			if ($debugFilePosition) { write-debug "Field $($names[$j]): start $($fs.Position)" }
			if ($fd.field_type -eq 1) {
				$datum | add-member -memberType NoteProperty -name $names[$j] -value ($fs.GetString())
			} elseif ($fd.field_type -eq 2) {
				$datum | add-member -memberType NoteProperty -name $names[$j] -value ($fs.GetInt32())
			} else {
				throw "Unrecognized field type $($fd.field_type) in $i : $($names[$j])"
			}
			if ($debugFilePosition) { write-debug "Field $($names[$j]): end $($fs.Position)" }
		}
		$data[$i] = $datum
	}
	Write-Progress "ParseSansaDat" "load dat_field_offset $i/$n" -completed
	
	$fs.Close(); $fs = $null
	return $data
}

function MakeAllItemsPlaylist ( $data )
{
	
}


function TestSansaParser
{
if (0) {
	$fs = Open-EnhancedFileStream "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070131\PP5000.hdr"
	write-debug $fs.Position
	write-debug $fs.GetInt16()
	write-debug $fs.GetInt16()
	write-debug $fs.GetInt32()
	write-debug $fs.GetString()
	write-debug $fs.Position
	$fs.Close()
	write-host ""
}

if (0) {
	$global:header = ParseSansaHdr "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070131\PP5000.hdr"
	$header | format-list
	write-output ""
	$header.fd | ft -auto -wrap
	write-output ""
	$header.max_dat_field_offsets
	write-output ""
	$header.dat_field_offset.Count
	write-output ""
	"header.num_dat_fields = $($header.num_dat_fields)"
	write-output ""
	$header.dat_field_offset[0].getType().FullName
	$header.dat_field_offset[0] | fw
	write-output ""
	$header.dat_field_offset[1] | fw
	write-output ""
	$header.dat_field_offset[2] | fw
	write-output ""

	$global:data = ParseSansaDat $global:header "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070131\PP5000.dat"
	
	$global:data.count
	$global:data[0]
}

if (1) {
	$global:header = ParseSansaHdr "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070523b\PP5000.hdr"
	$header | format-list
	$global:data = ParseSansaDat $global:header "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070523b\PP5000.dat"
	
	$global:data.count
	$global:data[0]
	$global:data[534]
	$data | % { $ratings = @{} } { ++($ratings[$_.popm])} { "popm"; $ratings }
	$data | % { $playcount = @{} } { ++($playcount[$_."PlayCount"]) } { "Playcount"; $playcount }
	$data | % { $YearQ = @{} } { ++($YearQ[$_."YearQ"]) } { "YearQ"; $YearQ }
	$data | group-object -property YearQ

}
}

function TestSansaDatabase
{
	[System.Reflection.Assembly]::LoadFrom("$pwd\SansaDatabase.dll") | ft
	$global:db = new-object SansaDatabase
	#$db.Load("$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070523b\PP5000.hdr", "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070523b\PP5000.dat")
	$db.Load("$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070603\PP5000.hdr", "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070603\PP5000.dat")
	$db	| fl
	
	$db.data | % { $ratings = @{} } { ++($ratings[$_["UserRating"]])} { "UserRating"; $ratings } | ft
	$db.data | % { $playcount = @{} } { ++($playcount[$_["PlayCount"]]) } { "Playcount"; $playcount } | ft
	$db.data | % { $YearQ = @{} } { ++($YearQ[$_["YearQ"]]) } { "YearQ"; $YearQ } | ft
	$db.data | % { $wasplayed = @{} } { ++($wasplayed[$_["142"]]) } { "142/wasplayed"; $wasplayed } | ft
}

function new-playlist ($path=(throw "Must have -path!"), $value)
{
	BEGIN {
		if ( (new-object IO.FileInfo (resolve-path $path)).Exists ) { clear-content (resolve-path $path) }
		"PLP PLAYLIST","VERSION 1.20","" | 
			% { [Text.Encoding]::Unicode.GetBytes([string]::join("`r`n", $_)+"`r`n") | 
			add-content $path -encoding byte }
	}
	PROCESS {
		if ($null -eq $value) { 
			[Text.Encoding]::Unicode.GetBytes([string]"HARP, "+($_.path)+"`r`n") | 
			add-content $path -encoding byte
		}
	}
	END {
		if ($null -ne $value) { 
			$value |
			% { [Text.Encoding]::Unicode.GetBytes([string]"HARP, "+($_.path)+"`r`n") | 
			add-content $path -encoding byte}
		}
	}
}

function ConnectedDatabase
{
	[System.Reflection.Assembly]::LoadFrom("$pwd\SansaDatabase.dll") | ft
	$global:dbNow = new-object SansaDatabase
	$dbNow.Load('e:\system\data\pp5000.hdr','e:\system\data\pp5000.dat')
	$dbNow | fl

	dir e:\playlists
	$dbNow.data | ? {$_.UserRating -ge 68 -and $_.Format -eq 0} | select-object  @{n='path';e={[IO.Path]::Combine($_.FilePath,$_.FileName)}} | new-playlist e:\playlists\FourPlus.plp
	dir e:\playlists\FourPlus.plp	
	$dbNow.data | ? { $_.Format -eq 0 -and $_.UserRating -le 64 } | select-object  @{n='path';e={[IO.Path]::Combine($_.FilePath,$_.FileName)}} | new-playlist e:\playlists\Unrated.plp
	dir e:\playlists\Unrated.plp	
}

function Transfer-RatingsToWmp ( $db, [switch] $WhatIf=$true, [switch] $Confirm=$false)
{
	$ratingLookup = 0, 1, 25, 50, 75, 99
	$player = new-object -com wmplayer.ocx
	#$player.mediaCollection.getByName()
	$db.data | 
		? { ($_.Format -eq 0) -and (($_.UserRating -band -bnot 64) -gt 0) } |
		% { 
			$datum = $_
			write-debug $_.TrackTitle
			$coll = $player.mediaCollection.getByName($_.TrackTitle)
			if ($coll.count -ne 0) { 
				0..($coll.count-1) | 
				% { $coll.item($_) } |
				% {
					if (($datum.TrackTitle -eq $_.GetItemInfo("Title")) -and 
						($datum.AlbumTitle -eq $_.GetItemInfo("WM/AlbumTitle")) -and 
						($datum.ArtistName -eq $_.GetItemInfo("WM/AlbumArtist")) -and 
						(($ratingLookup[$datum.UserRating -band -bnot 64] -ne $_.GetItemInfo("UserRating")) -or ($_.GetItemInfo("UserRating") -eq 0))
						) {
						if ($WhatIf) { write-output "$($_.SourceURL) was rated $($_.GetItemInfo('UserRating')) and would be $($ratingLookup[$datum.UserRating -band -bnot 64])"
						} else {
							$_.SetItemInfo("UserRating","{0:D2}" -f ($datum.UserRating -band -bnot 64))
						}
					}
				}
			}
		}
}

$DebugPreference = [System.Management.Automation.ActionPreference]::Continue #SilentlyContinue
#TestSansaParser
TestSansaDatabase
