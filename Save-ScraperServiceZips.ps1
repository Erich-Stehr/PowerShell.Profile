param (
	[Parameter(Mandatory=$true)]
	[string] 
	# build path to work with '\\builds\qdrops\view_Relevance-Infra-Ares_amd64_retail\3764333\a58729'
	$StartBuildPath=$(throw "Requires build path to work with"),
	[switch]
    # skip Azure zip/push
	$noAzure=$false,
	[switch]
    # skip Dtap zip
	$noDtap=$false,
	[switch]
    # skip relemeas19 zip
	$noQ19=$false,
	[switch]
    # skip relemeas17 zip
	$noCentral=$false,
	[switch]
    #skip flighting-1 zip
	$noFlighting=$false,
	[switch]
    # skip DomRelDev02 zip (based in India)
	$noIndia=$false,
	[switch]
    # Skip zipping before pushing to Azure \transfer directories
	$pushonly=$false
	)
$b = (Split-Path (Split-Path $startBuildPath) -Leaf)
Write-Debug $b
if ($StartBuildPath.Contains('retail')) {
	$startDir = Join-Path $startBuildPath 'retail\amd64\Relevancy\ScraperService'
} elseif ($StartBuildPath.Contains('debug')) {
	$startDir = Join-Path $startBuildPath 'debug\amd64\Relevancy\ScraperService'
} else {
	throw "startBuildPath must contain either debug or retail: $startBuildPath"
}

function ZipScraperService([string]$suffix='q17', [string]$extension="config")
{
	if ($pushonly) { return } # skip zipping if only pushing
	"${suffix}/${extension}"
	dir $startDir | ? {!$_.PSIsContainer} | ? { $_.Name -notmatch 'Persona|ScraperService\.exe\..+' -or $_.Name -match "\.${extension}`$" } | sort | % { zip -9j "C:\build${b}${suffix}.zip" $_.FullName }

}


if (!$noQ19) { ZipScraperService 'q19' 'q19' }
if (!$noDtap) { ZipScraperService 'dtap' 'dtap' }
if (!$noFlighting) { ZipScraperService 'f1' 'config\.f1' }
if (!$noCentral) { ZipScraperService 'q17' 'config' }
if (!$noIndia) { ZipScraperService 'stci02' 'stci02' }
if (!$noAzure) {
	push-location "${env:BASEDIR}\private\packages\Ares.Product\src\scraperservice\Tools"
	[Environment]::CurrentDirectory = $pwd
	$vm = XpathScanner.ps1 -xpath //Machine -file ..\Service\VirtualMachines.xml | select -ExpandProperty Name
	Write-Debug ([String]::Join("`r`n", $vm))
	for ($i=1; $i -le $vm.Count; ++$i) {
		$i;
		ZipScraperService "ri$i" ("ritools{0:D3}" -f $i)
		$vm[$i-1]
		.\Send-File.ps1 -filePath "C:\build${b}ri${i}.zip" -vmName $vm[$i-1]
	}
	pop-location
	[Environment]::CurrentDirectory = $pwd
}

<#
.SYNOPSIS
	builds per-server zip packages of ScraperService binaries given \\builds\qdrops location
.DESCRIPTION
	x
.INPUTS
	no pipeline inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
    PS> Save-ScraperServiceZips.ps1 \\builds\qdrops\view_Relevance-Infra-Ares_amd64_retail\3764333\a58729 -noAzure -noDtap -noQ19 -noFlighting -noIndia

    Builds q17/Central package only for build 3764333
.EXAMPLE
    PS> Save-ScraperServiceZips.ps1 \\builds\qdrops\view_Relevance-Infra-Ares_amd64_retail\3764333\a58729

    Builds out full deployment of .zips for all servers of build 3764333, pushing Azure .zips to the appropriate \transfer directories 
#>
