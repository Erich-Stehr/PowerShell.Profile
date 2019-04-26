# https://gist.github.com/camieleggermont/5b2971a96e80a658863106b21c479988
# additional DnsNames added, reminders
$cert = New-SelfSignedCertificate -DnsName "localhost", "localhost", $env:COMPUTERNAME, "${env:COMPUTERNAME}.${env:USERDNSDOMAIN}" -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -HashAlgorithm SHA256 -KeyLength 2048 -CertStoreLocation "cert:\LocalMachine\My" -NotAfter (Get-Date).AddYears(5)
$thumb = $cert.GetCertHashString()

Write-Warning "Deleting the 100 IISExpress certificate bindings"
For ($i=44300; $i -le 44399; $i++) {
    netsh http delete sslcert ipport=0.0.0.0:$i
}

Write-Warning "Recreating the 100 IISExpress certificate bindings"
For ($i=44300; $i -le 44399; $i++) {
    netsh http add sslcert ipport=0.0.0.0:$i certhash=$thumb appid=`{214124cd-d05b-4309-9af9-9caa44b2b74a`}
}

$StoreScope = 'LocalMachine'
$StoreName = 'root'

$Store = New-Object  -TypeName System.Security.Cryptography.X509Certificates.X509Store  -ArgumentList $StoreName, $StoreScope
$Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$Store.Add($cert)

$Store.Close()