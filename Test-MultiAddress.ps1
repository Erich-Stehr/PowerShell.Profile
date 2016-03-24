[CmdletBinding(ConfirmImpact='Medium',SupportsShouldProcess=$true)]
#[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
param (
	[string] 
	# start IP address
	$startAddressString=$("131.107.181.101"),
	[int]
	# number of addresses to check
	$addressCount=$(150),
	[string] 
	# URL for IP query
	$queryUrl=$("https://www.google.com/search?q=my+ip&amp;gws_rd=ssl"),
	[switch]
	$force=$false
	)
Begin {
	trap { break; } # old-style stop on error
	#[void][System.Reflection.Assembly]::LoadWithPartialName("HttpAgilityPack")
	$startAddress = [Net.IPAddress]::Parse($startAddressString)
	$CookieContainer = New-Object System.Net.CookieContainer

	function GetWebResourceViaRequest([string]$url) {
		trap { $result=$res.StatusCode; $res.Close(); $result }
		# modified from http://stackoverflow.com/questions/5470474/powershell-httpwebrequest-get-method-cookiecontainer-problem
		$CookieContainer = New-Object System.Net.CookieContainer # to clean between addresses
		[net.httpWebRequest] $req = [net.webRequest]::create($url)
		$req.method = "GET"
		$req.Accept = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
		$req.Headers.Add("Accept-Language: en-US")
		$req.Headers.Add("Accept-Encoding: gzip,deflate")
		$req.Headers.Add("Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7")
		# IE 10 UserAgent seems to invoke gzip compression!
		#$req.UserAgent = "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)"
		$req.AllowAutoRedirect = $false
		$req.TimeOut = 50000
		$req.KeepAlive = $true
		$req.Headers.Add("Keep-Alive: 300");
		$req.CookieContainer = $CookieContainer
		[net.httpWebResponse] $res = $req.getResponse()
	    if ($res.StatusCode -lt [System.Net.HttpStatusCode]::OK -or $res.StatusCode -ge [System.Net.HttpStatusCode]::Ambiguous) {
			throw $res.StatusCode
		}
		$resst = $res.getResponseStream()
		$sr = new-object IO.StreamReader($resst)
		$result = $sr.ReadToEnd()
		$res.close()
		return $result 

		#$web = new-object net.webclient
		#$web.Headers.add("Cookie", $res.Headers["Set-Cookie"])
		#$result = $web.DownloadString("https://secure_url")
	}

	function OpenBrowserWindow() {
		$browser = new-object -com "InternetExplorer.Application"
		$browser.Navigate($queryUrl)
		$browser.Visible = $true
		Write-Host "Close browser window to continue scan...."
		while ($browser.ReadyState) { sleep 5 }
		$browser = $null
	}
}
Process {
	$adapters = @(gwmi Win32_NetworkAdapterConfiguration | ? { (($_.IPEnabled) -and (!$_.DHCPEnabled)) })
	if ($adapters.Count -eq 0) {
		return "No DTAP available adapters"
	}

	# build address/subnet string arrays
	$ips = New-Object "System.Collections.Generic.List``1[System.String]" ($addressCount)
	$masks = New-Object "System.Collections.Generic.List``1[System.String]" ($addressCount)
	if ($startAddressString -match "(\d{1,3}\.\d{1,3}\.\d{1,3}\.)(\d{1,3})") {
		$networkString = $Matches[1]
		$subAddress = [int]$Matches[2]
		0..($addressCount-1) | %{
			$ips.Add($networkString + ($subAddress + $_))
			$masks.Add("255.255.255.0")
		}
		#$adapters[0].EnableStatic($ips.ToArray(), $masks.ToArray())
	} else {
		return "Check address format"
	}
	
	0..($addressCount-1) | %{
		$adapters[0].EnableStatic([string[]]@($ips[$_]), [string[]]@($masks[$_]))
		$result = GetWebResourceViaRequest $queryUrl
		if ($result -is [Net.HttpStatusCode]) {
			write-output "$($ips[$_]): $result"
			if ($result -ne [Net.HttpStatusCode]::ServiceUnavailable -and 
				$result -ne [Net.HttpStatusCode]::Forbidden -and 
				$result -ne [Net.HttpStatusCode]::NotFound) {
				write-output "$($ips[$_]): Opening browser window"
				OpenBrowserWindow
			}
		} else {
			# search doesn't have IP address in the initial output, 'myip' is in most top hits
			if ($result -match 'myip') {
				write-output "$($ips[$_]): OK"
			} else {
				write-output "$($ips[$_]): Opening browser window"
				OpenBrowserWindow
			}
		}
	}

}
End {
}

<#
.SYNOPSIS
	Over the given IP address range, loop trying to get the IP address through 
	<google.com/query?q=my+ip>, popping up the browser for the CAPTCHA'ed 
	addresses that return the important error codes 503, 403, 404
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.PowerShell
.EXAMPLE
	PS> Test-MultiAddress.ps1
#>
