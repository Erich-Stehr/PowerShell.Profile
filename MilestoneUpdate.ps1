# Set up locations and authentication credentials
$ListsURL = "https://liveserver.team.partners.extranet.microsoft.com/Companies/_vti_bin/Lists.asmx"
$PSCred = $host.UI.PromptForCredential('Connecting to extranet companies list',  '', 'redmond\lcsweb', $ListsURL) # includes prompt strings unlike Get-Credential
$NetCred = $PSCred.GetNetworkCredential()

$sharepointNamespace = 'http://schemas.microsoft.com/sharepoint/soap/'
$global:webExcept = $null

function SoapRequest([string] $url, [string] $namespace, [string] $method, [string] $bodyXml, [System.Net.NetworkCredential] $netCred=$null)
{
	trap [Exception] { $global:webExcept = $_ ; write-host $envelope.get_OuterXml() ; if (($null -ne $webExcept) -and ($null -ne $webExcept.Exception) -and ($null -ne $webExcept.Exception.Response)) { write-host ([System.Text.Encoding]::UTF8).GetString($webExcept.Exception.Response.GetResponseStream().ToArray())} }
	$global:envelope = [xml]'<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" ><SOAP-ENV:Header></SOAP-ENV:Header><SOAP-ENV:Body></SOAP-ENV:Body></SOAP-ENV:Envelope>'
	$wc = new-object System.Net.WebClient
	if ($null -eq $netCred) { $wc.UseDefaultCredentials = $true } else { $wc.Credentials = $netCred }
	$wc.Headers.Add("SOAPAction", $namespace + $method)
	$wc.Headers.Add("Content-type", "text/xml")
	$wc.Headers.Add([Net.HttpRequestHeader]::KeepAlive, "1")
	$bodyCmd = $envelope.Envelope.get_LastChild()
	$bodyCmd.set_innerXML('<' + $method + ' xmlns="' + $namespace + '"></' + $method + '>')
	if (($null -ne $bodyXml) -and ("" -ne $bodyXml)) {$bodyCmd.get_FirstChild().set_InnerXml($bodyXml)}
	write-debug $envelope.get_OuterXml()
	$wc.UploadString($url, $envelope.get_OuterXml())
	$wc.Dispose()
}

function ResetChoiceList([string] $url, [string] $listName, [string] $columnName, [string[]] $arrNewItems, [int] $offDefaultItem=0, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	$ListSchemaResult = SoapRequest $url $sharepointNamespace 'GetList' "<listName>$listName</listName>" $NetCred
	$ListSchemaResx = [xml]$ListSchemaResult
	$ListSchema = $ListSchemaResx.Envelope.Body.GetListResponse.GetListResult.List
	if ($null -eq $ListSchema) { write-error "No schema from GetList" ; exit}
	write-debug "ResetChoiceList ListSchema = $($ListSchema.get_OuterXml())"
	
	
	# tweak schema

	if ($null -ne $ListSchema) {
		$ListSchema.Fields.Field | ? { $_.Name -eq $columnName } | % { $fldColumn = $_.Clone() }
		if ($null -eq $fldColumn) { write-error "No Column $columnName found on $listName" ; exit }
		write-debug $fldColumn.get_OuterXml()

		if ($null -ne $fldColumn) {
			# create base choice element
			$newChild = $fldColumn.get_OwnerDocument().CreateElement("CHOICE", $sharepointNamespace);
			# strip existing choices; if empty, need to access as .Item() in order to get the element instead of the empty content string
			while ($null -ne $fldColumn.Item("CHOICES").get_FirstChild()) { [void]($fldColumn.CHOICES.RemoveChild($fldColumn.CHOICES.get_FirstChild())) }
			# for each new choice (unnamed, inline array) create a choice element and append it to the CHOICES element
			$arrNewItems | % {
				$ch = $newChild.Clone()
				$ch.set_InnerText($_)
				$fldColumn.Item("CHOICES").AppendChild($ch)
			} | out-null
			$fldColumn.Default = $arrNewItems[$offDefaultItem]
			write-debug $fldColumn.get_OuterXml()
		}

		# UpdateList to change list schema 

		$modify = "<listName>" + $ListSchema.ID + "</listName>"
		#[System.Web.HttpUtility]::HtmlAttributeEncode
		$modify += 		"<listProperties Title=`"" + ($ListSchema.Title) + "`" Description=`"" + ($ListSchema.Description) + "`" />"
		$modify += 		"<updateFields><Fields xmlns=''><Method ID='1'>" + $fldColumn.get_OuterXml() + "</Method></Fields></updateFields>"
		$modify += 		"<listVersion>" + $ListSchema.Version + "</listVersion>"
		write-verbose 'UpdateList'
		$newSchemaResult = SoapRequest $url $sharepointNamespace 'UpdateList' $modify $NetCred
		$newSchemaResx = [xml]$newSchemaResult
		write-debug $newSchemaResult
	}
}
#ResetChoiceList "http://pcs-erich:8080" 'Erich&apos;s Test List' 'Milestone' 'IDX','Beta1','Beta2','Beta3','RC','RTM','LOC RTM','Post RTM' 3

# Get site data

function SitesFrom([string] $url, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Webs.asmx')) {$url += '/_vti_bin/Webs.asmx' }
	$WebCollResult = SoapRequest $url $sharepointNamespace 'GetWebCollection' '' $NetCred
	$WebCollResx = [xml]$WebCollResult
	write-debug "SitesFrom WebCollResult = $WebCollResult"
	$WebCollResx.Envelope.Body.GetWebCollectionResponse.GetWebCollectionResult.Webs.Web
}
#SitesFrom 'https://liveserver.team.partners.extranet.microsoft.com/Companies' $NetCred | ft -autosize -wrap

$MilestoneList = 'Beta3','Beta3 Refresh','IDX','Loc RTM','Post RTM','RC','RTM','SP1','SP2'
SitesFrom 'https://voicetaprdp.team.partners.extranet.microsoft.com/Companies' $NetCred |
	? { $_.URL -notmatch '/veritest' } |
	% { write-host $_.Title
		ResetChoiceList ($_.URL) 'Provide Product FeedBack' 'Milestone' $MilestoneList 0 $NetCred
	}
