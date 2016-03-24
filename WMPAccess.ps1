#if ($null -eq $wmppia) { $wmppia = [System.Reflection.Assembly]::LoadFrom('C:\WMSDK\WMPSDK9\redist\wmppia.dll') }
#$player = new-object Microsoft.MediaPlayer.Interop.WindowsMediaPlayerClass

$global:player = new-object -com wmplayer.ocx
if ($false) {
$playAll = $player.mediaCollection.getAll()
$mediaItem = $playAll.Item(0)

#$playAll | % { write-host $_.sourceURL, $_.getItemInfo("UserRating") }
#foreach ($z in 90..110) { $playAll.Item($z) | % { write-host $_.sourceURL, $_.getItemInfo("UserRating") } }
#0,1,25,50,75,99

$mediaItems = $(foreach ($z in 0..($playAll.Count-1)) { $playAll.Item($z) } )
$mediaXml = [xml]'<asx version="3"></asx>'  #<entry><ref href="" UserRating=""/></entry>
$mediaItems | 
	? { $_.getItemInfo("UserRating") -gt 1 } |
	% { 
		$entry = $mediaXml.CreateElement('entry')
		[void]$mediaXml.asx.AppendChild($entry)
		$ref = $mediaXml.CreateElement('ref')
		[void]$entry.AppendChild($ref)
		
$ref.SetAttribute('href', $_.sourceURL)
		
$ref.SetAttribute('UserRating', $_.getItemInfo("UserRating").ToString())
	}

out-file fullWmpAccess.asx -input $mediaXml.get_OuterXml()

$inFull = [xml](get-content "$pwd\fullWmpAccess.asx")
$inFull.asx.Entry |
	% {
		$SourceURL = $_.ref.href
		$UserRating = $_.ref.UserRating
		write-debug "$sourceURL, $UserRating"
		$playlist = $player.mediaCollection.getByAttribute("SourceURL", $SourceURL)
		if ($playlist.Count -ne 1) { write-error "Wrong items at $sourceURL!"
; bp; continue }

		$playlist.item(0).setItemInfo("UserRating", $UserRating)

	}

#$fourplus = $infull.SelectNodes('/asx/entry/ref[@UserRating >= 75]')
}

function global:CollectWmpRatingsAsAsx ([int]$n = 0){
	$player = new-object -com wmplayer.ocx
	$playAll = $player.mediaCollection.getAll()

	$global:media = [xml]'<asx version="3"></asx>'  #<entry><ref href=""><AUTHOR>Author</AUTHOR><TITLE>Title</TITLE></entry>

	if ($n -le 0) { $n = $playAll.Count-1 }
	$(foreach ($z in 0..($playAll.Count-1)) { $playAll.Item($z) } ) | 
		? { $_.getItemInfo("UserRating") -gt 0 } |
		select-object -first $n |
		% { 
			$entry = $media.CreateElement('entry')
			[void]$media.asx.AppendChild($entry)

			$ref = $media.CreateElement('ref')
			[void]$entry.AppendChild($ref)
			
$ref.SetAttribute('href', $_.sourceURL)

			$elem = $media.CreateElement('author')
			[void]$entry.AppendChild($elem)
			$elem.set_InnerText($_.getItemInfo("Author"))

			$elem = $media.CreateElement('title')
			[void]$entry.AppendChild($elem)
			$elem.set_InnerText($_.getItemInfo("Title"))

			[void]$entry.AppendChild($media.CreateComment("UserRating=$($_.getItemInfo('UserRating').ToString())")) 
		}

	return $media
}

function global:ImportAsxWmpRatings([string] $asxPath='\\erichsinsp1100\c$\Documents and Settings\Erich\My Documents\WindowsPowerShell\CollectedWmpRatings.asx', [switch]$WhatIf, [switch]$verbose)
{
	if ($verbose -or $WhatIf) {$VerbosePreference = 'Continue'}
	$ratings = new-object Xml.XMLDocument
	$ratings.Load($asxPath)
	
	# build hashtable from href,userRating
	$perFile = @{}
	$ratings.asx.entry | % { if ($_.get_LastChild().get_Value() -match 'UserRating=(\d*)') {$perfile.Add($_.ref.href,$Matches[1]) } }

	# go through the list of sourceUrls and set per hashtable
	$player = new-object -com wmplayer.ocx
	$playAll = $player.mediaCollection.getAll()
	$(foreach ($z in 0..($playAll.Count-1)) { $playAll.Item($z) } ) | 
		? { $perFile.Contains($_.sourceURL) } |
		% {
			$oldRating = $_.getItemInfo("UserRating")
			$src = $_.sourceURL
			$newRating = $perFile[$src]
			if ($oldRating -ne $newRating) { if ($verbose -or $WhatIf) { write-verbose "'$src' was rated $oldRating and is now $newRating"} ; if (!$WhatIf) { $_.setItemInfo("UserRating", $newRating)} }
		}		
	
}

function global:WMPRenameAlbumFilesWithTracks( [string] $albumName )
{
	$playlist = $player.mediaCollection.getByAlbum($albumName)
	0..($playlist.count-1) | % { $playlist.item($_)} | % { 
		$p = $_.getItemInfo("SourceURL")
		$n = split-path $p -leaf
		$t = "{0:D2}" -f [int]$_.getItemInfo("WM/TrackNumber")
		# if ($n.Substring(0,2) -ne $t) {rename-item -path $p -newName ("$t-$n") -whatif -passThru}
		if (($n.Substring(0,2) -ne $t) -and ($t -ne "00")) {get-item -literalpath $p | % { $_.MoveTo("$(split-path $_ -parent)\$t-$n") ; $_ } }
	
	}
}
# WMPRenameAlbumFilesWithTracks "Seattle Rhythm & Blues Volume 1"


# $playAll = $player.mediaCollection.getAll(); 0..($playAll.count-1) | % { $playAll.item($_)} | % { $_.sourceUrl } | ? { ![long]::TryParse(([IO.Path]::GetFileName($_).Substring(0,2)), [ref]$i64) } | % { [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($_)) } | sort-object | Get-Unique | ? { -1 -eq $_.IndexOf(" ") }
# $playAll = $player.mediaCollection.getAll(); 0..($playAll.count-1) | % { $playAll.item($_)} | % { $_.sourceUrl } | ? { ![long]::TryParse(([IO.Path]::GetFileName($_).Substring(0,2)), [ref]$i64) } | % { [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($_)) } | sort-object | Get-Unique | ? { -1 -ne $_.IndexOf(" ") } | %{ WMPRenameAlbumFilesWithTracks $_ }
# $playAll = $player.mediaCollection.getAll(); 0..($playAll.count-1) | % { $playAll.item($_)} | % { $_.sourceUrl } | ? { ![long]::TryParse(([IO.Path]::GetFileName($_).Substring(0,2)), [ref]$i64) } | % { [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($_)) } | sort-object | Get-Unique | ? { -1 -ne $_.IndexOf("  ") } | % { $_.Replace("  ", ": ") } | % { WMPRenameAlbumFilesWithTracks  $_ }



function global:WMPAlbumFiles( [string] $albumName, [int] $removeLtRatingsPercent=0 )
# filterLtPercent passes those files with rating -ge $removeLtRatingsPercent
{
    if ($albumName.Contains('"')) { $albumName = $albumName -replace '"', '""' } # fix WMP bug 2011/12/27, needs doubling of double quotes to recognize album name
	$playlist = $player.mediaCollection.getByAlbum($albumName)
    if ($playlist.count -gt 0)
    {
    	0..($playlist.count-1) | 
	   	   % { $playlist.item($_)} |
		   ? { $rating = $_.getItemInfo('UserRating'); ($rating -eq 0) -or ($rating -ge $removeLtRatingsPercent) } |
		   % { Get-Item -literalpath $_.getItemInfo("SourceURL") }
    }
    else
    {
        throw "Couldn't find album '$albumName': check vs. WMP listing"
    }
}
# WMPAlbumFiles "Seattle Rhythm & Blues Volume 1" 26 # filter out 2 stars and lower

if ($false)
{ 	#fix double WMPRenameAlbumFilesWithTracks prior to the check
	0..($playlist.count-1) | % { $playlist.item($_)} | % { 
		$p = $_.getItemInfo("SourceURL")
		$t = "{0:D2}" -f [int]$_.getItemInfo("WM/TrackNumber")
		rename-item -path ("$(split-path $p)\$t-$(split-path $p -leaf)") -newName $(split-path $p -leaf) -passThru
	}
}

#$Authors = $player.mediaCollection.getAttributeStringCollection("Author","Audio")
#$TitleStrings = $player.mediaCollection.getAttributeStringCollection("Title","Audio") # nope
#$AlbumTitleStrings = $player.mediaCollection.getAttributeStringCollection("WM/AlbumTitle","Audio")
#$EmptyAlbumTitles = $player.mediaCollection.getByAttribute("Album","") 

# $star = $player.mediaCollection.getByName("Shining Star").item(0)
# 0..($star.attributeCount-1) | %{$t = $star.getAttributeName($_); @{$t=$($star.getItemInfo($t))} }
## $star.getItemInfo("UserRating")

function global:GetAllWmpItems()
{
	if ($null -eq $global:AllWmpItems)
	{
		$playlist = $player.mediaCollection.getAll()
		$global:AllWmpItems = 0..($playlist.count-1) | % { $playlist.item($_) }
	}
	$global:AllWmpItems
}

function global:WmpItemAttributes( $item )
{
	$ht = @{}
	for ($i = 0; $i -lt $item.attributeCount; $i++)
	{
		$n = $item.getAttributeName($i)
		$v = $item.getItemInfo($n)
		[void]$ht.Add($n,$v)

	}
	$ht
}

# 20080813
# GetAllWmpItems | select -f 1 | %{WmpItemAttributes $_}
# GetAllWmpItems | ? {($_.getItemInfo('UserRating') -eq  1) -and ($_.getItemInfo('SourceUrl').Contains('cc365org'))} | %{[int]::Parse($_.getItemInfo('FileSize'))} | measure-object -average -sum -min -max
##Count    : 103
##Average  : 6324481.49514563
##Sum      : 651421594
##Maximum  : 45729792
##Minimum  : 113572
# $AllMedia = $player.mediaCollection; GetAllWmpItems | ? {($_.getItemInfo('UserRating') -eq  1) -and ($_.getItemInfo('SourceUrl').Contains('cc365org'))} | %{ $AllMedia.remove($_, $true); remove-item -force $_.getItemInfo('SourceUrl') }
# $global:AllWmpItems = $null
# GetAllWmpItems | ? {($_.getItemInfo('UserRating') -le 25) -and ($_.getItemInfo('SourceUrl').Contains('cc365org'))} | %{[int]::Parse($_.getItemInfo('FileSize'))} | measure-object -average -sum -min -max
##Count    : 228
##Average  : 7026980.19736842
##Sum      : 1602151485
##Maximum  : 97986528
##Minimum  : 120624
# $AllMedia = $player.mediaCollection; GetAllWmpItems | ? {($_.getItemInfo('UserRating') -le 25) -and ($_.getItemInfo('SourceUrl').Contains('cc365org'))} | %{ $AllMedia.remove($_, $true); remove-item -force $_.getItemInfo('SourceUrl') }

#
