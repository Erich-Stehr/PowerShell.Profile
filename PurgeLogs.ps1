param (
	[string[]] 
	# paths to purge
	$path = @("C:\DeviceShim-Published\MDDBGeneration\*.xml", 
			"C:\DeviceShim\SqlAgentJobs\Daily_SLAPIUpload\dmTestShare-Replica\Backup"),
	[TimeSpan]
	# age of files to purge
	$age = (New-Timespan -days 5),
	[switch]
	$verbose=$false,
	[switch]
	$whatif=$false
)
Write-Verbose ([DateTime]::Now.ToString("o"))
$path | 
	% {
		$files = (dir -ea continue $_)
		$purgeFiles = @( $files | ? {$_.LastWriteTime -lt ([DateTime]::Now - $age)} | sort LastWriteTime)
		if (($purgeFiles.Count -ne 0) -and ($purgeFiles.Count -eq $files.Count)) {
			$purgeFiles.RemoveAt($purgeFiles.Count - 1) # don't remove _everything_, _especially_ if the last target is old
		}
		if ($verbose) {
			$purgeFiles
		}
		if ($purgeFiles.Count -gt 0) {
			$purgeFiles | % { del -rec -force -verbose -whatif:$whatif -ea continue $_.FullName }
		}
	}

<#
.SYNOPSIS
	Purges $path of files older than $age
.DESCRIPTION
	Given $path and $age, delete all of the files in the $path collection
	older than $age, unless that would empty the directory. (In this case,
	leave the last file alone to denote when the generating process stopped.)
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	in verbose, the [System.IO.FileInfo]'s to be deleted will be output
.EXAMPLE
	PurgeLogs.ps1 -path C:\foologs, C:\barlogs\*.xml -age [TimeSpan]"2.12:0"
	
	remove files older than 2.5 days from all in C:\foologs and all *.xml files in c:\barlogs
#>
