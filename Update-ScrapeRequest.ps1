param (
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
	[string[]] 
	# source scrape request
	$source,
	[string] 
	# destination for scrape request, either specific filename or directory for same named file)
	$destination=$pwd,
	[switch]
	$force=$false
	)
Begin {
	$envpwd = [Environment]::CurrentDirectory
	[Environment]::CurrentDirectory = $pwd
	$doc = [xml]"<root/>"
	$destDirInfo = ([IO.DirectoryInfo](resolve-path $destination -ea SilentlyContinue).Path)
	function UpdateNode([string]$xpath, [string]$innerXml) {
		$node = $doc.SelectSingleNode($xpath)
		if ($null -ne $node) {
			$node.InnerXml = $innerXml
		}
	}
}
Process {
	$s = $_
	if ($s -eq $null) { $s = $source }
	$doc.Load($s)
	$now = [DateTimeOffset]::Now
	$isotime = $now.ToString('yyyy-MM-ddTHH:mm:ss.fff')
	$compressed = $now.ToString('yyyyMMddTHHmmss')
	UpdateNode '/Batch/@BatchID' $compressed
	UpdateNode '/Batch/LastUpdate' $isotime
	UpdateNode '/Batch/Jobs/Job/@JobID' $compressed
	UpdateNode '/Batch/RefJobID' $compressed
	if ($destDirInfo.Exists) {
		$name = [IO.Path]::GetFileName($s)
		Write-Debug "Generating file $(Join-path $destDirInfo.FullName $name)"
		$doc.Save((Join-path $destDirInfo.FullName $name))
	} else {
		Write-Debug "Assuming file $destination"
		$doc.Save($destination)
	}
}
End {
	[Environment]::CurrentDirectory = $envpwd
}

<#
.SYNOPSIS
	Copies incoming request files (as .xml) modifying IDs to current datetime
.DESCRIPTION
	x
.INPUTS
	.xml File/FileInfo
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
#>
