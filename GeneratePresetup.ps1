param (
	[Uri] 
	# (local) site url to work with
	$siteUrl=$(throw "Requires (local) site URL to work with"), # 'http://sea-v-stehre/BrandTools2', # 
	[string] 
	# root of destination directory to pull application files to
	$destPath=$(throw "Requires destination directory to pull application files to") # '.\sample' # 
	)
# check for error causing states
#requires -Version 2.0
Set-StrictMode -Version 2.0
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
$web = Get-SPWeb -Id $siteUrl.AbsoluteUri -ea Stop
[void](resolve-path $destpath -ea Stop)

# open the script with the parameter for the site to be checked
@'
param (
	[string]
	# (local) web URL to be checked 
	$checkSite = $(throw "Requires (local) web URL to be checked"),
	[string]
	# [optional] root location of files to be uploaded
	$fileRoot=$null
	)
# check for error causing states
#requires -Version 2.0
Set-StrictMode -Version 2.0
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
$web = Get-SPWeb -Id $checkSite -ea Stop
if ($fileRoot) { [void](resolve-path $fileRoot -ea Stop) }

function VerifySPFeatureEnabled([Guid] $Id, [string] $name, [Microsoft.SharePoint.SPFeatureScope] $scope)
{
	$feature = Get-SPFeature -Identity $Id -ea SilentlyContinue
	if ($null -eq $feature) {
		trap { break;}
		new-object PSObject | select @{n='FeatureName';e={$name}},@{n='FeatureId';e={$id}},@{n='Scope';e={$scope}},@{n='Url';e={$null}},@{n='Operation';e={"Not installed"}} | write-warning
		#write-warning "Feature '$name' ($id) is not installed"
	} else {
		$fea = $null
		$url = $null
		switch ($scope) {
			([Microsoft.SharePoint.SPFeatureScope]::Farm) {
				$url = $null
				$fea = (Get-SPFeature $Id -farm -ea SilentlyContinue)
			}
			([Microsoft.SharePoint.SPFeatureScope]::WebApplication) {
				$url = (new-object Uri $web.Url).GetLeftPart([System.UriPartial]::Authority)
				$fea = (Get-SPFeature $Id -WebApplication $url -ea SilentlyContinue)
			}
			([Microsoft.SharePoint.SPFeatureScope]::Site) {
				$url = $web.Site.Url
				$fea = (Get-SPFeature $Id -Site $url -ea SilentlyContinue)
			}
			([Microsoft.SharePoint.SPFeatureScope]::Web) {
				$url = $web.Url
				$fea = (Get-SPFeature $Id -Web $url -ea SilentlyContinue)
			}
			default	{
				trap { break; }
				throw "Incorrect scope $scope found, stopping" 
			}
		}
		$tag = $(if ($null -ne $url){' -url '+$url} else {''})
		if ($null -eq $fea) {
			new-object PSObject | select @{n='FeatureName';e={$name}},@{n='FeatureId';e={$id}},@{n='Scope';e={$scope}},@{n='Url';e={$url}},@{n='Operation';e={"Enabling"}} | write-output
			#write-output "Feature '$name' ($id) is being enabled on $scope$tag"
			Invoke-Expression "Enable-SPFeature -Id $Id$tag"
		} else {
			new-object PSObject | select @{n='FeatureName';e={$name}},@{n='FeatureId';e={$id}},@{n='Scope';e={$scope}},@{n='Url';e={$url}},@{n='Operation';e={"Enabled"}} | write-verbose
			#write-verbose "Feature '$name' ($id) is already enabled on $scope$tag"
		}

	}
}

function UploadWebFiles([string]$sourceRoot=$(throw "Must provide root directory of files to upload"),
	[Microsoft.SharePoint.SPWeb]$web)
{
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
	dir -recurse $sourceRoot -exclude '*.etag','*.meta' | % { UploadPSFileWithMetadata $_ }
}

'@

filter WriteSPFeatureVerify
{
	if (([Microsoft.SharePoint.Administration.SPObjectStatus]::Online) -ne $_.Status) {
		"#$($_.ID)`t$($_.DisplayName)`t$($_.Scope)`t$($_.Status)"
	} else {
		"VerifySPFeatureEnabled -id '$($_.ID)' -name '$($_.DisplayName)' -scope $($_.Scope)"
	}
}

Get-SPFeature -Farm | WriteSPFeatureVerify 

Get-SPFeature -WebApplication $siteUrl.GetLeftPart([System.UriPartial]::Authority) | WriteSPFeatureVerify

Get-SPFeature -Site $web.Site | WriteSPFeatureVerify

Get-SPFeature -Web $web | WriteSPFeatureVerify

#Get-SPFeature -Sandbox | WriteSPFeatureVerify # bug? Throwing NullReferenceException in Get-SPFeature

function Copy-Stream([IO.Stream] $source, [IO.Stream] $destination)
{
	$size = 0x2000
	$buffer = new-object byte[] $size
	while (0 -ne $size)
	{
		$size = $source.Read($buffer, 0, $buffer.Length);
		$dest.Write($buffer, 0, $size);
	}
}

function DownloadPSFileWithMetadata([Microsoft.SharePoint.SPFile]$source, [string] $destination)
{
	if (!$destination.EndsWith('\')) { $destination = "$destination\" }
	$name = $source.Name
	$basepath = "$destination$name"
	$dest = $null
	$etag = ""
	$src = $null
	$dest = $null
	try {
		$etagOld = get-content -literalpath "$basepath.etag" -ea SilentlyContinue
		write-debug "Original etag = $etagOld; Current etag = $($source.etag)"
		$src = $source.OpenBinaryStream('None', $null, [ref]$etag)
		if ($etag -ne $etagOld) {
			$dest = [IO.File]::Create($basepath)
			write-debug "basepath = $basepath"
			Copy-Stream $src $dest
			set-content -literalpath "$basepath.etag" -value $etag
		}
	} catch {
		write-warning "Stopped on data stream: $($source.ServerRelativeUrl): $_"
	} finally {
		if ($null -ne $src) { $src.Close() }
		if ($null -ne $dest) { $dest.Close() }
		$src = $null; $dest = $null # prevent accidental reuse
	}

	# collect metadata stream if it exists
	try {
		$src = $source.OpenFileFormatMetaInfoStream($etag)
		write-debug "MetaInfoStream $src for properties.count = $($source.Properties.Count)"
		if ($null -ne $src) {
			$dest = [IO.File]::Create("$basepath.meta")
			write-debug "Metadata to $basepath.meta"
			Copy-Stream $src $dest
		}
	} catch {
		write-warning "Stopped on meta stream: $($source.ServerRelativeUrl): $_"
	} finally {
		if ($null -ne $src) { $src.Close() }
		if ($null -ne $dest) { $dest.Close() }
	}
	
	# collect web parts into .parts.xml file (<parts><part ZoneID="" ZoneIndex="" PersonalizationScope="Shared">...</part></parts>
	if ([System.IO.Path]::GetExtension($name) -eq ".aspx") {
		# from http://blog.mastykarz.nl/inconvenient-provisioning-content-query-web-part-instances/
		# _allows_ loading of CQWP's under SPLimitedWebPartManager
		$oldHttpContext = [Web.HttpContext]::Current
		if ($null -eq $oldHttpContext) {
			[Web.HttpContext]::Current = New-Object 'Web.HttpContext' (
					(New-Object 'Web.HttpRequest' ("", $web.Url, "")),
					(New-Object 'Web.HttpResponse' (New-Object IO.StringWriter))
			)
			[Web.HttpContext]::Current.Items["HttpHandlerSPWeb"] = $web
		}

		$writer = $null
		try {
			$wpm = $source.GetLimitedWebPartManager([System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
			if (($wpm -ne $null) -and ($wpm.WebParts.Count -gt 0)) {
				# settings code originally from http://msdn.microsoft.com/en-us/library/system.xml.xmlwritersettings.aspx
				$settings = New-Object system.Xml.XmlWriterSettings
				$settings.Indent = $true
				$settings.OmitXmlDeclaration = $false
				$settings.NewLineOnAttributes = $false

				# Create a new Writer
				$writer = [system.xml.XmlWriter]::Create("$basepath.parts", $settings)
				$settings.OmitXmlDeclaration = $true  # don't want them in the web parts, they'll choke
				$sw = New-Object System.IO.StringWriter

				#Write some XML: the # namespace for our files and the use of a StringWriter and a XmlTextWriter prevents "The prefix '' cannot be redefined from '' to 'http://schemas.microsoft.com/WebPart/v3' within the same start element tag."
				$ns = 'urn:90CF8BDF-C2B4-48E8-9B66-5989A6BD4243' 
				$writer.WriteStartElement('vmlbt', "parts", $ns)
				# $writer.WriteElementString("PageConnections", $ns, "")
				foreach ( $part in $wpm.WebParts ) {
					if ($part.ExportMode -eq 'None') { continue; } 
					if ($part.GetType().Name -eq 'ErrorWebPart') { throw "$($source.Url): ErrorWebPart: $($part.ErrorMessage)" }
					$writer.WriteStartElement("part", $ns)
					$writer.WriteAttributeString("ZoneID", $ns, $wpm.GetZoneID($part))
					$writer.WriteAttributeString("ZoneIndex", $ns, $part.ZoneIndex)
					$writer.WriteAttributeString("PersonalizationScope", $ns, $wpm.Scope)
					$writer.Flush()
					
					# couldn't directly set contents into $writer, so write into
					#  StringBuilder and WriteNode in from the readers on the SB.
					$sw.GetStringBuilder().Length = 0 # $sb.Clear()
					$sbxw = New-object 'System.Xml.XmlTextWriter' $sw
					$wpm.ExportWebPart($part, $sbxw)
					$sbxw.Flush()
					
					if ($sw.GetStringBuilder().Length -eq 0) {
						throw "No exported information!" 
					}
					$sr = New-Object IO.StringReader ($sw.GetStringBuilder().ToString())
					$sbxr = [System.Xml.XmlReader]::Create($sr)
					if ('None' -ne $sbxr.MoveToContent()) {
						while (!$sbxr.EOF) {
							$writer.WriteNode($sbxr, $true)
						}
						$sbxr.Close()
					}
					
					# $writer.WriteElementString("Connections", $ns, "")
					$writer.WriteEndElement()
					$writer.Flush() #debug, where have we gotten to?
				}
				$writer.WriteEndElement()

				# Flush the writer (and close the file) 
				$writer.Flush()
			}
			
		} catch {
			Write-Warning "Choked at $basepath.parts : $_"	
		} finally {
			if ($writer -ne $null) {$writer.Close()}
			$wpm.Dispose()

			# cleanup to prevent SPSite from being created as anonymous user
			if ($oldHttpContext -ne [Web.HttpContext]::Current) { 
				[Web.HttpContext]::Current = $oldHttpContext 
			}
		}
	}
}
 
function DownloadWebFiles([Microsoft.SharePoint.SPWeb]$web, 
	[string] $destination=$(throw "Must provide root destination directory")) 
{
	function RecurseWebFiles($files, $folders, $destpath)
	{
		if (!(test-path $destpath)) {
			write-verbose (new-item -ItemType Directory -path $destpath -ea Stop)
		}
		$files | % {
			write-debug "File $_ $($_.GetType().FullName)"
			DownloadPSFileWithMetadata $_ $destpath
		}
		$folders | % {
			write-debug "Folder $_ $($_.GetType().FullName)"
			#if ($_.Properties['vti_listname']) { return } # not diving into libraries right now, just application files
			RecurseWebFiles $_.Files $_.SubFolders "$destpath\$($_.Name)"
		}
	}

	$destpath = (resolve-path $destpath).Path
	RecurseWebFiles $web.Files $web.Folders $destpath 
}

@'
if ($fileRoot) { UploadWebFiles $fileRoot $web }

'@

DownloadWebFiles $web $destPath

<#
.SYNOPSIS
	Generates pre-setup script for target siteUrl.
.DESCRIPTION
	Generates script to 
	) Verify active farm, web app, site, and web features
	) (Optionally) push generated file tree into site
	) provide GUID to name resolution table covering site lists.

.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	.\GeneratePresetup.ps1 http://localhost/BrandTools1 .\BTSFiles > .\BTSFiles\Presetup.ps1
#>
