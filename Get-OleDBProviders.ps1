$script:oledbenum = @([System.Data.OleDb.OleDbEnumerator]::GetEnumerator([Type]::GetTypeFromProgID("MSDAENUM")));

try {
	$oledbenum |
		%{ 
		$script:reader = $_
		$obj = new-object PSObject
		for ($i = 0; $i -lt $reader.FieldCount; ++$i) {
			$obj | Add-Member -type NoteProperty -name ($reader.GetName($i)) -value ($reader[$i])
		}
		$obj
	}
} finally {
	$reader = $null
	$oledbenum = $null
}

<#
.SYNOPSIS
	Extracts OLE DB providers from system registry
.DESCRIPTION
	modified from Get-OleDBPSObject <http://poshcode.org/2536>
.INPUTS
	None
.OUTPUTS
	PSObjects generated from [System.Data.OleDb.OleDbEnumerator]::GetEnumerator handed MSDAENUM
#>
