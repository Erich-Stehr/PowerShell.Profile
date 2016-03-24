$ListsURL = "https://liveserver.team.partners.extranet.microsoft.com/Companies/_vti_bin/Lists.asmx"
$PSCred = $host.UI.PromptForCredential('Connecting to extranet companies list',  '', 'redmond\lcsweb', $ListsURL) # includes prompt strings unlike Get-Credential
$NetCred = $PSCred.GetNetworkCredential()
#$ListsURL, $usr, $pwd, $udom = "http://pcs-erich:8080/_vti_bin/Lists.asmx", "estehr", $(Read-host 'Password' -AsSecureString), 'EDC'
$wc = new-object System.Net.WebClient
#if ('' -eq $pwd) { $wc.UseDefaultCredentials = $true } else { $wc.Credentials = new-object System.Net.NetworkCredential ($usr, $pwd, $udom) }
if ($null -eq $netCred) { $wc.UseDefaultCredentials = $true } else { $wc.Credentials = $netCred }
$ListsWSDLs = $wc.DownloadString($ListsURL + '?WSDL') 
$ListsWsdl = [xml]$ListsWSDLs

if ($ListsWSDL.definitions.targetNamespace -ne "http://schemas.microsoft.com/sharepoint/soap/") { throw "Not a Sharepoint site!"; exit }

$sharepointNamespace = 'http://schemas.microsoft.com/sharepoint/soap/'
$global:webExcept = $null
function SoapRequest([string] $url, [string] $namespace, [string] $method, [string] $bodyXml, [System.Net.NetworkCredential] $netCred=$null)
{
	trap [Exception] { $global:webExcept = $_ ; write-host $envelope.get_OuterXml() ; if (($null -ne $webExcept) -and ($null -ne $webExcept.Exception) -and ($null -ne $webExcept.Exception.Response)) { write-host ([System.Text.Encoding]::UTF8).GetString($webExcept.Exception.Response.GetResponseStream().ToArray())} }
	#write-host 'URL' $url
	#write-host 'Namespace' $namespace
	#write-host 'Method' $method
	$global:envelope = [xml]'<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" ><SOAP-ENV:Header></SOAP-ENV:Header><SOAP-ENV:Body></SOAP-ENV:Body></SOAP-ENV:Envelope>'
	$wc = new-object System.Net.WebClient
	if ($null -eq $netCred) { $wc.UseDefaultCredentials = $true } else { $wc.Credentials = $netCred }
	$wc.Headers.Add("SOAPAction", $namespace + $method)
	$wc.Headers.Add("Content-type", "text/xml")
	$wc.Headers.Add([Net.HttpRequestHeader]::KeepAlive, "1")
	$bodyCmd = $envelope.Envelope.get_LastChild()
	#$bodyCmd.get_OuterXml()
	$bodyCmd.set_innerXML('<' + $method + ' xmlns="' + $namespace + '"></' + $method + '>')
	if (($null -ne $bodyXml) -and ("" -ne $bodyXml)) {$bodyCmd.get_FirstChild().set_InnerXml($bodyXml)}
	#write-host $envelope.get_OuterXml()
	$wc.UploadString($url, $envelope.get_OuterXml())
	$wc.Dispose()
	$wc = $null
}

write-host 'GetListCollection'
$ListsColls = SoapRequest $ListsURL $sharepointNamespace 'GetListCollection' '' $NetCred
$ListsColl = [xml]$ListsColls
#if ($null -eq $ListsColl) { write-host 'null' } else { $ListsColl | gm }

$Lists = $ListsColl.envelope.Body.GetListCollectionResponse.GetListCollectionResult.Lists.List
#$Lists | ft Name,Title

# GetList to pick up list schema

write-host 'GetList'
#$ListSchemaResult = SoapRequest $ListsURL $sharepointNamespace 'GetList' '<listName>{A202EB52-88B5-44CA-A0D4-12B98C5FEDF5}</listName>' $usr $pwd $udom
$ListSchemaResult = SoapRequest $ListsURL $sharepointNamespace 'GetList' '<listName>Erich&apos;s Test List</listName>' $NetCred
$ListSchemaResx = [xml]$ListSchemaResult
$ListSchema = $ListSchemaResx.Envelope.Body.GetListResponse.GetListResult.List
if ($null -eq $ListSchema) { write-host "No schema from GetList" }


# tweak schema

if ($null -ne $ListSchema) {
	$ListSchema.Fields.Field | ? { $_.Name -eq 'Milestone' } | % { $fldMilestone = $_.Clone() }
	#$fldMilestone.get_OuterXml()

	if ($null -ne $fldMilestone) {
		# create base choice element
		$newChild = $fldMilestone.get_OwnerDocument().CreateElement("CHOICE", $sharepointNamespace);
		# strip existing choices; if empty, need to access as .Item() in order to get the element instead of the empty string
		while ($null -ne $fldMilestone.Item("CHOICES").get_FirstChild()) { [void]($fldMilestone.CHOICES.RemoveChild($fldMilestone.CHOICES.get_FirstChild())) }
		# for each new choice (unnamed, inline array) create a choice element and append it to the CHOICES element
		'IDX', 'Beta1', 'Beta2', 'Beta3', 'RC', 'RTM', 'LOC RTM', 'Post RTM' | % {
			$ch = $newChild.Clone()
			$ch.set_InnerText($_)
			$fldMilestone.Item("CHOICES").AppendChild($ch)
		} | out-null
		$fldMilestone.Default = 'Beta3'
		#$fldMilestone.get_OuterXml()
	}

	# UpdateList to change list schema 

	$modify = "<listName>" + $ListSchema.ID + "</listName>"
	#[System.Web.HttpUtility]::HtmlAttributeEncode
	$modify += 		"<listProperties Title=`"" + ($ListSchema.Title) + "`" Description=`"" + ($ListSchema.Description) + "`" />"
	$modify += 		"<updateFields><Fields xmlns=''><Method ID='1'>" + $fldMilestone.get_OuterXml() + "</Method></Fields></updateFields>"
	$modify += 		"<listVersion>" + $ListSchema.Version + "</listVersion>"
	write-host 'UpdateList'
	$newSchemaResult = SoapRequest $ListsURL $sharepointNamespace 'UpdateList' $modify $NetCred
	$newSchemaResx = [xml]$newSchemaResult
	#$newSchemaResult
}

# Get site data

$WebsURL = 'https://liveserver.team.partners.extranet.microsoft.com/Companies/_vti_bin/Webs.asmx'

$WebCollResult = SoapRequest $WebsURL $sharepointNamespace 'GetWebCollection' '' $NetCred
$WebCollResx = [xml]$WebCollResult
#$WebCollResult
$WebColl = $WebCollResx.Envelope.Body.GetWebCollectionResponse.GetWebCollectionResult.Webs.Web
$WebColl | ft -autosize -wrap

exit
