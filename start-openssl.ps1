[CmdletBinding()]
$openSslDir="${env:ProgramFiles}\OpenSSL-Win64"
if (!(test-path $openSslDir)) {
    $openSslDir="${env:ProgramFiles}\OpenSSL"
}
if (!(test-path $openSslDir)) {
    throw "Couldn't find OpenSSL directory!"
}

$env:PATH="${env:PATH};${openSslDir}\bin"
$env:OPENSSL_CONF="${env:ProgramFiles}\Common Files\SSL\openssl.cnf"
Write-Verbose "OPENSSL_CONF=${env:OPENSSL_CONF}"
$env:OPENSSL_ENGINES="${openSslDir}"
Write-Verbose "OPENSSL_ENGINES=${env:OPENSSL_ENGINES}"
$env:OPENSSL_MODULES="${openSslDir}\bin"
Write-Verbose "OPENSSL_MODULES=${env:OPENSSL_MODULES}"
openssl version -a
