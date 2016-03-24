param ([switch] $CreativeCommons=$false)
. "$profilepath\WmpAccess.ps1"

# artist name must match passed source pathname (directory) 
# album name must match WMA database
function Copy-MusicFiles ($artistName, $albumname, $albumroot='E:\Albums', $percentRating=51)
{
	$artistname = $artistname.Replace('"', "'")
	$albumdirname = $albumname.Replace(":", "-")
	$albumdirname = $albumdirname.Replace('"', "'")
	$albumdirname = $albumdirname.Replace('/', "--")
	$albumdirname = $albumdirname.Replace('?', "%")
	$targetPath = "$albumroot\$artistName\$albumdirName"	
	write-output $targetPath
	if (!(test-path -literalPath $targetPath -pathtype container))
	{
		[void](new-item -path (split-path $targetpath -parent) -name "$albumdirname" -type directory -force)
	}
	WMPAlbumFiles $albumname $percentRating | ? {($_ -match $artistName) -or ($artistName -match 'Various Artists')} | ? {$_ -match '(.*)\\' ; $srcpath = $Matches[1]} | % {  $_ | Copy-FilesNotPresent -dest $targetpath -force ; dir -literalpath $srcpath -force -filter *.jpg | Copy-FilesNotPresent -dest $targetpath }
}

Copy-MusicFiles "ABBA" "Gold: Greatest Hits"
#Copy-MusicFiles "Aerosmith" "Toys in the Attic"
#Copy-MusicFiles "Alan Parsons Project" "The Best of the Alan Parsons Project"
#Copy-MusicFiles "Albert King" "The Very Best of Albert King"
Copy-MusicFiles "Aldo Nova" "Portrait of Aldo Nova"
Copy-MusicFiles "America" "The Complete Greatest Hits"
Copy-MusicFiles "Anita Baker" "The Best of Anita Baker"
Copy-MusicFiles "Ashford & Simpson" "Capitol Gold: The Best of Ashford & Simpson"
Copy-MusicFiles "Atlantic Starr" "Ultimate Collection"
Copy-MusicFiles "Big Bad Voodoo Daddy" "Big Bad Voodoo Daddy `[Interscope`]"
Copy-MusicFiles "Big Bad Voodoo Daddy" "Save My Soul"
Copy-MusicFiles "Billy Joel" "Greatest Hits, Vols. 1 & 2 (1973-1985) `[Bonus CD-ROM Track`] Disc 1"
Copy-MusicFiles "Billy Joel" "Greatest Hits, Vols. 1 & 2 (1973-1985) `[Bonus CD-ROM Track`] Disc 2"
#Copy-MusicFiles "Bill Withers" "The Best of Bill Withers: Lean on Me"
#Copy-MusicFiles "Blondie" "The Best of Blondie"
#Copy-MusicFiles "Blood Sweat & Tears" "Blood, Sweat & Tears' Greatest Hits [Remastered]"
Copy-MusicFiles "Blue �yster Cult" "Fire of Unknown Origin"
Copy-MusicFiles "Blue �yster Cult" "Spectres"
Copy-MusicFiles "Bob Seger & the Silver Bullet Band" "Live Bullet"
Copy-MusicFiles "Bob Seger" "Nine Tonight"
Copy-MusicFiles "Bonnie Raitt" "Fundamental"
Copy-MusicFiles "Bonnie Raitt" "The Bonnie Raitt Collection"
Copy-MusicFiles "Bonnie Raitt" "Slipstream"
Copy-MusicFiles "Boston" "Boston"
Copy-MusicFiles "Boston" "Don't Look Back"
Copy-MusicFiles "Boston" "Third Stage"
Copy-MusicFiles "Boz Scaggs" "My Time: The Anthology (1969-1997) Disc 1"
Copy-MusicFiles "Boz Scaggs" "My Time: The Anthology (1969-1997) Disc 2"
Copy-MusicFiles "Brenda Russell" "Get Here"
Copy-MusicFiles "Brian Setzer Orchestra" "The Brian Setzer Orchestra"
#Copy-MusicFiles "Bruce Springsteen" "Greatest Hits"
Copy-MusicFiles "Bryan Adams" "Anthology Disc 1"
Copy-MusicFiles "Bryan Adams" "Anthology Disc 2"
#Copy-MusicFiles "Buster Poindexter" "Buster Poindexter"
#Copy-MusicFiles "Captain & Tennille" "More Than Dancing...Much More"
#Copy-MusicFiles "Captain & Tennille" "Ultimate Collection: The Complete Hits"
Copy-MusicFiles "Cab Calloway" "Are You Hep To The Jive?"
Copy-MusicFiles "Chaka Khan" "Epiphany: The Best of Chaka Khan, Vol. 1"
Copy-MusicFiles "Champaign" "The Very Best of Champaign: How 'Bout Us"
#Copy-MusicFiles "Cheap Trick" "Authorized Greatest Hits"
Copy-MusicFiles "Chubby Carrier and The Bayou Swamp Band" "Rough Guide to Cajun & Zydeco: Bayou Road Disc 2"
Copy-MusicFiles "Cheryl Bentyne" "Something Cool"
Copy-MusicFiles "Chicago" "The Very Best of Chicago: Only the Beginning Disc 1"
Copy-MusicFiles "Chicago" "The Very Best of Chicago: Only the Beginning Disc 2"
Copy-MusicFiles "Commodores" "The Definitive Collection"
Copy-MusicFiles "Dan Hartman" "Keep the Fire Burnin'"
#Copy-MusicFiles "Dave Brubeck Quartet" "Time Out"
#Copy-MusicFiles "David Foster" "Hit Man Returns Disc 1"
Copy-MusicFiles "DeBarge" "The Definitive Collection"
#Copy-MusicFiles "Deep Purple" "Deepest Purple: The Very Best of Deep Purple"
#Copy-MusicFiles "Dokken" "Breaking the Chains"
#Copy-MusicFiles "Dokken" "Tooth And Nail"
#Copy-MusicFiles "Dokken" "Under Lock And Key"
#Copy-MusicFiles "Dokken" "Beast From The East"
#Copy-MusicFiles "Dokken" "Dysfunctional"
#Copy-MusicFiles "Don Dokken" "Up From The Ashes"
Copy-MusicFiles "Don Henley" "Building The Perfect Beast"
Copy-MusicFiles "Don Henley" "The Very Best of Don Henley `[CD/DVD`] `[Deluxe Edition`] Disc 1"
Copy-MusicFiles "Donna Summer" "The Journey: The Very Best of Donna Summer `[Bonus Disc`] Disc 1"
#Copy-MusicFiles "Donna Summer" "The Journey: The Very Best of Donna Summer `[Bonus Disc`] Disc 2"
#Copy-MusicFiles "Dr. Buzzard's Original Savannah Band" "The Very Best of Dr. Buzzard's Original Savannah Band"
Copy-MusicFiles "Dr Jane" "Fossil Fever"
Copy-MusicFiles "Dr John" "Dr. John's Gumbo"
Copy-MusicFiles "Dr John" "Trippin' Live"
#Copy-MusicFiles "Duke Ellington Orchestra" "Digital Duke"
Copy-MusicFiles "Duran Duran" "Greatest"
Copy-MusicFiles "Eagles" "The Complete Greatest Hits (Standard Edition) Disc 1"
Copy-MusicFiles "Eagles" "The Complete Greatest Hits (Standard Edition) Disc 2"
Copy-MusicFiles "Earth, Wind & Fire" "The Eternal Dance Disc 1"
Copy-MusicFiles "Earth, Wind & Fire" "The Eternal Dance Disc 2"
Copy-MusicFiles "Earth, Wind & Fire" "The Eternal Dance Disc 3"
Copy-MusicFiles "Eddie Money" "The Best Of Eddie Money"
Copy-MusicFiles "Elton John" "Goodbye Yellow Brick Road"
Copy-MusicFiles "Elton John" "Greatest Hits"
Copy-MusicFiles "Elton John" "Greatest Hits, 1976-1986"
#Copy-MusicFiles "Elvis Presley" "Elvis: 30 #1 Hits"
#Copy-MusicFiles "Eurythmics" "Greatest Hits"
Copy-MusicFiles "Evelyn ""Champagne"" King" "Platinum & Gold Collection"
##Copy-MusicFiles "Everything But the Girl" "Amplified Heart"
Copy-MusicFiles "Fleetwood Mac" "The Very Best of Fleetwood Mac Disc 1"
Copy-MusicFiles "Fleetwood Mac" "The Very Best of Fleetwood Mac Disc 2"
Copy-MusicFiles "Foreigner" "No End in Sight: The Very Best of Foreigner Disc 1"
Copy-MusicFiles "Foreigner" "No End in Sight: The Very Best of Foreigner Disc 2"
Copy-MusicFiles "Frank Hayes" "Never Set The Cat On Fire"
Copy-MusicFiles "Frank Sinatra" "Nothing But the Best `[Capitol`]"
Copy-MusicFiles "Frankie Valli & the Four Seasons" "The Definitive Pop Collection Disc 1"
Copy-MusicFiles "Frankie Valli & the Four Seasons" "The Definitive Pop Collection Disc 2"
Copy-MusicFiles "George Benson" "The Greatest Hits of All"
#Copy-MusicFiles "George Thorogood" "Maverick"
#Copy-MusicFiles "George Thorogood" "The Baddest of George Thorogood and the Destroyers"
Copy-MusicFiles "George Thorogood & the Destroyers" "2120 South Michigan Ave."
#Copy-MusicFiles "Glenn Miller & the Army Air Force Band" "Masters of Jazz, Vols. 1-5"
#Copy-MusicFiles "Glenn Miller Orchestra" "In the Digital Mood"
Copy-MusicFiles "Hall & Oates" "The Very Best of Daryl Hall & John Oates"
#Copy-MusicFiles "Hall & Oates" "Voices `[Bonus Tracks`]"
#Copy-MusicFiles "Harold Melvin & the Blue Notes-Teddy Pendergrass" "The Essential Harold Melvin & the Blue Notes"
Copy-MusicFiles "Harry Connick, Jr." "When Harry Met Sally"
#Copy-MusicFiles "Harry Connick Jr." "25"
#Copy-MusicFiles "Harry Connick, Jr" "Your Songs"
Copy-MusicFiles "Heart" "Dreamboat Annie"
Copy-MusicFiles "Heart" "Little Queen"
Copy-MusicFiles "Heart" "Dog & Butterfly"
Copy-MusicFiles "Heart" "Bebe Le Strange"
Copy-MusicFiles "Heart" "Private Audition"
Copy-MusicFiles "Heart" "Passionworks"
Copy-MusicFiles "Heart" "Heart"
#Copy-MusicFiles "Heart" "Bad Animals"
Copy-MusicFiles "Heart" "Brigade"
Copy-MusicFiles "Heart" "Greatest Hits `[1998`]"
Copy-MusicFiles "Huey Lewis & The News" "Greatest Hits"
#Copy-MusicFiles "Huey Lewis & The News" "Picture This"
Copy-MusicFiles "INXS" "The Best of INXS"
#Copy-MusicFiles "Iron Maiden" "Somewhere Back In Time: The Best of 1980-1989"
Copy-MusicFiles "Jan & Dean" "Surf City: The Very Best of Jan & Dean"
Copy-MusicFiles "Jackson Browne" "The Very Best of Jackson Browne Disc 1"
Copy-MusicFiles "Jackson Browne" "The Very Best of Jackson Browne Disc 2"
#Copy-MusicFiles "Janis Ian" "Folk Is the New Black `[Japan`]"
#Copy-MusicFiles "Janis Ian" "Best of Janis Ian: The Autobiography Collection Disc 1"
#Copy-MusicFiles "Janis Ian" "Best of Janis Ian: The Autobiography Collection Disc 2"
#Copy-MusicFiles "Janis Ian" "Billie's Bones/Folk Is the New Black Disc 1"
Copy-MusicFiles "Journey" "The Essential Journey Disc 1"
Copy-MusicFiles "Journey" "The Essential Journey Disc 2"
##Copy-MusicFiles "Jordin Kare" "Fire In The Sky"
##Copy-MusicFiles "Judas Priest" "The Essential Judas Priest Disc 1"
##Copy-MusicFiles "Judas Priest" "The Essential Judas Priest Disc 2"
#Copy-MusicFiles "Kansas" "Two For The Show"
#Copy-MusicFiles "Kansas" "The Best of Kansas `[1999`]"
Copy-MusicFiles "Kool & the Gang" "The Very Best of Kool & The Gang"
#Copy-MusicFiles "Lavay Smith & Her Red Hot Skillet Lickers" "Everybody's Talkin' Bout Miss Thing"
Copy-MusicFiles "Lakeside" "Ultimate Collection"
Copy-MusicFiles "Loverboy" "Loverboy Classics: Their Greatest Hits"
Copy-MusicFiles "Manhattan Transfer" "The Anthology: Down in Birdland Disc 1"
Copy-MusicFiles "Manhattan Transfer" "The Anthology: Down in Birdland Disc 2"
Copy-MusicFiles "Maze" "Anthology Disc 1"
Copy-MusicFiles "Maze" "Anthology Disc 2"
Copy-MusicFiles "MFSB" "Love Is the Message: The Best of MFSB"
#Copy-MusicFiles "Michael Jackson" "Thriller `[25th Anniversary Edition Deluxe Edition`] Disc 1"
#Copy-MusicFiles "Michael Jackson" "Michael Jackson's This Is It Disc 1"
Copy-MusicFiles "Midnight Star" "Anniversary Collection"
Copy-MusicFiles "Minnie Riperton" "Capitol Gold: The Best of Minnie Riperton"
Copy-MusicFiles "Moody Blues" "The Story of the Moody Blues - Legend of a Band"
Copy-MusicFiles "Muddy Waters" "Hard Again `[Expanded`]"
#Copy-MusicFiles "Nat King Cole" "The Very Best of Nat King Cole `[Capitol`]"
#Copy-MusicFiles "Natalie Cole" "Unforgettable"
Copy-MusicFiles "Night Ranger" "20th Century Masters - The Millennium Collection: The Best of Night Ranger"
Copy-MusicFiles "One Way" "The Best of One Way: Featuring Al Hudson & Alicia Myers"
#Copy-MusicFiles "Orchestral Manoeuvres in the Dark" "The OMD Singles"
Copy-MusicFiles "Pat Benatar" "Greatest Hits"
Copy-MusicFiles "Patrice Rushen" "Haven't You Heard: The Best of Patrice Rushen"
#Copy-MusicFiles "Paul Revere & the Raiders" "Greatest Hits `[Columbia`]"
Copy-MusicFiles "Pet Shop Boys" "Discography: The Complete Singles Collection"
#Copy-MusicFiles "Pink Floyd" "The Dark Side of the Moon"
Copy-MusicFiles "Prince" "The Very Best of Prince"
Copy-MusicFiles "Rainbow" "Long Live Rock 'n' Roll"
Copy-MusicFiles "Rainbow" "Difficult To Cure"
Copy-MusicFiles "Rainbow" "Bent Out Of Shape"
Copy-MusicFiles "Rainbow" "Final Vinyl Disc 1"
Copy-MusicFiles "Rainbow" "Final Vinyl Disc 2"
#Copy-MusicFiles "REO Speedwagon" "Live: You Get What You Play For"
Copy-MusicFiles "REO Speedwagon" "The Hits"
#Copy-MusicFiles "R.E.M." "Out of Time"
Copy-MusicFiles "Robert Cray Band" "Don't Be Afraid Of The Dark"
Copy-MusicFiles "Robert Cray Band" "I Was Warned"
Copy-MusicFiles "Robert Cray" "Nothin But Love"
#Copy-MusicFiles "Rose Royce" "Greatest Hits `[2005`]"
##Copy-MusicFiles "Roy Orbison" "The All-Time Greatest Hits of Roy Orbison `[Monument`]"
Copy-MusicFiles "Rush" "The Spirit of Radio: Greatest Hits 1974-1987"
Copy-MusicFiles "Scorpions" "The Best of Rockers 'n' Ballads"
#Copy-MusicFiles "Simon & Garfunkel" "The Best of Simon & Garfunkel"
Copy-MusicFiles "Slade" "Keep Your Hands Off My Power Supply"
#Copy-MusicFiles "Soundtrack" "American Graffiti Disc 1"
#Copy-MusicFiles "Soundtrack" "American Graffiti Disc 2"
Copy-MusicFiles "Soundtrack" "Sleepless In Seattle"
#Copy-MusicFiles "Spike Jones" "The Best of Spike Jones, Vol. 1 `[RCA`]"
#Copy-MusicFiles "Spike Jones" "The Best of Spike Jones, Vol. 2 `[RCA`]"
#Copy-MusicFiles "Spike Jones" "Spike Jones Is Murdering the Classics"
##Copy-MusicFiles "Squirrel Nut Zippers" "The Inevitable"
Copy-MusicFiles "Steely Dan" "A Decade of Steely Dan"
Copy-MusicFiles "Steely Dan" "Aja"
Copy-MusicFiles "Steely Dan" "Gold"
#Copy-MusicFiles "Steely Dan" "Two Against Nature"
##Copy-MusicFiles "Steve Miller Band" "Young Hearts: Complete Greatest Hits"
Copy-MusicFiles "Steve Winwood" "Chronicles"
#Copy-MusicFiles "Stevie Ray Vaughan & Double Trouble" "Texas Flood"
#Copy-MusicFiles "Stevie Ray Vaughan and Double Trouble" "Live Alive"
#Copy-MusicFiles "Stevie Ray Vaughan" "The Sky Is Crying"
#Copy-MusicFiles "Stills & Nash (And Young) Crosby" "Daylight Again"
#Copy-MusicFiles "Taj Mahal" "The Essential Taj Mahal Disc 1"
#Copy-MusicFiles "Taj Mahal" "The Essential Taj Mahal Disc 2"
#Copy-MusicFiles "Talking Heads" "Popular Favorites 1984-1992: Sand in the Vaseline Disc 1"
#Copy-MusicFiles "Talking Heads" "Popular Favorites 1984-1992: Sand in the Vaseline Disc 2"
Copy-MusicFiles "Tears for Fears" "20th Century Masters - The Millennium Collection: The Best of Tears for Fears"
Copy-MusicFiles "Tears for Fears" "Songs from the Big Chair `[UK Bonus Tracks`]"
#Copy-MusicFiles "Ted Nugent" "The Essential Ted Nugent Disc 1"
#Copy-MusicFiles "Ted Nugent" "The Essential Ted Nugent Disc 2"
Copy-MusicFiles "Teena Marie" "Greatest Hits `[Epic`]"
Copy-MusicFiles "Teena Marie" "Ultimate Collection"
#Copy-MusicFiles "Tesla" "Mechanical Resonance"
Copy-MusicFiles "Tesla" "Time's Makin Changes: The Best of Tesla"
#Copy-MusicFiles "The Association" "The Association's Greatest Hits"
Copy-MusicFiles "The Average White Band" "Pickin' Up the Pieces: The Best of Average White Band (1974-1980)"
Copy-MusicFiles "The B-52's" "Time Capsule"
Copy-MusicFiles "The B-52's" "With the Wild Crowd!: Live in Athens, GA"
#Copy-MusicFiles "The Bar-Kays" "The Best of the Bar-Kays"
Copy-MusicFiles "The Beach Boys" "Sounds of Summer: The Very Best of the Beach Boys"
Copy-MusicFiles "The Bee Gees" "Number Ones `[Bonus DVD`] Disc 1"
Copy-MusicFiles "The Blues Brothers" "Briefcase Full of Blues"
Copy-MusicFiles "The Blues Brothers" "Made In America"
##Copy-MusicFiles "The Cars" "Complete Greatest Hits"
#Copy-MusicFiles "The Clash" "The Singles `[2007`]"
#Copy-MusicFiles "The Doors" "Greatest Hits `[LP`]"
Copy-MusicFiles "The Dirty Dozen Brass Band" "This Is Jazz, Vol. 30"
Copy-MusicFiles "The Emotions" "Best of My Love: The Best of the Emotions"
Copy-MusicFiles "The Four Tops" "Keepers of the Castle: Their Best 1972-1978"
Copy-MusicFiles "The Gap Band" "Ultimate Collection"
#Copy-MusicFiles "The Go-Go's" "Return to the Valley of the Go-Go's Disc 1"
#Copy-MusicFiles "The Go-Go's" "Return to the Valley of the Go-Go's Disc 2"
#Copy-MusicFiles "The Guess Who" "Anthology Disc 1"
#Copy-MusicFiles "The Guess Who" "Anthology Disc 2"
#Copy-MusicFiles "The Hollies" "Classic Masters"
Copy-MusicFiles "The Main Attraction" "By Request"
#Copy-MusicFiles "The Mamas & The Papas" "Gold Disc 1"
#Copy-MusicFiles "The Mamas & The Papas" "Gold Disc 2"
#Copy-MusicFiles "The New Orleans Ragtime Orchestra" "Creole Belles"
#Copy-MusicFiles "The Ohio Players" "Funk on Fire: The Mercury Anthology Disc 1"
#Copy-MusicFiles "The Ohio Players" "Funk on Fire: The Mercury Anthology Disc 2"
Copy-MusicFiles "The Pointer Sisters" "Goldmine: The Best of The Pointer Sisters Disc 1"
Copy-MusicFiles "The Pointer Sisters" "Goldmine: The Best of The Pointer Sisters Disc 2"
Copy-MusicFiles "The Rolling Stones" "Jump Back: The Best of the Rolling Stones 1971-1993"
Copy-MusicFiles "The Spinners" "One of a Kind Love Affair Disc 1"
Copy-MusicFiles "The Spinners" "One of a Kind Love Affair Disc 2"
#Copy-MusicFiles "The Who" "Quadrophenia Disc 1"
#Copy-MusicFiles "The Who" "Quadrophenia Disc 2"
##Copy-MusicFiles "The Who" "Greatest Hits `[Geffen`]"
Copy-MusicFiles "Three Dog Night" "The Complete Hit Singles"
#Copy-MusicFiles "Tina Turner" "Tina!"
Copy-MusicFiles "Tom Smith" "Domino Death"
Copy-MusicFiles "Tom Petty & The Heartbreakers" "Anthology: Through the Years Disc 1"
Copy-MusicFiles "Tom Petty & The Heartbreakers" "Anthology: Through the Years Disc 2"
##Copy-MusicFiles "Toni Braxton" "Secrets"
#Copy-MusicFiles "Toni Tennille" "More Than You Know `[Bonus Tracks`]"
Copy-MusicFiles "Toto" "Past to Present 1977-1990"
Copy-MusicFiles "Triumph" "Livin' for the Weekend: Anthology Disc 1"
Copy-MusicFiles "Triumph" "Livin' for the Weekend: Anthology Disc 2"
Copy-MusicFiles "Triumph" "Surveillance"
Copy-MusicFiles "Triumph" "The Sport of Kings"
Copy-MusicFiles "Van Halen" "Fair Warning"
Copy-MusicFiles "Van Halen" "Women and Children First"
Copy-MusicFiles "Van Halen" "OU812"
Copy-MusicFiles "Van Halen" "A Different Kind of Truth"
Copy-MusicFiles "Van Morrison" "The Best of Van Morrison `[Mercury`]"
Copy-MusicFiles "Various Artists" "A-Z of Soul Classics Disc 1"
Copy-MusicFiles "Various Artists" "A-Z of Soul Classics Disc 2"
1980..1988 | % { Copy-MusicFiles "Various Artists" "Billboard Top Hits: $_" }
Copy-MusicFiles "Various Artists" "Billboard Top Rock & Roll Hits: 1969"
#Copy-MusicFiles "Various Artists" "Classic Ragtime Roots & Offshoots"
Copy-MusicFiles "Various Artists" "Frat Rock! `[Box & Bonus Disc`] Disc 1"
Copy-MusicFiles "Various Artists" "Son of Frat Rock"
Copy-MusicFiles "Various Artists" "Grandson of Frat Rock!, Vol. 3"
Copy-MusicFiles "Various Artists" "Grease `[Original Soundtrack`]"
#Copy-MusicFiles "Various Artists" "Happy Anniversary, Charlie Brown!"
Copy-MusicFiles "Various Artists" "Irish Drinking Songs `[CBS`]"
Copy-MusicFiles "Various Artists" "Millennium Party `[Rhino Box`] Disc 5"
Copy-MusicFiles "Various Artists" "Millennium Party: Funk"
Copy-MusicFiles "Various Artists" "New Millennium Funk Party"
Copy-MusicFiles "Various Artists" "Pure Disco `[Polygram`]"
Copy-MusicFiles "Various Artists" "Pure Disco, Vol. 2"
Copy-MusicFiles "Various Artists" "Rough Guide To Cajun & Zydeco Disc 1"
Copy-MusicFiles "Various Artists" "Seattle Rhythm & Blues Volume 1"
Copy-MusicFiles "Various Artists" "Smooth Grooves: A Sensual Collection, Vol. 1"
Copy-MusicFiles "Various Artists" "Smooth Grooves: Essential Collection"
Copy-MusicFiles "Various Artists" "The Greatest Slow Jams"
Copy-MusicFiles "Various Artists" "`"Soulsville, U.S.A`" Stax Classics 1965-1973"
Copy-MusicFiles "Walt Disney" "The Enchanted Tiki Room"
Copy-MusicFiles "Wang Chung" "20th Century Masters - The Millennium Collection: The Best of Wang Chung"
#Copy-MusicFiles "Warren Zevon" "Genius: The Best of Warren Zevon"
##Copy-MusicFiles "Weird Al Yankovic" "The Essential Weird Al Yankovic Disc 1"
##Copy-MusicFiles "Weird Al Yankovic" "The Essential Weird Al Yankovic Disc 2"
Copy-MusicFiles "Whitesnake" "Slide It In"
Copy-MusicFiles "Whitesnake" "Slip of the Tongue"
Copy-MusicFiles "Whitesnake" "Whitesnake"
#Copy-MusicFiles "Yes" "Greatest Hits"
#Copy-MusicFiles "ZZ Top" "ZZ Top Greatest Hits"
#Copy-MusicFiles "" ""

if ($CreativeCommons) {
    $player = new-object -com wmplayer.ocx
    $playAll = $player.mediaCollection.getAll()
    $mediaItems = 0..($playAll.Count-1) | % { $playAll.Item($_) }
    #$cc = 
    $mediaItems | 
    	? { $_.sourceUrl -match 'cc365org' } |
    	? { $rating = $_.getItemInfo("UserRating") ; ($rating -eq 0) -or ($rating -gt $percentRating) } |
    	... sourceUrl | 
    	? {$_ -match '.*\\cc365org\\((.*)\\.*)'} | 
    	sort-object | 
    	% { [void]($_ -match '.*\\cc365org\\((.*)\\.*)') ; 
	       	$partpath = $matches[2];
    		$filename = $matches[1];
	       	#write-debug "$partpath`t$filename"
    		new-item -type directory "e:\Albums\cc365org\$partpath" -ea SilentlyContinue ;
    		dir $_ | copy-FilesNotPresent -dest "e:\Albums\cc365org\$partpath" }
}
