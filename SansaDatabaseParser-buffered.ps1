function FileAsByteArray( [string]$path )
{
	trap [Exception] { if ($null -ne $fs) {$fs.Close(); break;}}
	$fs = new-object System.IO.FileStream (([string]$path),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
	$buf = new-object byte[] $fs.Length
	$off = 0
	do
	{
		$cb = $fs.Read($buf, $off, $fs.Length-$off)
		$off += $cb
	} while ($off -lt $fs.Length)
	$fs.Close()
	return $buf
}

function BuildWStringFromByteArray ( [byte[]] $buf, [int] $start, [int] $maxBytes )
# pick up Unicode characters from $buf starting at $start until '\0'L or $maxLen bytes have been eaten
{
	$maxEnd = [Math]::Min($start + $maxBytes, ($buf.Length))
	$sb = new-object System.Text.StringBuilder ([int]($maxEnd/2))
	#write-debug "$start + $maxbytes = $maxEnd"
	
	for ($i = $start; $i -lt $maxEnd; $i += 2)
	{
		$ch = [BitConverter]::ToChar($buf, $i)
		if (0 -eq [int]$ch)
		{
			break;
		}
		#write-debug "$ch  $i"
		[void]$sb.Append($ch)
	}
	return $sb.ToString()
	# "Hello" -eq (BuildWStringFromByteArray ([System.Text.Encoding]::Unicode.GetBytes("Hello`0")) 0 25)
	# "Hel" -eq (BuildWStringFromByteArray ([System.Text.Encoding]::Unicode.GetBytes("Hello`0")) 0 6)
}

$script:expectedpredatfieldoffsetpadding = 1088
$script:H10DB_MAX_DAT_ENTRIES = 5000

function ParseSansaHeader ( [byte[]] $buf )
{
	function ParseFd ([ref]$i)
	{
		$fd = new-object System.Management.Automation.PSObject
		add-member -memberType NoteProperty -name id -value ([BitConverter]::ToInt32($buf, $i.Value)) -inputObject $fd; $i.Value += 4 
		add-member -memberType NoteProperty -name field_type -value ([BitConverter]::ToInt32($buf, $i.Value)) -inputObject $fd; $i.Value += 4 
		add-member -memberType NoteProperty -name max_length -value ([BitConverter]::ToInt32($buf, $i.Value)) -inputObject $fd; $i.Value += 4 
		add-member -memberType NoteProperty -name unknown5 -value ([BitConverter]::ToInt32($buf, $i.Value)) -inputObject $fd; $i.Value += 4 
		add-member -memberType NoteProperty -name unknown6 -value ([BitConverter]::ToInt32($buf, $i.Value)) -inputObject $fd; $i.Value += 4 
		add-member -memberType NoteProperty -name has_index -value ([BitConverter]::ToInt32($buf, $i.Value)) -inputObject $fd; $i.Value += 4 
		add-member -memberType NoteProperty -name unknown7 -value ([BitConverter]::ToInt32($buf, $i.Value)) -inputObject $fd; $i.Value += 4 
		add-member -memberType NoteProperty -name unknown8 -value ([BitConverter]::ToInt32($buf, $i.Value)) -inputObject $fd; $i.Value += 4 
		add-member -memberType NoteProperty -name idx_pathname -value $(BuildWStringFromByteArray $buf $i.Value 512) -inputObject $fd; $i.Value += 512 
		
		$fd
	}
	$global:header = new-object System.Management.Automation.PSObject
	$i = 0
	add-member -memberType NoteProperty -name unknown1 -value ([BitConverter]::ToInt32($buf, $i)) -inputObject $header; $i += 4 
	add-member -memberType NoteProperty -name unknown2 -value ([BitConverter]::ToInt32($buf, $i)) -inputObject $header; $i += 4 
	add-member -memberType NoteProperty -name pathname_dat -value $(BuildWStringFromByteArray $buf $i 512) -inputObject $header; $i += 512  
	add-member -memberType NoteProperty -name unknown3 -value ([BitConverter]::ToInt32($buf, $i)) -inputObject $header; $i += 4 
	add-member -memberType NoteProperty -name pathname_hdr -value $(BuildWStringFromByteArray $buf $i 512) -inputObject $header; $i += 512 
	add-member -memberType NoteProperty -name unknown4 -value ([BitConverter]::ToInt32($buf, $i)) -inputObject $header; $i += 4 
	add-member -memberType NoteProperty -name num_dat_records -value ([BitConverter]::ToInt32($buf, $i)) -inputObject $header; $i += 4 
	add-member -memberType NoteProperty -name num_dat_inactive_records -value ([BitConverter]::ToInt32($buf, $i)) -inputObject $header; $i += 4 
	add-member -memberType NoteProperty -name num_dat_fields -value ([BitConverter]::ToInt32($buf, $i)) -inputObject $header; $i += 4 
	add-member -memberType NoteProperty -name fd -value @() -inputObject $header
	for ($n = 0; $n -lt $header.num_dat_fields; ++$n)
	{	
		write-debug $i	
		$header.fd += (ParseFd([ref]$i))
	}
	
	write-debug $i	
	$i += $script:expectedpredatfieldoffsetpadding
	write-debug "`n$i"	

	add-member -memberType NoteProperty -name max_dat_field_offsets -value @() -inputObject $header
	for ($n = 0; $n -lt $header.num_dat_fields+2; ++$n)
	{	
		$header.max_dat_field_offsets += ([BitConverter]::ToInt32($buf, $i)); $i += 4
	}
	write-debug $i	
	
	add-member -memberType NoteProperty -name dat_size -value ([BitConverter]::ToInt32($buf, $i)) -inputObject $header; $i += 4 
	add-member -memberType NoteProperty -name unknown5 -value ([BitConverter]::ToInt32($buf, $i)) -inputObject $header; $i += 4 
	# expect unknown5 -eq 1
	
	# load dat_field_offset[num_dat_fields][H10DB_MAX_DAT_ENTRIES];
	$dat_field_offset = @()

	for ($m = 0; $m -lt $script:H10DB_MAX_DAT_ENTRIES; ++$m)
	{
		$field_offset = @()
		for ($n = 0; $n -lt $header.num_dat_fields+2; ++$n)
		{
			$field_offset += ,([BitConverter]::ToInt16($buf, $i))
			$i += 2
		}
		if ($field_offset -ne 0)
		{
			$dat_field_offset += ,($field_offset)
		}
	}
	write-debug $i	
	write-debug "dat_field_offset: = $(get-typename $dat_field_offset)"	
	write-debug "dat_field_offset.count = $($dat_field_offset.count)"	
	add-member -memberType NoteProperty -name dat_field_offset -value @($dat_field_offset) -inputObject $header
	
	# load dat_record_offset[H10DB_MAX_DAT_ENTRIES+1]
	
	$dat_record_offset = @()

	for ($m = 0; $m -le $script:H10DB_MAX_DAT_ENTRIES; ++$m)
	{
		$dat_record_offset += @([BitConverter]::ToInt32($buf, $i))
		$i += 4
	}
	write-debug $i	
	write-debug "dat_record_offset.count = $($dat_record_offset.count)"	
	write-debug "dat_record_offset[0] = $($dat_record_offset[0])"	
	add-member -memberType NoteProperty -name dat_record_offset -value @($dat_record_offset) -inputObject $header
	
	
	$header	
}

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
		write-debug $fs.Position
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
			$field_offset[$n] = ,($fs.GetInt16())
		}
		if ($field_offset -ne 0)
		{
			$dat_field_offset[$m] = ,($field_offset)
		}
	}
	Write-Progress "ParseSansaHdr" "load dat_field_offset" -completed
	write-debug $fs.Position
	write-debug "dat_field_offset: = $(get-typename $dat_field_offset)"	
	write-debug "dat_field_offset.count = $($dat_field_offset.count)"	
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
	
}

function MakeAllItemsPlaylist ( $data )
{
	
}


function TestSansaParser
{
	$fs = Open-EnhancedFileStream "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070131\PP5000.hdr"
	write-debug $fs.Position
	write-debug $fs.GetInt16()
	write-debug $fs.GetInt16()
	write-debug $fs.GetInt32()
	write-debug $fs.GetString()
	write-debug $fs.Position
	$fs.Close()
	write-host ""

if (0) {	write-debug "FileAsByteArray"
	if ($global:bufHdr -eq $null)	{ $global:bufHdr = FileAsByteArray("$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070131\PP5000.hdr") }
	if ($global:bufHdr -eq $null)	{ break; }
	write-debug "ParseSansaHeader"
	$global:header = ParseSansaHeader $bufHdr
}
	$global:header = ParseSansaHdr "$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070131\PP5000.hdr"
	$header | format-list
	write-output ""
	$header.fd | format-list
	write-output ""
	$header.max_dat_field_offsets
	write-output ""
	$header.dat_field_offset.Count
	write-output ""
	"header.num_dat_fields = $($header.num_dat_fields)"
	write-output ""
	$header.dat_field_offset[0], $header.dat_field_offset[0].count
	write-output ""
	$header.dat_field_offset[1], $header.dat_field_offset[1].count
	write-output ""
	$header.dat_field_offset[2], $header.dat_field_offset[2].count
	write-output ""
#	$header.dat_field_offset[($H10DB_MAX_DAT_ENTRIES)-1], $header.dat_field_offset[($H10DB_MAX_DAT_ENTRIES)-1].count
#	write-output ""


if (0) {	write-debug "FileAsByteArray"
	if ($global:bufDat -eq $null)	{ $global:bufDat = FileAsByteArray("$env:userprofile\Desktop\Sansa System-DATA 20070131\DATA20070131\PP5000.dat") }
	if ($global:bufDat -eq $null)	{ break; }
	$global:data = ParseSansaDat $global:header $global:bufDat
	
	$global:data.count
	$global:data[0]
	}
}

$DebugPreference = [System.Management.Automation.ActionPreference]::Continue #SilentlyContinue
TestSansaParser
