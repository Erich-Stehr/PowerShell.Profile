$ListsURL = "https://liveserver.team.partners.extranet.microsoft.com/Companies/_vti_bin/Lists.asmx"
$usr = "lcsweb"
$pwd = 'HKittyP*Ptart'
$udom = 'redmond'
$wc = new-object System.Net.WebClient
$wc.Credentials = new-object System.Net.NetworkCredential ($usr, $pwd, $udom)
$ListsWSDLs = $wc.DownloadString($ListsURL + '?WSDL') 
$ListsWsdl = [xml]$ListsWSDLs

if ($ListsWSDL.definitions.targetNamespace -ne "http://schemas.microsoft.com/sharepoint/soap/") { throw "Not a Sharepoint site!"; exit }

$SoapPlainEnvelope = [xml]'<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Header></SOAP-ENV:Header> <SOAP-ENV:Body></SOAP-ENV:Body></SOAP-ENV:Envelope>'

function SoapRequest([string] $url, [string] $namespace, [string] $method, [string] $bodyXml, [string] $usr, [string] $pwd)
{
	#write-host 'URL' $url
	#write-host 'Namespace' $namespace
	#write-host 'Method' $method
	$envelope = [xml]'<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><SOAP-ENV:Header></SOAP-ENV:Header> <SOAP-ENV:Body></SOAP-ENV:Body></SOAP-ENV:Envelope>'
	$wc = new-object System.Net.WebClient
	$wc.Credentials = new-object System.Net.NetworkCredential ($usr, $pwd, $udom)
	$wc.Headers.Add("SOAPAction", $namespace + $method)
	$wc.Headers.Add("Content-type", "text/xml")
	$bodyCmd = $envelope.Envelope.get_LastChild()
	#$bodyCmd.get_OuterXml()
	$bodyCmd.set_innerXML('<s0:' + $method + ' xmlns:s0="' + $namespace + '"></s0:' + $method + '>')
	if (($null -ne $bodyXml) -and ("" -ne $bodyXml)) {$bodyCmd.get_FirstChild().set_InnerXml($bodyXml)}
	#write-host $bodyCmd.get_OuterXml()
	$wc.UploadString($url, $envelope.get_OuterXml())
}

$ListsColls = SoapRequest ($ListsURL) 'http://schemas.microsoft.com/sharepoint/soap/' 'GetListCollection' '' $usr $pwd
$ListsColl = [xml]$ListsColls
#if ($null -eq $ListsColl) { write-host 'null' } else { $ListsColl | gm }

$Lists = $ListsColl.envelope.Body.GetListCollectionResponse.GetListCollectionResult.Lists.List
#$Lists | ft Name,Title
exit
