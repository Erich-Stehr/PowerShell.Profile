params ([string]$Path)
{
	# assumption: in (split-path -parent path) exists the "EncryptedPassword" file
	$directory = (Split-Path -Parent $Path)
	$password = & {
		$decryptedBytes = $null
		[void][System.Reflection.Assembly]::LoadWithPartialName("System.Security")
		try {
			$encryptedBytes = [IO.File]::ReadAllBytes([IO.Path]::Combine((ScriptRoot), "EncryptedPassword"))
			$decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedBytes, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
			$result = (New-Object System.Security.SecureString)
			#$sb = New-Object System.Text.StringBuilder # to use certutil, we'll need the unencrypted password
			$rdr = New-Object System.IO.StreamReader @((New-Object System.IO.MemoryStream (,$decryptedBytes)),
			 (New-Object System.Text.UnicodeEncoding @($false, $true, $true)))
			while (($ch = $rdr.Read()) -gt 0) {
				$result.AppendChar($ch)
				#[void]$sb.Append([char]$ch)
			}

			return $result#, $sb.ToString()
		} finally {
			$ex = $_
			if ($decryptedBytes -ne $null) { 0..($decryptedBytes.Count-1) | % {$decryptedBytes[$_] = 0} }
			if ($null -ne $ex) {throw $ex}
		}
	}
}