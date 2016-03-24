param (
	[IO.FileInfo] 
	# file to upload
	$sourceFile=$(throw "Requires file to upload from"),
	[string] 
	# Root of directory tree file lives in (for verifying folders, default is parent directory)
	$sourceRoot=$(Split-Path $sourceFile -Parent),
	[string] 
	# URL to web
	$destinationWebUrl=$(throw "Requires destinationWebUrl to upload to"),
	[string] 
	# document library name within destinationWebUrl, if file is to be visible within library
	$libraryName=$null,
	[switch]
	# prevents check-in of uploaded file
	$NoCheckin=$false,
	[switch]
	# attempt to publish uploaded file
	$Publish=$false
	)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)

$web = Get-SPWeb $destinationWebUrl -ea Stop
$rootFolder = $web.RootFolder
if (![string]::IsNullOrEmpty($libraryName)) {
	trap { break;}
	$rootFolder = $web.Lists[$libraryName].RootFolder
}

function UploadPSFileWithMetadata([IO.FileInfo]$sourceFile)
{
	if ($sourceFile.Extension -eq '.etag')  { return } # these are not the files we are looking for (they're the server hashes)
	if ($sourceFile.Extension -eq '.meta')  { return } # these are not the files we are looking for (they're the metadata streams)
	if ($sourceFile.Extension -eq '.parts') { return } # these are not the files we are looking for (they're the metadata streams)

	# Open up the streams
	$data = $sourceFile.OpenRead()
	$etag = get-content "$($sourceFile.Fullname).etag" -ea SilentlyContinue
	$meta = [System.IO.Stream]::Null ; try { $meta = (new-object IO.FileInfo "$($sourceFile.Fullname).meta").OpenRead() } catch { $meta = [System.IO.Stream]::Null }
	$parts = $null ; try { $parts = (new-object Xml.XmlTextReader "$($sourceFile.Fullname).parts"); $parts.MoveToContent() } catch { $parts = $null }
	$newEtag = [String]::Empty
	$file = $null

	try {
		# Are the folders there?
		$filepath = $sourceFile.Fullname.Replace($sourceRoot,'')
		$fragments = $filepath.Split("/\".ToCharArray(), [StringSplitOptions]::RemoveEmptyEntries)
		$filepath = [string]::Join($fragments, '\')
		write-debug "filepath = '$filepath'"
		$fld = $null
		$files = $null
		$flds = $rootFolder.SubFolders
		if ($fragments.Count -ge 2) { # verify folders exist in web.Folders hierearchy
			$fragments[0..($fragments.Count-2)] | % {
				trap { break; } # all-stop on uncaught errors
				try { $fld = $flds[$_] } catch { $fld = $null }
				if ($null -eq $fld) {
					$fld = $flds.Add($_)
				}
				$flds = $fld.SubFolders
			}
		}
		if ($null -eq $fld) 
		{ 
			$files = $rootFolder.Files
		} else { 
			$files = $fld.Files
		} 

		# TODO: Do we need checkout?  Do we want the .etag?

		# is the file there already?   
		try { $file = $files[$fragments[-1]] } catch { $file = $null }
		if ($null -eq $file) {
			$file = $files.Add($fragments[-1], $data, $True <# overwrite #>, 
					$True <# checkRequired #>, $meta, [ref]$newEtag)
			Write-Debug "Added file $file"
		} else {
			$file.SaveBinary($data, $True <# checkRequired #>, 
					$True <# createVersion #>, "" <# etagMatch #>, "" <# lockIdMatch #>,
					$meta, $True <# requireWebFilePermissions #>, [ref]$newEtag )
			Write-Debug "Updated file contents $file"
		}
		# if it has web parts, install them
		if ($parts -ne $null) {
			$wpm = $file.GetLimitedWebPartManager([System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
			$ns = 'urn:90CF8BDF-C2B4-48E8-9B66-5989A6BD4243' 
			$wp = null
			while ($parts.Read()) {
				if ($parts.NodeType -ne 'Element') { 
					continue; 
				}
				if ($parts.LocalName -eq 'parts') {
					$parts.ReadToDescendant('part', $ns)
				}
				if ($parts.LocalName -eq 'part') {
					$ZoneID=$parts.GetAttribute("ZoneID", $ns)
					$ZoneIndex=$parts.GetAttribute("ZoneIndex", $ns)
					$PersonalizationScope=$parts.GetAttribute("PersonalizationScope", $ns)
					$err = ""
					$wp = $wpm.ImportWebPart($parts, [ref]$err)
					if ($err -ne "") {
						throw $err
					}
					$wp.ZoneIndex=$ZoneIndex
					$wp.Update()
					$parts.ReadToNextSibling('part')
				}
			}
		}
		
	} finally {
		if ($null -ne $data) { $data.Close() }
		if ([IO.Stream]::Null -ne $meta) { $meta.Close() }
		if ($null -ne $parts) { $parts.Close() }
		if (($null -ne $file) -and (!$NoCheckin)) {
			$file.Checkin("uploaded", [Microsoft.SharePoint.SPCheckinType]::MajorCheckIn); 
		}
		if (($null -ne $file) -and ($Publish) -and 
				($file.InDocumentLibrary) -and 
				($file.Item.ParentList.EnableMinorVersions)) {
			$file.Publish("published from upload"); 
			$file.Approve("approved from upload"); 
		}
	}
}

# work with full paths internally to avoid confusion over which directory is current
if ($sourceRoot.StartsWith('\\')) {
	# resolve-path treats UNC as PoSH-only path; handle separately, but check presence
	[void](resolve-path $sourceRoot -ea Stop)
} else {
	$sourceRoot = (resolve-path $sourceRoot -ea Stop).Path 
}
#dir -recurse $sourceRoot -exclude '*.etag','*.meta' | % { UploadPSFileWithMetadata $_ }
dir $sourceFile -exclude '*.etag','*.meta' | % { UploadPSFileWithMetadata $_ }

<#
.SYNOPSIS
	Upload file(s) to SharePoint Web or Document Library
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Upload-SPFile.ps1 foo.txt $pwd 'http://server/sites/web' 'View Documents'
	Upload-SPFile.ps1 foo.txt -dest 'http://server/sites/web' -lib 'View Documents'
#>
