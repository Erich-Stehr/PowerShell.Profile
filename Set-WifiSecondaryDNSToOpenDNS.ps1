if (gcm Get-DnsClientServerAddress) {
	$wifi = Get-DnsClientServerAddress "Wireless Network Connection" | ? { $_.Address }
	if (!$wifi) { throw "No 'Wireless Network Connection'" }
	if ($wifi.Address[1] -and $wifi.Address[1] -ne '208.67.222.222') {
		$addresses = $wifi.Address.Clone()
		$addresses[1] = '208.67.222.222'
		Set-DnsClientServerAddress -InterfaceIndex ($wifi.InterfaceIndex) -ServerAddresses $addresses #-Validate
	} else {
	"OK"
	}
} else {
	# older method: 
	netsh interface ip set dns name="Wireless Network Connection" static 208.67.222.222 index=2
}