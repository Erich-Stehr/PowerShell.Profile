param (
	[Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
	[Object]
	# paths/FileInfos to be opened
	$obj
	)
begin {
	$ie = new-object -com "InternetExplorer.Application"
	$ie.Navigate("about:blank")
	$ie.Visible = $true
}
process {
	if ($obj -is [IO.FileInfo]) {
		$path = ($obj | Select-String 'URL=' ).Line
		if ($path.StartsWith('URL=')) { $path = $path.SubString(4) }
	} elseif ($obj -is [System.Array]) {
		$obj | % { $ie.Navigate($_, 4096) }
		$path = $null
	}
	if (![string]::IsNullOrEmpty($path)) {
		$ie.Navigate($path, 4096)
	}
}


<#
.SYNOPSIS
	Takes stream of shortcut files and loads them into tabs in a new instance
	of Internet Explorer 7+
.DESCRIPTION
	x
.INPUTS
	stream of shortcut files
.OUTPUTS
	string[] status messages
.EXAMPLE
#>
