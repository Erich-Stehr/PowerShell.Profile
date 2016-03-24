param (
	[string] 
	# path of output .csv (if not to output)
	$path=$null,
	[string] 
	# name of termset (default: implied from path filename)
	$termset=$(if ([string]::IsNullOrEmpty($path)) {trap {break;}; throw "Need termset if no path to imply name"} else {(split-path $path -leaf) -replace '\..*',''}),
	[object[]] 
	# Properties to convert into term path, in order
	$Property=$('Term1','Term2','Term3','Term4','Term5','Term6','Term7')
	)
begin {
	if (!$Property.Count -or ($Property.Count -lt 1) -or ($Property.Count -gt 7))
	{
		trap { break; }
		throw "Need at least one term and no more than 7 terms in Property to construct term hierarchy"
	}

	# clear target file and generate header
	'"Term Set Name","Term Set Description","LCID","Available for Tagging","Term Description","Level 1 Term","Level 2 Term","Level 3 Term","Level 4 Term","Level 5 Term","Level 6 Term","Level 7 Term"' |
		Set-Content -Path $path -Encoding UTF8
	# set termset name
	"""$termset"",""Term Set Description"",,,,,,,,,," |
		Add-Content -Path $path
	$rowtemplate = ",,,""True"",""Term Description"",{0},{1},{2},{3},{4},{5},{6}"
	
	$props = New-Object 'System.Collections.Generic.List[string]'
	$Property | %{ $props.Add($_.ToString()) }
	While ($props.Count -lt 7) { $props.Add($null) }
}
process {
	$item = $_
	if ($item -is [Object[]]) {
		$terms = (New-Object object[] 7)
		$item[0..6].CopyTo($terms, 0)
	} else {
		$terms = $props | % { if ($_) { $item."$_" } else { [String]::Empty } }
	}
	[String]::Format($rowtemplate, $terms) | Add-Content -Path $path
}

<#
.SYNOPSIS
	Use input stream's Property to generate ImportTermSet.csv
.DESCRIPTION
	Accepts stream of PSObjects or object[], pulls PSobject values based on 
	Property or Object[] out as hierarchy of Terms in the Termset and 
	generates ImportTermSet.csv for importing.
.INPUTS
	either PSObject with Property properties or object[]
.OUTPUTS
	no objects, UTF8 file in name $path
.EXAMPLE
	@{term1='foo';term2='bar';term3='quux'}, @{term1='fred';term2='barney';term3='xyzzy'} | GenerateImportTermSetCsv.ps1 foo.csv
	@('foo','bar','quux'), @('fred','barney','xyzzy') | GenerateImportTermSetCsv.ps1 foo.csv
	dir -rec | ? {$_.PSIsContainer}| %{ $ht=@{}; $terms=@($_.Fullname.Replace("$pwd\","").Split("\")); for ($i = 0; $i -lt $terms.count; ++$i) {$ht.Add("term$($i+1)", $terms[$i])}; $ht} | GenerateImportTermSetCsv.ps1 MarketingPortalTermset.csv
	#$groupinfo = dir -rec | ? {$_.PSIsContainer}| %{ $terms=@($_.Fullname.Replace("$pwd\","").Split("\")); @{TermCount=$terms.Count;Path=$_} | New-HashObject} | group-object TermCount
	#$groupinfo[7].Group | ... Path | ... FullName > ~\OvertermedPaths.txt
	#$groupinfo[8].Group | ... Path | ... FullName >> ~\OvertermedPaths.txt
#>
