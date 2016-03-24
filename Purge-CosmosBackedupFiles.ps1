[CmdletBinding(ConfirmImpact=[System.Management.Automation.ConfirmImpact]::Medium,SupportsShouldProcess=$true)]
#[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
param (
	[parameter(ValueFromPipeline=$true)]
	[string[]] 
	# files or paths to purge files from
	$path="\\relemeas12\Archive\SearchEngineResultPages",
	[string] 
	# Cosmos backup location
	$cosmosPathUrl="https://cosmos09.osdinfra.net/cosmos/relevance/projects/measurement/SerpsBackup/",
	[int] 
	# maximum age of $path files in days (62 being longest possible for 'two months' old)
	$maxage=62,
	[switch]
	# Pass deleted file information through to output ([IO.FileInfo] objects will still have .Exists=$true)
	$passThru=$false,
	[switch]
	$force=$false
	)
Begin {
	if (!(get-module -ListAvailable -Name Cosmos -ea SilentlyContinue)) { try { throw "Requires Cosmos Powershell module be installed; http://aka.ms/CosmosPowerShell" } catch { throw $_; break;} } # stop execution, display requirement
	if (!(get-module -Name Cosmos -ea SilentlyContinue)) { 
		Import-Module -Name Cosmos
	}
	$PIPELINEINPUT = (-not $PSBOUNDPARAMETERS.ContainsKey("path")) #https://social.technet.microsoft.com/Forums/scriptcenter/en-US/f07fd26a-ec59-44a4-8143-dea182ffae70/powershell-mandatory-parameters-lose-pipeline-input?forum=ITCG
	$earliest = [DateTime]::Today.AddDays(-$maxage)

	function DoIt($thisOne) {
		try {
			$streamInfo = Get-CosmosStream "$cosmosPathUrl$($thisOne.Name)" # -ErrorAction SilentlyContinue not being handled correctly
		} catch {
			$streamInfo = $null
		}
		if ($thisOne.LastWriteTime -and ($thisOne.LastWriteTime -lt $earliest) -and ($streamInfo -ne $null)) {
            if ($passThru) { $thisOne }
			# ShouldProcess provides -Confirm/-WhatIf, $action is optional, additional arguments change semantics 
			if ($pscmdlet.ShouldProcess($thisOne.FullName)) {
				# cmdlets within need `-Confirm:$false` since we've already asked
				Remove-Item $thisOne.FullName -Force:$force -Confirm:$false
			}
		}
	}


}
Process {
    if ($PIPELINEINPUT -and ($_ -ne $null)) {
        $path = $_
    }
    $path | %{
        $onePath = $_
    	if ($_ -is [IO.FileSystemInfo]) {
	    	$onePath = $onePath.FullName
    	}
        try {
    	    Push-Location $onePath
            Write-Verbose $pwd
            dir $onePath | % {
                DoIt $_
            }
        } finally {
    	    Pop-Location
        }
    }
}
End {
}

# 

<#
.DESCRIPTION
	Checks files in $path against the Cosmos stream $cosmosPathUrl; if files 
	are present in the Cosmos path, and they are older than $maxage days, the
	files will be deleted.
.INPUTS
	path strings, IO.FileInfo, IO.DirectoryInfo
.OUTPUTS
	Nothing, or deleted IO.FileInfo objects when -pass
.COMPONENT	
	Cosmos
.EXAMPLE
	.\Purge-CosmosBackedupFiles.ps1 -pass *>>\PurgedFiles.log
.EXAMPLE
    Given \\relemeas12 is a Win2008 R1 server, the available command line tool for creating the task is used:
    PS D:\Tools> schtasks /create /ru networkservice /sc daily /tn Purge-CosmosBackedupFiles /tr "$PSHOME\powershell.exe -nologo -noprofile Get-Date -f o >>D:\tools\Purge-CosmosBackedupFiles.log ; & 'D:\tools\Purge-CosmosBackedupFiles.ps1' -passThru *>>D:\Tools\Purge-CosmosBackedupFiles.log; sleep 10" /st 05:00 /f /rl highest
#>
