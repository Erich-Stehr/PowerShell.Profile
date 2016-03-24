## http://poshcode.org/2536
<#
Get-OleDBPSObject ([string]$ConnectionString, [string]$Query)

No time for documentation right now, but I thought this was handy enough that I should share it right away...

This function will connect to any database that an OLEDB.Net connection string can be written for (http://www.connectionstrings.com/) and returns PSObjects with properties named and typed based on the columns returned. Perfect for pipelining.
#>
function Get-OleDBPSObject ([string]$ConnectionString, [string]$Query) {
	$ConnObj = new-object System.Data.OleDb.OleDbConnection $ConnectionString
	$command = New-Object System.Data.OleDb.OleDbCommand $Query, $ConnObj
	try {
		$ConnObj.Open()
		[System.Data.OleDB.OleDbDataReader]$reader = $command.ExecuteReader()
		while ($reader.Read()) {
			$obj = New-Object PSObject
			for ($i=0; $i -lt $reader.FieldCount; $i++) {
				$obj | Add-Member -type NoteProperty -name ($reader.GetName($i)) -value ($reader[$i])
			}
			$obj	
		}
	}
	catch { throw $_ }
	finally {
		$command = $null
		$reader.Close()
		$reader = $null
		$ConnObj.Close()
		$ConnObj = $null
	}
}