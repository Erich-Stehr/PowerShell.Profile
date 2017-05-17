param (
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
	[string[]] 
	# Path to file to replace within
	$path,
	[System.Collections.Hashtable]
	# key,value = exact match, replacement
	$exact=@{},
	[System.Collections.Hashtable]
	# key,value = regular expression to match, replacement
	$regex=@{},
	[switch]
	$passThru=$false,
	[switch]
	$WhatIf=$WhatIfPreference,
	[switch]
	$Confirm=$false,
	[switch]
	$force=$false
	)
Begin {
	$script:cdir = [Environment]::CurrentDirectory
	[Environment]::CurrentDirectory = $PWD

	$PIPELINEINPUT = (-not $PSBOUNDPARAMETERS.ContainsKey("path")) #https://social.technet.microsoft.com/Forums/scriptcenter/en-US/f07fd26a-ec59-44a4-8143-dea182ffae70/powershell-mandatory-parameters-lose-pipeline-input?forum=ITCG

	function DoIt($thisOne) {
		$operating = $true
		try {
			$res = @(Get-Content -Path $thisOne | %{
				$line = $_
				$exact.GetEnumerator() | %{ $line = $line -replace $_.Key,$_.Value}
				$regex.GetEnumerator() | %{ $line = ([Regex]($_.Key)).Replace($line,$_.Value)}
				$line
			})
		} catch {
            $operating = $false
			throw;
		}
		if ($operating) {
			$res | % { Write-Debug $_ }
		    Set-Content -Path $thisOne -Value $res -Force:$force -Confirm:$Confirm -PassThru:$passThru -WhatIf:$WhatIf
		}
	}

}
Process {
    if ($PIPELINEINPUT -and ($_ -ne $null)) {
        $path = $_
    }
    $path | %{
        DoIt $_
    }
}
End {
    [Environment]::CurrentDirectory = $script:cdir
}

<#
.SYNOPSIS
	Replaces text content in source files
.DESCRIPTION
	For each line in each source file, replace the keys of $exact with the
	appropriate value using the -replace operator, then replace the keys of 
	$regexp with that appropriate value using [Regex]::Replace. Write the 
	file back out over itself unless -whatif specified.

	Remember that regex's are case-sensitive without the inline option '(?i)'!
.INPUTS
	FileInfo
.OUTPUTS
	string[] status messages
.EXAMPLE
	PS> "1","2","1 1" | out-file testfile.txt
	PS> Update-StringContents -path testfile.txt -exact @{'1'='foo';'2'='bar'}
	PS> gc testfile.txt
	foo
	bar
	foo foo
.EXAMPLE
	PS> "bar","bear","bar bell" | out-file testfile.txt
	PS> Update-StringContents -path testfile.txt -regex @{'b.*?r'='1';'b.*?l'='2';'(?is)x.*l'='x'}
	PS> gc testfile.txt
	1
	1
	1 2l
	PS> # last line could be just '2l' due to non-ordering of HashTables
#>
