$ListsURL = "https://liveserver.team.partners.extranet.microsoft.com/Companies/_vti_bin/Lists.asmx"
$usr = "redmond\lcsweb"
$pwd = 'RTCpa$$word'
$objHTTP = new-object -com msxml2.xmlhttp
$objHTTP.Open("GET",$ListsURL + "?WSDL",$false, $usr, $pwd)
$objHTTP.Send()
# $objHTTP.ResponseText
$ListsWSDL = [xml]$objHTTP.ResponseText

if ($ListsWSDL.definitions.targetNamespace -ne "http://schemas.microsoft.com/sharepoint/soap/") { throw "Not a Sharepoint site!"; exit }

$SoapPlainEnvelope = [xml]'<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Header></SOAP-ENV:Header> <SOAP-ENV:Body></SOAP-ENV:Body></SOAP-ENV:Envelope>'

function SoapRequest([string] $url, [string] $namespace, [string] $method, [string] $bodyXml, [string] $usr, [string] $pwd)
{
	#write-host 'URL' $url
	#write-host 'Namespace' $namespace
	#write-host 'Method' $method
	$envelope = [xml]'<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Header></SOAP-ENV:Header> <SOAP-ENV:Body></SOAP-ENV:Body></SOAP-ENV:Envelope>'
	$objHTTP = new-object -com msxml2.xmlhttp
	$objHTTP.Open('POST', $url, $false, $usr, $pwd)
	$objHTTP.setRequestHeader("SOAPAction", $namespace + $method)
	$objHTTP.setRequestHeader("Content-type", "text/xml")
	$bodyCmd = $envelope.Envelope.get_LastChild()
	#$bodyCmd.get_OuterXml()
	$bodyCmd.set_innerXML('<s0:' + $method + ' xmlns:s0="' + $namespace + '"></s0:' + $method + '>')
	#write-host $bodyCmd.get_OuterXml()
	$objHTTP.Send($envelope.get_OuterXml())
	$objHTTP
}

$objHTTP = SoapRequest ($ListsURL) 'http://schemas.microsoft.com/sharepoint/soap/' 'GetListCollection' '' $usr $pwd
$ListsColl = [xml]$null
write-host ($objHTTP.get_status)
if (($objHTTP.Status -lt 300) -and ($objHTTP.Status -ge 200)) {$ListsColl = [xml]$objHTTP.ResponseText} else { $objHTTP.ResponseText}
if ($null -eq $ListsColl) { write-host 'null' } else { $ListsColl | gm }
exit

$GLCR = $SoapPlainEnvelope.Clone()
$objHTTP.Open('POST', $ListsURL, $false, $usr, $pwd)
$objHTTP.setRequestHeader("SOAPAction", "http://schemas.microsoft.com/sharepoint/soap/GetListCollection")
$objHTTP.setRequestHeader("Content-type", "text/xml")
$bodyCmd = $GLCR.Envelope.get_LastChild().set_innerXML("<s0:GetListCollection xmlns:s0='http://schemas.microsoft.com/sharepoint/soap/'></s0:GetListCollection>")
$GLCR.get_OuterXml()
$objHTTP.Send($GLCR.get_OuterXml())
# $objHTTP.ResponseText
if ($objHTTP.Status -lt 300) {$ListsColl = [xml]$objHTTP.ResponseText} else { $objHTTP.ResponseText; exit}
