param ($datasource="(local)\COMPASS", $database="SummitDev", [switch]$verbose=$false)

$tables = Invoke-SqlCommandCe.ps1 -dataSource $datasource -database $database -sqlCommand "SELECT Table_Name FROM INFORMATION_SCHEMA.TABLES" | select -ExpandProperty Table_Name | sort
$counts = $tables | % { Invoke-SqlCommandCe.ps1 -dataSource $datasource -database $database -sqlCommand "SELECT 'Count'=COUNT(*),'Table'='$_' FROM dbo.$_" }

$tables | %{
	if ($verbose) { Write-Verbose $_ }
	bcp "$database.dbo.$_" format nul -S $datasource -T -E -w -x -f "$_.format.xml"
	bcp "$database.dbo.$_" out "$_.dat" -S $datasource -T -E -f "$_.format.xml" 
}
# assuming all the tables are set up, import with #  dir *.dat | % { $_.BaseName } | % { $_; bcp "$database.dbo.$_" in "$_.dat" -S "$datadestination" -T -E -f "$_.format.xml" }