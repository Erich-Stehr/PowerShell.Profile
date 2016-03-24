# Set up locations and authentication credentials
$ListsURL = "https://liveserver.team.partners.extranet.microsoft.com/Companies/_vti_bin/Lists.asmx"
$account = "$env:USERDOMAIN\$env:USERNAME" #'redmond\a-erste' #'echodev\erich' # 'redmond\IWAMail' # 'redmond\lcsweb'
$PSCred = $host.UI.PromptForCredential('NetCred credentials',  '', $account, $ListsURL) # includes prompt strings unlike Get-Credential
$global:NetCred = $PSCred.GetNetworkCredential()
if (($NetCred.Domain -eq $env:USERDOMAIN) -and ($NetCred.UserName -eq $env:USERNAME)) { $global:localCred = $NetCred } else { $global:localcred = (get-credential "$env:USERDOMAIN\$env:USERNAME").GetNetworkCredential() }

$global:sharepointNamespace = 'http://schemas.microsoft.com/sharepoint/soap/'
$global:webExcept = $null



function global:StopHalt()
{
	#$MyInvocation | fl ; $MyInvocation.MyCommand | fl 
	#if ($MyInvocation.ScriptName.Length) {exit} else {write-error 'Stopping' -ea Stop}
	write-error 'Stopping' -ea Stop
}

$script:sharePointSoapAsFba = $false
function global:Set-SharePointSoapAsFba([bool]$value)
# do we force Windows Authentication on FBA sites or not
{
	$script:sharePointSoapAsFba = $value
}

function global:SoapRequest([string] $url, [string] $namespace, [string] $method, [string] $bodyXml, [System.Net.NetworkCredential] $netCred=$null)
{
	trap [Exception] { $global:webExcept = $_ ; write-host $envelope.get_OuterXml() ; if (($null -ne $webExcept) -and ($null -ne $webExcept.Exception) -and ($null -ne $webExcept.Exception.Response)) { write-host ([System.Text.Encoding]::UTF8).GetString($webExcept.Exception.Response.GetResponseStream().ToArray())} ; break }
	$global:envelope = [xml]'<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" ><SOAP-ENV:Header></SOAP-ENV:Header><SOAP-ENV:Body></SOAP-ENV:Body></SOAP-ENV:Envelope>'
	$wc = new-object System.Net.WebClient
	$wc.Proxy = new-object System.Net.WebProxy
	if ($null -eq $netCred) { $wc.UseDefaultCredentials = $true } else { $wc.Credentials = $netCred }
	$wc.Headers.Add("SOAPAction", $namespace + $(if ($namespace.EndsWith("/")) {""} else {"/"}) + $method)
	$wc.Headers.Add("Content-type", "text/xml")
	$wc.Headers.Add([Net.HttpRequestHeader]::KeepAlive, "1")
	if ($script:sharePointSoapAsFba) { $wc.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f") }
	$bodyCmd = $envelope.Envelope.get_LastChild()
	$bodyCmd.set_innerXML('<' + $method + ' xmlns="' + $namespace + '"></' + $method + '>')
	if (($null -ne $bodyXml) -and ("" -ne $bodyXml)) {$bodyCmd.get_FirstChild().set_InnerXml($bodyXml)}
	write-debug $envelope.get_OuterXml()
	$wc.UploadString($url, $envelope.get_OuterXml())
	$wc.Dispose()
}
# $perms = SoapRequest "https://liveserver.team.partners.extranet.microsoft.com/companies/testing/_vti_bin/Permissions.asmx" ($sharepointNamespace+'directory/') 'GetPermissionCollection' "<objectName>View Bugs</objectName><objectType>List</objectType>" $NetCred ; $perms
# $perms = SoapRequest "https://liveserver.team.partners.extranet.microsoft.com/companies/Bell%20Canada/_vti_bin/Permissions.asmx" ($sharepointNamespace+'directory/') 'GetPermissionCollection' "<objectName>View Bugs</objectName><objectType>List</objectType>" $NetCred ; $perms
# SoapRequest "https://liveserver.team.partners.extranet.microsoft.com/companies/testing/_vti_bin/Permissions.asmx" ($sharepointNamespace+'directory/') 'UpdatePermission' "<objectName>View Bugs</objectName><objectType>List</objectType><permissionIdentifier>Contributor</permissionIdentifier><permissionType>role</permissionType><permissionMask>134283789</permissionMask>" $NetCred
# SoapRequest "https://voicetaprdp.team.partners.extranet.microsoft.com/_vti_bin/Lists.asmx" $sharepointNamespace 'GetListAndView' "<listName>Release</listName>" $NetCred | tidy-xml
# SoapRequest "http://pcs-erich:8080/_vti_bin/Lists.asmx" $sharepointNamespace 'UpdateListItems' "<listName>Erich&apos;s Test List</listName><updates><Batch><Method ID='1' Cmd='Delete'><Field Name='ID'>2</Field><Field Name='Title'>Breaking change</Field></Method></Batch></updates>" | tidy-xml
# SoapRequest "https://lcs-tap.team.partners.extranet.microsoft.com/_vti_bin/Lists.asmx" $sharepointNamespace 'GetListItems' "<listName>Release</listName><query><Query><Where><Eq><FieldRef Name='Title'/><Value Type='string'>Voicetaprdp</Value></Eq></Where></Query></query><viewFields><ViewFields><FieldRef Name='ID'/></ViewFields></viewFields><QueryOptions><IncludeMandatoryColumns>FALSE</IncludeMandatoryColumns><DateInUtc>TRUE</DateInUtc></QueryOptions>" $NetCred
# $env = [xml](SoapRequest 'https://voicetaprdp.team.partners.extranet.microsoft.com/companies/Template/_vti_bin/Lists.asmx' $sharepointnamespace 'GetListItems' '<listName>Announcements</listName><query><Query><Where><Neq><FieldRef Name="Title"/><Value Type="Text"></Value></Neq></Where><OrderBy><FieldRef Name="ID" Ascending="TRUE" /></OrderBy></Query></query><viewFields><ViewFields><FieldRef Name="Title"/><FieldRef Name="Body"/><FieldRef Name="Expires"/></ViewFields></viewFields><queryOptions><QueryOptions/></queryOptions>' $NetCred); $rows = $env.Envelope.Body.GetListItemsResponse.GetListItemsResult.listitems.data.row ; $rows | ft
# SoapRequest "https://voicetaprdp.team.partners.extranet.microsoft.com/_vti_bin/Lists.asmx" $sharepointNamespace 'GetListItems' "<listName>UserInfo</listName><query><Query><Where><IsNotNull><FieldRef Name='ID'/></IsNotNull></Where><OrderBy><FieldRef Name='ID' /></OrderBy></Query></query><viewFields><ViewFields><FieldRef Name='ID'/><FieldRef Name='Name'/><FieldRef Name='Title'/><FieldRef Name='Email'/></ViewFields></viewFields><queryOptions><QueryOptions/></queryOptions>" $NetCred | tidy-xml
# SoapRequest "http://pcs-erich:8080/_vti_bin/Lists.asmx" $sharepointNamespace 'GetListItems' "<listName>Erich's Test List</listName><query><Query><OrderBy><FieldRef Name='ID' Ascending='FALSE'/></OrderBy></Query></query>" | tidy-xml
# SoapRequest "http://pcs-erich:8080/_vti_bin/Lists.asmx" $sharepointNamespace 'GetListItems' "<listName>Erich's Test List</listName><query><Query><Where><BeginsWith><FieldRef Name='Title'/><Value Type='Text'>T</Value></BeginsWith></Where></Query></query>" | tidy-xml
# SoapRequest "http://pcs-erich:8080/_vti_bin/SiteData.asmx" $sharepointNamespace 'GetSite' "" | tidy-xml
# $webInfo = [xml](SoapRequest "http://voicetaprdp.team.partners.extranet.microsoft.com/_vti_bin/SiteData.asmx" $sharepointNamespace 'GetWeb' "" $NetCred) ; $webInfo.Envelope.Body.GetWebResponse.sWebMetadata.WebId
# SoapRequest "http://livecommteam/sites/main/TAP/Voice/_vti_bin/Lists.asmx" $sharepointNamespace 'GetListItems' "<listName>Voice Database</listName><viewName>815D6BA9-297D-4A12-BE9F-6633BA4553F5</viewName>" | tidy-xml
# SoapRequest "https://lcs-tap.team.partners.extranet.microsoft.com/_vti_bin/Lists.asmx" $sharepointNamespace 'GetListItems' "<listName>Program Launch</listName><query><Query><Where><Eq><FieldRef Name='Release'/><Value Type='string'>Voicetaprdp</Value></Eq></Where></Query></query><viewFields><ViewFields><FieldRef Name='ID'/><FieldRef Name='Title'/><FieldRef Name='Release'/><FieldRef Name='Program'/><FieldRef Name='Status'/><FieldRef Name='ReleaseProgram'/></ViewFields></viewFields><QueryOptions><IncludeMandatoryColumns>FALSE</IncludeMandatoryColumns><DateInUtc>TRUE</DateInUtc></QueryOptions>" $NetCred
# SoapRequest "http://r2-wss3/_vti_bin/SiteData.asmx" $sharepointNamespace 'GetWeb' "" $NetCred | tidy-xml
# SoapRequest "http://r2-wss3/_vti_bin/SiteData.asmx" $sharepointNamespace 'EnumerateFolder' "<strFolderUrl>/</strFolderUrl>" $NetCred | tidy-xml
# SoapRequest "http://r2-wss3/_vti_bin/WebPartPages.asmx" 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPartProperties2' "<pageUrl>default.aspx</pageUrl><storage>Shared</storage><behavior>Version3</behavior>" $NetCred | tidy-xml
# SoapRequest "http://r2-wss3/_vti_bin/WebPartPages.asmx" 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPartPage' "<documentName>default.aspx</documentName><behavior>Version3</behavior>" $NetCred | tidy-xml
# $parts = [xml](SoapRequest "http://r2-wss3/_vti_bin/WebPartPages.asmx" 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPartProperties' "<pageUrl>/default.aspx</pageUrl><storage>Shared</storage>" $NetCred); $parts.Envelope.Body.GetWebPartPropertiesResponse.GetWebPartPropertiesResult.WebParts.WebPart.count
# SoapRequest "http://r2-wss3/_vti_bin/Webs.asmx" $sharepointNamespace 'GetCustomizedPageStatus' "<fileUrl>default.aspx</fileUrl>" $NetCred | tidy-xml
# SoapRequest "http://r2-wss3/_vti_bin/Webs.asmx" $sharepointNamespace 'GetActivatedFeatures' "" $NetCred | tidy-xml
# SoapRequest "http://r2-wss3/_vti_bin/Webs.asmx" $sharepointNamespace 'GetWebCollection' "" $NetCred | tidy-xml
# $parts2 = [xml](SoapRequest "http://msw/AboutMicrosoft/Archives/ResearchTools/ImageViewer/_vti_bin/WebPartPages.asmx" 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPartProperties2' "<pageUrl>/AboutMicrosoft/Archives/ResearchTools/ImageViewer/Pages/SearchTest.aspx</pageUrl><storage>Shared</storage>" $NetCred); @($parts2.Envelope.Body.GetWebPartPropertiesResponse.GetWebPartPropertiesResult.WebParts.WebPart).count
# $wp2 = [xml](SoapRequest "http://msw/AboutMicrosoft/Archives/ResearchTools/ImageViewer/_vti_bin/WebPartPages.asmx" 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPart2' "<pageurl>Pages/SearchTest.aspx</pageurl><storageKey>{d83afffd-00e0-4060-8fc1-df04a23a96a7}</storageKey><storage>Shared</storage><behavior>Version3</behavior>" $NetCred)

function global:GetListSchema([string] $url, [string] $listName, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	$ListSchemaResult = SoapRequest $url $sharepointNamespace 'GetList' "<listName>$listName</listName>" $NetCred
	$ListSchemaResx = [xml]$ListSchemaResult
	$ListSchema = $ListSchemaResx.Envelope.Body.GetListResponse.GetListResult.List
	if ($null -eq $ListSchema) { write-error "No schema from GetList" ; stophalt}
	write-debug "ResetChoiceList ListSchema = $($ListSchema.get_OuterXml())"
	$ListSchema
}
# $listSchema = GetListSchema "http://pcs-erich:8080" 'Erich&apos;s Test List' ; $listSchema
# $listSchema = GetListSchema "http://projectportal/Projects/" 'Project Portfolio' ; $listSchema
# $listSchemaLS = GetListSchema "https://liveserver.team.partners.extranet.microsoft.com/_vti_bin/Lists.asmx" 'Program Master' $NetCred ; $listSchemaLS
# $listSchemaV = GetListSchema "https://voicetaprdp.team.partners.extranet.microsoft.com/_vti_bin/Lists.asmx" 'Program Master' $NetCred  ; $listSchemaV.Fields.Field | ft



function global:ResetChoiceList([string] $url, [string] $listName, [string] $columnName, [string[]] $arrNewItems, [int] $offDefaultItem=0, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	$ListSchema = GetListSchema $url $listName $netCred
	
	# tweak schema

	if ($null -ne $ListSchema) {
		$ListSchema.Fields.Field | ? { $_.Name -eq $columnName } | % { $fldColumn = $_.Clone() }
		if ($null -eq $fldColumn) { write-error "No Column $columnName found on $listName" ; stophalt }
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
			if ($offDefaultItem -lt $arrNewItems.Length) { $fldColumn.Default = $arrNewItems[$offDefaultItem] }
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
# ResetChoiceList "http://pcs-erich:8080" 'Erich&apos;s Test List' 'Milestone' 'IDX','Beta1','Beta2','Beta3','Beta3 Refresh','RC','RTM','LOC RTM','Post RTM' 4
# SitesFrom 'https://liveserver.team.partners.extranet.microsoft.com/Companies' $NetCred | % { ResetChoiceList ($_.URL) 'Provide Product Feedback' 'Milestone' 'IDX','Beta1','Beta2','Beta3','Beta3 Refresh','RC','RTM','LOC RTM','Post RTM' 4 $NetCred }
# SitesFrom 'https://rtcwave12pep.team.partners.extranet.microsoft.com/Companies' $NetCred | % { ResetChoiceList $_.Url 'Provide Product Feedback' 'Issue_x0020_type' 'Bug/Code Bug','Bug/Design Bug','Bug/External','Bug/Geopolitical','Bug/Localization','Bug/Partner Bug','Bug/Spec Bug','Bug/Test Bug','DCR','Work Item/Dev','Work Item/PM','Work Item/Spec','Work Item/Test','Work Item/Tracking','Documentation' 0 $NetCred }
# SitesFrom 'https://rtcwave12pep.team.partners.extranet.microsoft.com/Companies' $NetCred | % { ResetChoiceList $_.Url 'Provide Product Feedback' 'Feature_x0020_area' (new-object string[] 0) 0 $NetCred }

# Get site data

function global:SitesFrom([string] $url, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Webs.asmx')) {$url += '/_vti_bin/Webs.asmx' }
	$WebCollResult = SoapRequest $url $sharepointNamespace 'GetWebCollection' '' $NetCred
	$WebCollResx = [xml]$WebCollResult
	write-debug "SitesFrom WebCollResult = $WebCollResult"
	$WebCollResx.Envelope.Body.GetWebCollectionResponse.GetWebCollectionResult.Webs.Web
}
#SitesFrom 'https://liveserver.team.partners.extranet.microsoft.com/Companies' $NetCred | ft -autosize -wrap



# TransferListSchema - create a destListName list at destUrl, taking the description, template ID, and schema from the srcListName at srcUrl

# BUGBUG: replace global: once functioning
function TransferListSchema( [string] $srcUrl, [string] $srcListName, [string] $destUrl, [string] $destListName, [System.Net.NetworkCredential] $srcNetCred=$null, [System.Net.NetworkCredential] $destNetCred=$srcNetCred)
{
	if (!$srcUrl.EndsWith('/_vti_bin/Lists.asmx')) {$srcUrl += '/_vti_bin/Lists.asmx' }
	if (!$destUrl.EndsWith('/_vti_bin/Lists.asmx')) {$destUrl += '/_vti_bin/Lists.asmx' }
	
	$ListSchemaElem = GetListSchema $srcUrl $srcListName $srcNetCred
	
	# create allowable listProperties per WSS2 SDK docs for UpdateList

	$listProperties = [xml]'<List></List>'
	"AllowMultiResponses", "Description", "Direction", "EnableAssignedToEmail", "EnableAttachments", "EnableModeration", "EnableVersioning", "Hidden", "MultipleDataList", "Ordered", "ShowUser" |
	% { if ($listSchemaElem.HasAttribute($_)) { $listProperties.item('List').SetAttribute($_, $listSchemaElem.GetAttribute($_)) } }

	# create newFields 	
	
	$camlDestList = [xml](SoapRequest $destUrl $sharepointNamespace 'AddList' "<listName>$destListName</listName><description>$($ListSchemaElem.Description)</description><templateID>$($ListSchemaElem.ServerTemplate)</templateID>" $destNetCred)
	# $camlDestList	; bp
	$camlDestListView = [xml](SoapRequest $destUrl $sharepointNamespace 'GetListAndView' "<listName>$destListName</listName>" $NetCred)

	$fields = [xml]'<Fields></Fields>'
	$method = 1

	# for each field in the source list schema, if that field is not in the (unmodified) destination list schema, wrap it in a Method element and appendChild to $fields
	$destNames = ( $camlDestList.Envelope.Body.AddListResponse.AddListResult.List.Fields.Field | % { $_.Name } )
	$listSchemaElem.Fields.Field | ? { -not ($destnames -contains $_.Name) } |  % { $elemMethod = $fields.item("Fields").AppendChild($fields.CreateElement("Method")); $elemMethod.SetAttribute("ID",$method++) ; $elemMethod.SetAttribute("AddToView",$camlDestListView.Envelope.Body.GetListAndViewResponse.GetListAndViewResult.ListAndView.View.Name); $elemMethod.set_InnerXml($_.get_OuterXml()) ; $elemMethod.get_FirstChild().SetAttribute("DisplayName",[Xml.XmlConvert]::DecodeName($elemMethod.get_FirstChild().GetAttribute("Name"))) } 

	# for each field in the original destination list schema, pick up the changes applied to the source list
	$updatefields = [xml]'<Fields></Fields>'
	$listSchemaElem.Fields.Field | ? { ($destnames -contains $_.Name) } |  % { $elemMethod = $updatefields.item("Fields").AppendChild($updatefields.CreateElement("Method")); $elemMethod.SetAttribute("ID",$method++) ; $elemMethod.set_InnerXml($_.get_OuterXml()) } 
	
	# update list
	
	SoapRequest $destUrl $sharepointNamespace 'UpdateList' "<listName>$destListName</listName><listProperties>$($listProperties.get_OuterXml())</listProperties><newFields>$($fields.get_OuterXml())</newFields><updateFields>$($updatefields.get_OuterXml())</updateFields>" $destNetCred
	
	# re-update list to match DisplayNames where the decoded .Name doesn't match the DisplayName
	
	$renamedfields = [xml]'<Fields></Fields>'
	$method = 1
	$listSchemaElem.Fields.Field | % { $elemMethod = $renamedfields.item("Fields").AppendChild($renamedfields.CreateElement("Method")); $elemMethod.SetAttribute("ID",$method++) ; $elemMethod.set_InnerXml($_.get_OuterXml()) }
	if ($renamedfields.Fields.get_type -ne [string]) { SoapRequest $destUrl $sharepointNamespace 'UpdateList' "<listName>$destListName</listName><updateFields>$($renamedfields.get_OuterXml())</updateFields>" $destNetCred }
	
}
# TransferListSchema 'https://lcs-tap.team.partners.extranet.microsoft.com' 'Release' 'https://Voicetaprdp.team.partners.extranet.microsoft.com/' 'Release' $NetCred
# TransferListSchema 'https://liveserver.team.partners.extranet.microsoft.com' 'Program Master' 'https://Voicetaprdp.team.partners.extranet.microsoft.com/' 'Program Master 3' $NetCred
# TransferListSchema 'https://liveserver.team.partners.extranet.microsoft.com' 'Program Launch' 'https://Voicetaprdp.team.partners.extranet.microsoft.com/' 'Program Launch 3' $NetCred


# BUGBUG: replace global: once functioning
function TransferListData( [string] $srcUrl, [string] $srcListName, [string] $rawQuery, [string] $destUrl, [string] $destListName, [System.Net.NetworkCredential] $srcNetCred=$null, [System.Net.NetworkCredential] $destNetCred=$srcNetCred)
# Note: doesn't copy over User fields; would need to look up in UserInfo list (which doesn't respond to the CAML <Query> element)
{
	if (!$srcUrl.EndsWith('/_vti_bin/Lists.asmx')) {$srcUrl += '/_vti_bin/Lists.asmx' }
	if (!$destUrl.EndsWith('/_vti_bin/Lists.asmx')) {$destUrl += '/_vti_bin/Lists.asmx' }

	# collect default viewed names and schema definitions, we want the actual source fields not the calculated fields	
	$camlDestListView = [xml](SoapRequest $destUrl $sharepointNamespace 'GetListAndView' "<listName>$destListName</listName>" $destNetCred)
	$listNames = @{}; $camlDestListView.Envelope.Body.GetListAndViewResponse.GetListAndViewResult.ListAndView.List.Fields.Field | % { $listNames[$_.Name] = $_ }
	$viewNames = ($camlDestListView.Envelope.Body.GetListAndViewResponse.GetListAndViewResult.ListAndView.View.ViewFields.FieldRef | % { $_.Name } | % { if ($listnames[$_].DisplayNameSrcField) { $listnames[$_].DisplayNameSrcField } else {$_} })
	
	# grab rows
	$sRs = [xml](SoapRequest $srcUrl $sharepointNamespace 'GetListItems' "<listName>$srcListName</listName>$rawQuery" $srcNetCred)
#bp 'TransferListData/GetListItems'
		
	# insert data from 'matching' field names (ows_Fieldname to Fieldname) into destination items
	$updates = [xml]"<Batch></Batch>"
	$method = 1
	$sRs.Envelope.Body.GetListItemsResponse.GetListItemsResult.listitems.data.row | # select-object -first 1 |
	% {
		$row = $_
		$elemMethod = $updates.item("Batch").AppendChild($updates.CreateElement("Method")); $elemMethod.SetAttribute("ID",$method++) ; $elemMethod.SetAttribute("Cmd","New"); $elemMethod.set_InnerXml("<Field Name='ID'>New</Field>") #"<Field Name='ID'>$( if ($row.ows_ID) { $row.ows_ID } else {'New'})</Field>"
		$viewNames | % { $n = $_; $r = ($row.$('ows_'+$_)) ; if ($r) {$fld = $elemMethod.AppendChild($updates.CreateElement("Field")); $fld.SetAttribute("Name", $n); $fld.set_InnerText(($r -replace "^(\w+|\d+)?;#",""))} ; write-debug "$n $r" }
	}
	write-debug (($updates.get_OuterXml())+"`r`r")
	
	# execute matched batch
	$res = SoapRequest $destUrl $sharepointNamespace 'UpdateListItems' "<listName>$destlistName</listName><updates>$($updates.get_OuterXml())</updates>" $destNetCred
	$res
#bp '$res'
}
# TransferListData 'https://lcs-tap.team.partners.extranet.microsoft.com' 'Release' '<query><Query><Where><Contains><FieldRef Name="Title"/><Value Type="Text">Voicetaprdp</Value></Contains></Where></Query></query><queryOptions xmlns:SOAPSDK9="http://schemas.microsoft.com/sharepoint/soap/"><QueryOptions/></queryOptions>' 'https://Voicetaprdp.team.partners.extranet.microsoft.com/' 'Release' $NetCred
# TransferListData 'https://liveserver.team.partners.extranet.microsoft.com' 'Program Master' '<query><Query><Where><Neq><FieldRef Name="Title"/><Value Type="Text"></Value></Neq></Where></Query></query><queryOptions><QueryOptions/></queryOptions>' 'https://Voicetaprdp.team.partners.extranet.microsoft.com/' 'Program Master 3' $NetCred
# TransferListData 'https://liveserver.team.partners.extranet.microsoft.com' 'Program Launch' '<query><Query><Where><Eq><FieldRef Name="Release"/><Value Type="Text">Voicetaprdp</Value></Eq></Where><OrderBy><FieldRef Name="ID" Ascending="TRUE" /></OrderBy></Query></query><viewFields><ViewFields><FieldRef Name="Title"/><FieldRef Name="Release"/><FieldRef Name="Program"/><FieldRef Name="Program_x0020Manager"/><FieldRef Name="Launch_x0020Date"/><FieldRef Name="End_x0020Date"/><FieldRef Name="Status"/><FieldRef Name="PS_x0020Alias"/><FieldRef Name="Release"/><FieldRef Name="Program"/><FieldRef Name="ListsToExport"/><FieldRef Name="FormsToExport"/></ViewFields></viewFields><queryOptions><QueryOptions/></queryOptions>' 'https://Voicetaprdp.team.partners.extranet.microsoft.com/' 'Program Launch 3' $NetCred
# TransferListData 'https://voicetaprdp.team.partners.extranet.microsoft.com/companies/Template' 'Announcements' '<query><Query><Where><Neq><FieldRef Name="Title"/><Value Type="Text"></Value></Neq></Where><OrderBy><FieldRef Name="ID" Ascending="FALSE" /></OrderBy></Query></query><viewFields><ViewFields><FieldRef Name="Title"/><FieldRef Name="Body"/><FieldRef Name="Expires"/></ViewFields></viewFields><queryOptions><QueryOptions/></queryOptions>' 'http://pcs-erich:8080/' 'Announcements' $NetCred $null
# TransferListData 'https://lcs-tap.team.partners.extranet.microsoft.com' 'Program Launch' "<query><Query><Where><Eq><FieldRef Name='Release'/><Value Type='string'>Voicetaprdp</Value></Eq></Where></Query></query><viewFields><ViewFields><FieldRef Name='ID'/><FieldRef Name='Title'/><FieldRef Name='Release'/><FieldRef Name='Program'/><FieldRef Name='Status'/><FieldRef Name='ReleaseProgram'/></ViewFields></viewFields><QueryOptions><IncludeMandatoryColumns>FALSE</IncludeMandatoryColumns><DateInUtc>TRUE</DateInUtc></QueryOptions>" 'https://voicetaprdp.team.partners.extranet.microsoft.com/' 'Program Launch' $NetCred


function global:GetFieldIDs([string] $url, [string] $listName, [string] $field, [string] $fieldName="Title", [System.Net.NetworkCredential] $netCred=$null)
#returns XML rows of result or $null, ows_ID are matching values
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	$result = SoapRequest $url $sharepointNamespace 'GetListItems' "<listName>$listName</listName><query><Query><Where><Eq><FieldRef Name='$fieldName'/><Value Type='string'>$field</Value></Eq></Where><OrderBy><FieldRef Name='ID' Ascending='TRUE' /></OrderBy></Query></query><viewFields><ViewFields><FieldRef Name='ID'/></ViewFields></viewFields><queryOptions><QueryOptions><IncludeMandatoryColumns>FALSE</IncludeMandatoryColumns><DateInUtc>TRUE</DateInUtc></QueryOptions></queryOptions>" $NetCred
	$resx = [xml]$result
	$answer = $resx.Envelope.Body.GetListItemsResponse.GetListItemsResult.listitems.data.row
	write-debug "GetFieldIDs Answer= $(if ($answer) {$answer} else {'<null>'})"
	$answer
}
# $IDs = GetFieldIDs "http://pcs-erich:8080" 'Erich&apos;s Test List' 'Breaking change' 'Title'; $IDs
# $IDs = GetFieldIDs "https://liveserver.team.partners.extranet.microsoft.com/companies/Allstream" 'Announcements' 'Configuring Weekly Usage Reports' 'Title' $NetCred ; $IDs
# $IDs = GetFieldIDs "https://voicetaprdp.team.partners.extranet.microsoft.com/companies/Accenture" 'Links' 'https://voicerdptap.microsoft.com' 'URL' $NetCred ; $IDs



function global:ZapLatestItemByField([string] $url, [string] $listName, [string] $field, [string] $fieldName="Title", [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	
	$IDs = GetFieldIDs $url $listName $field $fieldName $netCred
	if ($IDs)
	{	
		$id = $(if ($IDs[-1]) { $IDs[-1] } else { $IDs }) # get last if collection, this if not
		$zapRes = SoapRequest $url $sharepointNamespace 'UpdateListItems' "<listName>$listName</listName><updates><Batch><Method ID='1' Cmd='Delete'><Field Name='ID'>$($id.ows_ID)</Field><Field Name='$fieldName'>$field</Field></Method></Batch></updates>" $NetCred
		$err = ([xml]$zapRes).Envelope.Body.UpdateListItemsResponse.UpdateListItemsResult.Results.Result
		if (0+$err.ErrorCode) { write-error "Failed $url with error $($err.ErrorCode) $(err.ErrorText)" } else { $id.ows_ID }
	}
	else
	{
		write-error "No '$field' in '$listName' at '$url'"
	}
}
# ZapLatestItemByField "http://pcs-erich:8080" 'Erich&apos;s Test List' 'Breaking change'
# SitesFrom "https://liveserver.team.partners.extranet.microsoft.com/companies" $NetCred | % { ZapLatestItemByField ($_.Url) 'Announcements' 'Configuring Weekly Usage Reports' 'Title' $NetCred }
# ZapLatestItemByField "https://voicetaprdp.team.partners.extranet.microsoft.com/companies/Accenture" 'Links' 'https://voicerdptap.microsoft.com' 'URL' $NetCred
# SitesFrom "https://voicetaprdp.team.partners.extranet.microsoft.com/companies" $NetCred | % { ZapLatestItemByField ($_.Url) 'My Downloads' 'Devices' 'Link_x0020_Title' $NetCred }

function global:ResetFieldDefault([string] $url, [string] $listName, [string] $columnName, [string] $default="", [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	$ListSchema = GetListSchema $url $listName $netCred
	
	# tweak schema

	if ($null -ne $ListSchema) {
		$ListSchema.Fields.Field | ? { $_.Name -eq $columnName } | % { $fldColumn = $_.Clone() }
		if ($null -eq $fldColumn) { write-error "No Column $columnName found on $listName" ; stophalt }
		write-debug $fldColumn.get_OuterXml()

		if ($null -ne $fldColumn) {
			# create base choice element
			if ($null -eq $fldColumn.Item("Default")) 
			{
				$fldColumn.AppendChild($fldColumn.get_OwnerDocument().CreateElement("Default", $sharepointNamespace))
			}
			$fldColumn.Default = $default

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
# ResetFieldDefault "https://rtcwave12pep.team.partners.extranet.microsoft.com/companies/ACCOR/" 'Provide Product Feedback' 'How_x0020_found' 'Beta' $NetCred
# SitesFrom "https://rtcwave12pep.team.partners.extranet.microsoft.com/companies" $NetCred | % { ResetFieldDefault $_.Url 'Provide Product Feedback' 'How_x0020_found' 'Beta' $NetCred }

function global:ResetFieldRequired([string] $url, [string] $listName, [string] $columnName, [bool] $req=$false, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	$ListSchema = GetListSchema $url $listName $netCred
	
	# tweak schema

	if ($null -ne $ListSchema) {
		$ListSchema.Fields.Field | ? { $_.Name -eq $columnName } | % { $fldColumn = $_.Clone() }
		if ($null -eq $fldColumn) { write-error "No Column $columnName found on $listName" ; stophalt }
		write-debug $fldColumn.get_OuterXml()

		if ($null -ne $fldColumn) {
			$fldColumn.Required = $req.ToString()

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
# ResetFieldRequired "https://rtcwave12pep.team.partners.extranet.microsoft.com/companies/CitigroupAPAC" 'Provide Product Feedback' 'Feature_x0020_area' $false $NetCred
# SitesFrom "https://rtcwave12pep.team.partners.extranet.microsoft.com/companies" $NetCred | % { ResetFieldRequired $_.Url 'Provide Product Feedback' 'Feature_x0020_area' $false $NetCred }

# SoapRequest 'http://a-bryhu-tablet:33674/_vti_bin/Webs.asmx' $sharepointNamespace 'GetWebCollection' '' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet:33674/_vti_bin/Webs.asmx' $sharepointNamespace 'GetActivatedFeatures' '' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet:33674/_vti_bin/SiteData.asmx' $sharepointNamespace 'GetWeb' '' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet:33674/_vti_bin/Webs.asmx' $sharepointNamespace 'GetWeb' '<webUrl>.</webUrl>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet:33674/_vti_bin/SiteData.asmx' $sharepointNamespace 'EnumerateFolder' '<strFolderUrl>/</strFolderUrl>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet:33674/_vti_bin/SiteData.asmx' $sharepointNamespace 'GetList' '<strListName>{44F7D260-D2CB-43D6-8DF1-3E47D4B877C6}</strListName>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet:43192/_vti_bin/Lists.asmx' $sharepointNamespace 'GetListItems' '<listName>{44F7D260-D2CB-43D6-8DF1-3E47D4B877C6}</listName><viewFields><ViewFields><FieldRef Name="ID"/></ViewFields></viewFields><rowLimit>4294967295</rowLimit>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet:33674/_vti_bin/Views.asmx' $sharepointNamespace 'GetViewCollection' '<listName>{44F7D260-D2CB-43D6-8DF1-3E47D4B877C6}</listName>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet:33674/_vti_bin/SiteData.asmx' $sharepointNamespace 'EnumerateFolder' '<strFolderUrl>/Lists/Administrator Tasks</strFolderUrl>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet:33674/_vti_bin/Webs.asmx' $sharepointNamespace 'GetCustomizedPageStatus' '<fileUrl>/Lists/Administrator Tasks/AllItems.aspx</fileUrl>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet:33674/_vti_bin/WebPartPages.asmx' 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPartProperties' '<pageUrl>/Lists/Administrator Tasks/AllItems.aspx</pageUrl><storage>Shared</storage>' | tidy-xml

# SoapRequest 'http://a-bryhu-tablet0/_vti_bin/Webs.asmx' $sharepointNamespace 'GetWebCollection' '' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet0/Reports/_vti_bin/SiteData.asmx' $sharepointNamespace 'GetWeb' '' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet0/Docs/_vti_bin/SiteData.asmx' $sharepointNamespace 'GetList' '<strListName>{3C23163D-2103-43FF-B8B5-8B92FFD045D5}</strListName>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet0/Docs/_vti_bin/SiteData.asmx' $sharepointNamespace 'EnumerateFolder' '<strFolderUrl>Documents</strFolderUrl>' | tidy-xml

# SoapRequest 'http://a-bryhu-tablet/_vti_bin/SiteData.asmx' $sharepointNamespace 'GetWeb' '' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/SiteData.asmx' $sharepointNamespace 'GetList' '<strListName>{518DBF72-7466-4949-A921-7185919B9903}</strListName>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/SiteData.asmx' $sharepointNamespace 'EnumerateFolder' '<strFolderUrl>/Content and Structure Reports  </strFolderUrl>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/SiteData.asmx' $sharepointNamespace 'EnumerateFolder' '<strFolderUrl>/Reports List</strFolderUrl>' | tidy-xml
# $listSchema = GetListSchema 'http://a-bryhu-tablet' 'Content and Structure Reports' ; $listSchema

# SoapRequest 'http://a-bryhu-tablet0/_vti_bin/SiteData.asmx' $sharepointNamespace 'EnumerateFolder' '<strFolderUrl>/SiteDirectory/Tabs</strFolderUrl>' | tidy-xml

# $listSchema = GetListSchema 'http://a-bryhu-tablet0/' '{9623AB63-7CE8-42DA-A3C4-AD8B01A967F6}' ; $listSchema.Fields.Field | ft

## http://a-bryhu-tablet/PublishingImages/Forms/AllItems.aspx
# $listSchema = GetListSchema 'http://a-bryhu-tablet/' '{8EEBF930-8E92-4FB4-9ED7-D8B265D6720E}' ; $listSchema.Fields.Field | ft
# ********  Note: SiteData GetListItems returns v1 XML string of encoded XML, not XML proper!
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/SiteData.asmx' $sharepointNamespace 'GetListItems' '<strListName>{8EEBF930-8E92-4FB4-9ED7-8B265D6720E}</strListName><uRowLimit>100000</uRowLimit>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/SiteDirectory/_vti_bin/SiteData.asmx' $sharepointNamespace 'EnumerateFolder' '<strFolderUrl>/SiteDirectory/Tabs</strFolderUrl>' | tidy-xml
#

# SoapRequest 'http://a-bryhu-tablet/_vti_bin/Lists.asmx' $sharepointNamespace 'GetListItems' '<listName>Documents</listName><viewFields><ViewFields><FieldRef Name="ID"/><FieldRef Name="DirName" /><FieldRef Name="LeafName" /><FieldRef Name="Size" /><FieldRef Name="Type" /></ViewFields></viewFields><rowLimit>4294967295</rowLimit>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/Lists.asmx' $sharepointNamespace 'GetListItems' '<listName>Images</listName><viewFields><ViewFields><FieldRef Name="ID"/><FieldRef Name="DirName" /><FieldRef Name="LeafName" /><FieldRef Name="Size" /><FieldRef Name="Type" /></ViewFields></viewFields><rowLimit>4294967295</rowLimit>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/Lists.asmx' $sharepointNamespace 'GetListItems' '<listName>Style Library</listName><viewFields><ViewFields><FieldRef Name="ID"/><FieldRef Name="DirName" /><FieldRef Name="LeafName" /><FieldRef Name="Size" /><FieldRef Name="Type" /></ViewFields></viewFields><rowLimit>4294967295</rowLimit>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/SiteData.asmx' $sharepointNamespace 'EnumerateFolder' '<strFolderUrl>_catalogs</strFolderUrl>' | tidy-xml

# SoapRequest 'http://a-bryhu-tablet/_vti_bin/Lists.asmx' $sharepointNamespace 'GetListItems' '<listName>Style Library</listName><viewName></viewName><Query><Where><Eq><FieldRef Name="Type"/><Value>0</Value></Eq></Where><OrderBy><FieldRef Name="Id" Ascending="TRUE"></FieldRef></OrderBy></Query><ViewFields><FieldRef Name="Id" /><FieldRef Name="DirName" /><FieldRef Name="LeafName" /><FieldRef Name="Size" /><FieldRef Name="Type" /></ViewFields><QueryOptions><ViewAttributes Scope="Recursive" /></QueryOptions><rowLimit>4294967295</rowLimit>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/SiteData.asmx' $sharepointNamespace 'GetWeb' '' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/Docs/_vti_bin/SiteData.asmx' $sharepointNamespace 'GetSiteAndWeb' '<strUrl>http://a-bryhu-tablet/Docs</strUrl>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/Docs/_vti_bin/Webs.asmx' $sharepointNamespace 'GetAllSubWebCollection' '<!-- -->' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/Docs/_vti_bin/Sites.asmx' $sharepointNamespace 'GetSiteTemplates' '<LCID>1033</LCID>' | tidy-xml
# $sdgli = [xml](SoapRequest 'http://a-bryhu-tablet/_vti_bin/SiteData.asmx' $sharepointNamespace 'GetListItems' '<strListName>{0574f8ee-e6d6-4101-9f7f-ac5b576e4fd9}</strListName><uRowLimit>100000</uRowLimit>'); $listItems = [xml]$sdgli.Envelope.Body.GetListItemsResponse.GetListItemsResult; $$listItems.xml.data.row[0].ows_FileSizeDisplay
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/Lists.asmx' $sharepointNamespace 'GetListItems' '<listName>Style Library</listName><viewName></viewName><Query><Where><Eq><FieldRef Name="Type"/><Value>0</Value></Eq></Where><OrderBy><FieldRef Name="Id" Ascending="TRUE"></FieldRef></OrderBy></Query><ViewFields><FieldRef Name="Id" /><FieldRef Name="DirName" /><FieldRef Name="LeafName" /><FieldRef Name="File Size" /><FieldRef Name="Type" /></ViewFields><QueryOptions><ViewAttributes Scope="Recursive" /></QueryOptions><rowLimit>4294967295</rowLimit>' | tidy-xml
# $listSchema = GetListSchema 'http://a-bryhu-tablet/' '{0574f8ee-e6d6-4101-9f7f-ac5b576e4fd9}' ; $listSchema.Fields.Field | ft
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/Lists.asmx' $sharepointNamespace 'GetListItems' '<listName>Style Library</listName><viewFields><ViewFields><FieldRef Name="ID" /><FieldRef Name="FileSizeDisplay" /></ViewFields></viewFields><rowLimit>4294967295</rowLimit>' | tidy-xml
# SoapRequest 'http://a-bryhu-tablet/_vti_bin/Lists.asmx' $sharepointNamespace 'GetListItems' '<listName>Style Library</listName><viewFields><ViewFields><FieldRef Name="ID" /><FieldRef Name="FileSizeDisplay" /></ViewFields></viewFields><rowLimit>4294967295</rowLimit><queryOptions><QueryOptions><ViewAttributes Scope="Recursive" /></QueryOptions></queryOptions>' | tidy-xml

# SoapRequest "http://a-bryhu-tablet/_vti_bin/WebPartPages.asmx" 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPartProperties' "<pageUrl>/Pages/default.aspx</pageUrl><storage>Shared</storage>" | tidy-xml
# SoapRequest "http://a-bryhu-tablet/_vti_bin/WebPartPages.asmx" 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPartProperties2' "<pageUrl>/Pages/default.aspx</pageUrl><storage>Shared</storage>" | tidy-xml




function global:GetAllSubWebCollection([string] $url, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Webs.asmx')) {$url += '/_vti_bin/Webs.asmx' }
	$result = SoapRequest $url $sharepointNamespace 'GetAllSubWebCollection' '' $NetCred
	$resx = [xml]$result
	$answer = $resx.Envelope.Body.GetAllSubWebCollectionResponse.GetAllSubWebCollectionResult.Webs.Web
	write-debug "GetAllSubWebCollection Answer= $(if ($answer) {$answer} else {'<null>'})"
	$answer

}
# GetAllSubWebCollection 'http://rx200s3013:15518/e360' # returns all webs in the same site collection


function global:EnumerateFolder([string] $url, [string] $strFolderUrl, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/SiteData.asmx')) {$url += '/_vti_bin/SiteData.asmx' }
	$result = SoapRequest $url $sharepointNamespace 'EnumerateFolder' "<strFolderUrl>$strFolderUrl</strFolderUrl>" $NetCred
	write-debug "EnumerateFolder call result= $(if ($result) {$result} else {'<null>'})"
	$resx = [xml]$result
	$answer = $resx.Envelope.Body.EnumerateFolderResponse.vUrls._sFPUrl
	write-debug "EnumerateFolder Answer= $(if ($answer) {$answer} else {'<null>'})"
	$answer

}
# EnumerateFolder 'http://moss.go-planet.com' '/' $NetCred

function global:GetThisSubWebCollection([string] $url, [System.Net.NetworkCredential] $netCred=$null)
{
	$svcUrl = $url
	if (!$url.EndsWith('/_vti_bin/Webs.asmx')) {$svcUrl = $url + '/_vti_bin/Webs.asmx' }
	$result = SoapRequest $svcUrl $sharepointNamespace 'GetAllSubWebCollection' '' $NetCred
	$resx = [xml]$result
	$answer = ($resx.Envelope.Body.GetAllSubWebCollectionResponse.GetAllSubWebCollectionResult.Webs.Web | ? { $_.Url.StartsWith($url, [System.StringComparison]::OrdinalIgnoreCase) })
	write-debug "GetThisSubWebCollection Answer= $(if ($answer) {$answer} else {'<null>'})"
	$answer

}
# GetThisSubWebCollection 'http://rx200s3013:15518/e360' $NetCred # returns all webs under the given site

function global:GetListCollection([string] $url, [string] $titleMatch=$null, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	$result = SoapRequest $url $sharepointNamespace 'GetListCollection' '' $NetCred
	$resx = [xml]$result
	$answer = $resx.Envelope.Body.GetListCollectionResponse.GetListCollectionResult.Lists.List
	write-debug "GetListCollection Answer= $(if ($answer) {$answer} else {'<null>'})"
	$answer | ? { $_.Title -match $titleMatch } # $null or [string]::Empty always match
}
# GetListCollection 'http://moss.go-planet.com' $NetCred # returns all lists in that site
# GetListCollection 'http://erichstehr/sites/development/ffcdatabase' 'Emp' | select ID,Title # all lists with $_.Title -match 'Emp'

function global:GetListItemsBySiteData([string] $url, [string] $listGuid, [System.Net.NetworkCredential] $netCred=$null)
{
	#write-debug "GetListItemsBySiteData url = $url; listGuid = $listGuid"
	if ([String]::IsNullOrEmpty($listGuid)) { return $null }
	if (!$url.EndsWith('/_vti_bin/SiteData.asmx')) {$url += '/_vti_bin/SiteData.asmx' }
	$result = SoapRequest $url $sharepointNamespace 'GetListItems' "<strListName>$listGuid</strListName><uRowLimit>2147483647</uRowLimit>" $NetCred
	$resx = [xml]$result
	$answer = $resx.Envelope.Body.GetListItemsResponse.GetListItemsResult
	#write-debug "GetListItemsBySiteData Answer= $(if ($answer) {$answer} else {'<null>'})"
	([xml]($answer)).xml
}
# GetListItemsBySiteData 'http://moss.go-planet.com' '{455577D8-C8AE-4FEB-ADA2-7CB5536F2563}' $NetCred # returns .Schema and all .data.row in Announcements

function global:GetListItemsByLists([string] $url, [string] $listGuid='', [string] $viewName='', [string] $camlQuery=$null, [string] $viewFields='', [string] $queryOptions='', [string] $webID='', [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	
	$query = ''
	if ($null -ne $listGuid) { $query += "<listName>$listGuid</listName>" }
	if ($null -ne $viewName) { $query += "<viewName>$viewName</viewName>" }
	if ('' -ne $camlQuery) { 
		if (!$camlQuery.StartsWith("<Query")) { $camlQuery = "<Query>$camlQuery</Query>" }
		$query += "<query>$camlQuery</query>"
	}
	if ('' -ne $viewFields) { $query += "<viewFields>$viewFields</viewFields>" }
	$query += "<rowLimit>2147483647</rowLimit>"
	if ('' -ne $queryOptions) { $query += "<queryOptions><QueryOptions>$queryOptions</QueryOptions></queryOptions>" }
	if ('' -ne $webID) { $query += "<webID>$webID</webID>" }
	
	$result = SoapRequest $url $sharepointNamespace 'GetListItems' $query  $NetCred
	
	write-debug "GetListItemsByLists Result= $(if ($result) {$result} else {'<null>'})"
	$resx = [xml]$result
	$resx.Envelope.Body.GetListItemsResponse.GetListItemsResult.listitems.data.row

}
# GetListItemsByLists 'http://moss.go-planet.com' 'UserInfo' -netcred $NetCred # top-level list items, including folders
# GetListItemsByLists 'http://moss.go-planet.com' 'Documents' -netcred $NetCred # top-level list items, including folders
# GetListItemsByLists 'http://moss.go-planet.com' 'Documents' -queryOptions '<ViewAttributes Scope="Recursive" />' -netcred $NetCred # all list items in all folders, not including folders
# remember: <Neq>, <Leq>, <Geq> ; <Includes>. <NotIncludes>
# remember: //FieldRef/@LookupId='TRUE' #2012/04/05
# GetListItemsByLists http://erichstehr/sites/alphatesting/marketing "View Documents" -camlQuery "<Query><Where><Gt><FieldRef Name=""Created"" /><Value Type=""DateTime""><Today OffsetDays=""-30"" /></Value></Gt></Where></Query>"
# GetListItemsByLists http://erichstehr/sites/alphatesting/marketing "View Documents" -camlQuery "<Query><Where><In><FieldRef Name=""Brands""    LookupId=""True""    /><Values><Value Type=""Lookup"">3</Value></Values></In></Where></Query>"
# GetListItemsByLists http://erichstehr/sites/alphatesting/marketing "View Documents" -camlQuery "<Query><Where><In><FieldRef Name=""Brands""    LookupId=""True""    /><Values><Value Type=""Integer"">3</Value></Values></In></Where></Query>" # if indexed in 2010
# GetListItemsByLists http://groupvelocity.mackie.com/news "Posts" -camlQuery "<Query><Where><Eq><FieldRef Name=""ID""/><Value Type=""Integer"">29</Value></Eq></Where></Query>" -viewName $null -viewFields "<ViewFields><FieldRef Name=""ID""/><FieldRef Name=""Title""/><FieldRef Name=""ArticleThumbnail""/><FieldRef Name=""Body""/></ViewFields>"
# GetListItemsByLists http://groupvelocity.mackie.com/news "Posts" -camlQuery "<Query><Where><Eq><FieldRef Name=""ID""/><Value Type=""Integer"">29</Value></Eq></Where></Query>" -viewName $null -viewFields "<ViewFields></ViewFields>" #pull all fields
# GetListItemsByLists http://groupvelocity.mackie.com/news "Posts" -camlQuery "<Query><Where><Eq><FieldRef Name=""ID""/><Value Type=""Integer"">29</Value></Eq></Where></Query>" -viewName $null -viewFields "<ViewFields><FieldRef Name=""ID""/><FieldRef Name=""Title""/><FieldRef Name=""ArticleThumbnail""/><FieldRef Name=""Body""/></ViewFields>" -queryOptions "<IncludeMandatoryColumns>FALSE</IncludeMandatoryColumns><DateInUtc>TRUE</DateInUtc>" #only PublishedDate vanishes from IMC


function global:Copy-SiteLists([string] $srcUrl, [string] $destUrl, [System.Net.NetworkCredential] $srcNetCred=$null, [System.Net.NetworkCredential] $destNetCred=$srcNetCred)
{
	function HashListsByTitle($url, $cred)
	{
		# Make a hash of the lists in the site keyed on Title, no hidden or doclibs to be used
		$h = @{}
		GetListCollection $url $cred | ? { ($_.Hidden -eq $False) -and ($_.BaseType -eq 0) } | % { $h.Add($_.Title, $_) }
		,$h
	}
	$destLists = HashListsByTitle $destUrl $destNetCred
	
	GetListCollection $srcUrl $srcNetCred | %{
		if (!$destLists.Contains($_.Title))
		{
			TransferListSchema $srcUrl $_.Title $destUrl $_.Title $srcNetCred $destNetCred
		}
		TransferListData $srcUrl $_.Title '' $destUrl $_.Title $srcNetCred $destNetCred
	}
}
# Copy-SiteLists http://moss.go-planet.com "http://${env:computername}:8080" $NetCred $null
# Copy-SiteLists http://dl385g1026 http://rx200s3013 $NetCred


function global:GetActivatedFeatures([string] $url, [System.Net.NetworkCredential] $netCred=$null)
# NOTE: must be run on server to collect names of features
{
	if (!$url.EndsWith('/_vti_bin/Webs.asmx')) {$url += '/_vti_bin/Webs.asmx' }
	$result = SoapRequest $url $sharepointNamespace 'GetActivatedFeatures' '' $NetCred
	$resx = [xml]$result
	$answer = $resx.Envelope.Body.GetActivatedFeaturesResponse.GetActivatedFeaturesResult
	write-debug "GetListCollection Answer= $(if ($answer) {$answer} else {'<null>'})"
	
	$collectionFeatures, $siteFeatures = $answer.Split(" `t", 2, "RemoveEmptyEntries")

	$collectionFeatures.Split(',', [int32]::MaxValue, 'RemoveEmptyEntries') | select @{name="ID";expr={$_} },@{name="FeatureDirectory";expr={$features[$_]}},@{name="Scope";expr={"SiteCollection"}}
	$siteFeatures.Split(',', [int32]::MaxValue, 'RemoveEmptyEntries') | select @{name="ID";expr={$_}},@{name="FeatureDirectory";expr={$features[$_]}},@{name="Scope";expr={"Site"}}
}
# GetActivatedFeatures 'http://moss.go-planet.com' $NetCred # returns activated features, with names if run on server with same features installed
# GetActivatedFeatures 'http://rx200s3013' $NetCred

function global:DeleteList([string] $SiteUrl, [string] $name, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$SiteUrl.EndsWith('/_vti_bin/Lists.asmx')) {$SiteUrl += '/_vti_bin/Lists.asmx' }
	$result = SoapRequest $SiteUrl $sharepointNamespace 'DeleteList' "<listName>$name</listName>" $NetCred
	write-debug "DeleteList Answer= $(if ($result) {$result} else {'<null>'})"
	#$resx = [xml]$result
	#$answer = $resx #.Envelope.Body.DeleteListResponse.DeleteListResult
	#write-debug "DeleteList Answer= $(if ($answer) {$answer} else {'<null>'})"
}
# DeleteList 'http://sherman/sites/products/destination' '{5BD19C53-F0C9-4CE8-9006-A6B6564AE17E}'
# DeleteList 'http://sherman/sites/products/destination' 'Product Issues'

function global:GetSiteColumns
([string] $WebUrl, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$WebUrl.EndsWith('/_vti_bin/Webs.asmx')) {$WebUrl += '/_vti_bin/Webs.asmx' }
	$result = SoapRequest $WebUrl $sharepointNamespace 'GetColumns' "" $NetCred
	#write-debug "GetSiteColumns Answer= $(if ($result) {$result} else {'<null>'})"
	$resx = [xml]$result
	$answer = $resx.Envelope.Body.GetColumnsResponse.GetColumnsResult.Fields.Field
	#write-debug "GetSitecolumns Answer= $(if ($answer) {$answer} else {'<null>'})"
	$answer
}
# GetSiteColumns http://revere:1337 $localCred | ft id,StaticName,type

function global:UpdateSiteColumns
([string] $WebUrl, [string] $newFields, [string] $updateFields, [string] $deleteFields, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$WebUrl.EndsWith('/_vti_bin/Webs.asmx')) {$WebUrl += '/_vti_bin/Webs.asmx' }
	$fieldNodes = ""
	if (![string]::IsNullOrEmpty($newFields))
		{ $fieldNodes += "<newFields><Fields>$newFields</Fields></newFields>" }
	if (![string]::IsNullOrEmpty($updateFields))
		{ $fieldNodes += "<updateFields><Fields>$updateFields</Fields></updateFields>" } 
	if (![string]::IsNullOrEmpty($deleteFields))
		{ $fieldNodes += "<deleteFields><Fields>$deleteFields</Fields></deleteFields>" }
	if ([string]::IsNullOrEmpty($fieldNodes))
		{ throw "UpdateSiteColumns must have at least one of newFields, updateFields, deleteFields" }
	$result = SoapRequest $WebUrl $sharepointNamespace 'UpdateColumns' $fieldNodes $NetCred
	write-debug "UpdateSiteColumns Answer= $(if ($result) {$result} else {'<null>'})"
	$resx = [xml]$result
	$answer = $resx.Envelope.Body.UpdateColumnsResponse.UpdateColumnsResult.Results
	write-debug "UpdateSitecolumns Answer= $(if ($answer) {$answer} else {'<null>'})"
	$answer
}
# UpdateSiteColumns http://revere:1337 -deleteFields "<Field ID='{CBF7A92E-C140-43b3-9408-33E2FEBE385E}'/>" $localCred | tidy-xml
# UpdateSiteColumns http://revere:1337 -newFields "<Field ID='{CBF7A92E-C140-43b3-9408-33E2FEBE385E}' Name='SelectedItem' StaticName='SelectedItem' SourceID='http://schemas.microsoft.com/sharepoint/v3' Group='echoTechnology' DisplayName='Selected Item Checkbox' Type='Computed' Required='FALSE' Sealed='FALSE' ><FieldRefs><FieldRef Name='ID'/></FieldRefs><DisplayPattern><HTML><![CDATA[<input type=checkbox WT_SELECTIONCHECKBOX = true  title='selection checkbox' name='selectionCheckBox' WT_ENCODEDABSURL =']]></HTML><Field Name='EncodedAbsUrl'/><HTML><![CDATA[' ItemID=']]></HTML><Column Name='ID'/><HTML><![CDATA[' id='cbx_]]></HTML><Column Name='ID'/><HTML><![CDATA['>]]></HTML></DisplayPattern></Field>" $localCred | tidy-xml
# UpdateSiteColumns http://revere:1337 -updateFields "<Field ID='{CBF7A92E-C140-43b3-9408-33E2FEBE385E}' Name='SelectedItem' StaticName='SelectedItem' SourceID='http://schemas.microsoft.com/sharepoint/v3' Group='echoTechnology' DisplayName='Selected Item Checkbox' Type='Computed' Required='FALSE' Sealed='FALSE' ><FieldRefs><FieldRef Name='ID'></FieldRefs><DisplayPattern><HTML><![CDATA[<input type=checkbox WT_SELECTIONCHECKBOX = true  title='selection checkbox' name='selectionCheckBox' WT_ENCODEDABSURL =']]></HTML><Field Name='EncodedAbsUrl'/><HTML><![CDATA[' ItemID=']]></HTML><Column Name='ID'/><HTML><![CDATA[' id='cbx_]]></HTML><Column Name='ID'/><HTML><![CDATA['>]]></HTML></DisplayPattern></Field>" $localCred | tidy-xml

function global:GetSiteContentType
([string] $WebUrl, [string] $contentTypeId='0x', [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$WebUrl.EndsWith('/_vti_bin/Webs.asmx')) {$WebUrl += '/_vti_bin/Webs.asmx' }
	$result = SoapRequest $WebUrl $sharepointNamespace 'GetContentType' "<contentTypeId>$contentTypeId</contentTypeId>" $NetCred
	#write-debug "GetSiteContentTypes Answer= $(if ($result) {$result} else {'<null>'})"
	$resx = [xml]$result
	$answer = $resx.Envelope.Body.GetContentTypeResponse.GetContentTypeResult.ContentType
	#write-debug "GetSiteContentTypes Answer= $(if ($answer) {$answer} else {'<null>'})"
	$answer
}
# GetSiteContentType http://revere:1337/ '0x0100423C26A0AFF554449A14A7AB9A4FFCC6' $localCred | ft id,Name
# (GetSiteContentType http://revere:1337/ '0x0100423C26A0AFF554449A14A7AB9A4FFCC6' $localCred).get_OuterXml() | tidy-xml

function global:GetSiteContentTypes
([string] $WebUrl, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$WebUrl.EndsWith('/_vti_bin/Webs.asmx')) {$WebUrl += '/_vti_bin/Webs.asmx' }
	$result = SoapRequest $WebUrl $sharepointNamespace 'GetContentTypes' "" $NetCred
	#write-debug "GetSiteContentTypes Answer= $(if ($result) {$result} else {'<null>'})"
	$resx = [xml]$result
	$answer = $resx.Envelope.Body.GetContentTypesResponse.GetContentTypesResult.ContentTypes.ContentType
	#write-debug "GetSiteContentTypes Answer= $(if ($answer) {$answer} else {'<null>'})"
	$answer
}
# GetSiteContentTypes http://revere:1337 $localCred | ft id,Name
# GetSiteContentTypes http://revere/ $localCred | ? { $_.Name -eq 'Issue134ContentType' } | % { (GetSiteContentType http://revere $_.ID $localCred).get_OuterXml() } | tidy-xml

function global:GetNamedListItemsBySiteData([string] $url, [string] $name, [System.Net.NetworkCredential] $netCred=$null)
{
	GetListCollection $url -netcred $netCred | ? {$_.Title -eq $Name} | % { (GetListItemsBySiteData $url ($_.ID) -netcred:$netcred).data.row }
}
# GetListCollection ${srcUrl} -netcred $netCred | ? {$_.Title -eq 'IssuesListWithAssignedTo'} | % { (GetListItemsBySiteData ${srcUrl} ($_.ID) -netcred:$netcred).data.row }
# GetNamedListItemsBySiteData ${srcUrl} 'IssuesListWithAssignedTo' $netCred | ft

# GetListItemsByLists http://echodev-paris/sites/products/template 'General Discussion' -netcred:$netcred | ft
# GetListCollection http://echodev-paris/sites/products/template -netcred:$netcred | ft id,title
# GetNamedListItemsBySiteData ${srcUrl} 'IssuesListWithAssignedTo' $netCred | ft
# (GetListSchema ${SrcUrl} 'IssuesListWithAssignedTo' $NetCred).Fields.Field | ft
# (GetListSchema ${destUrl} 'IssuesListWithAssignedTo' ).Fields.Field | ft -auto RowOrdinal,StaticName,ColName,Type,Hidden,DisplayName,ReadOnly

# GetListCollection 'http://paris.echodev.local/sites/Products/Source' $NetCred | ? {$_.Title -eq 'RAILTracker_changed'} | % { SoapRequest "http://paris.echodev.local:668/RemoteEcho/ContentRetriever.asmx" "http://winapptechnolgy.com/webservices/" 'GetListsItemsUrls' "<listId>$($_.ID)</listId><webUrl>http://paris.echodev.local/sites/Products/Source</webUrl>" $NetCred }
# & { $url = 'http://paris.echodev.local/sites/SRPAMP' ; GetListCollection $url $NetCred | ? {$_.Title -eq 'RAIL Tracker'} | % { SoapRequest "http://paris.echodev.local:668/RemoteEcho/ContentRetriever.asmx" "http://winapptechnolgy.com/webservices/" 'GetListItemInfos' "<listId>$($_.ID)</listId><webUrl>$url</webUrl>" $NetCred } }

# $sch = GetListSchema http://paris/sites/products/1044 'Shared Documents' $NetCred
# $sourceUrl = 'http://paris/sites/products/1044'
# $netAdminCred = (get-credential "echodev\Administrator").GetNetworkCredential()
# SoapRequest "$sourceUrl/_vti_bin/Views.asmx" $sharepointNamespace 'GetViewCollection' '<listName>{E2D06445-210F-4953-8F46-D3C944D73CFD}</listName>' $netAdminCred | tidy-xml
# SoapRequest "$sourceUrl/_vti_bin/Views.asmx" $sharepointNamespace 'GetView' '<listName>{E2D06445-210F-4953-8F46-D3C944D73CFD}</listName><viewName>{D76EC52F-7B52-4823-AFEB-5D71137B0985}</viewName>' $netAdminCred | tidy-xml
# try # SoapRequest "$sourceUrl/_vti_bin/Views.asmx" $sharepointNamespace 'UpdateView' '<listName>{E2D06445-210F-4953-8F46-D3C944D73CFD}</listName><viewName>{D76EC52F-7B52-4823-AFEB-5D71137B0985}</viewName><viewProperties><View Name="{D76EC52F-7B52-4823-AFEB-5D71137B0985}" Type="HTML" Hidden="TRUE" Personal="TRUE" DisplayName="" Url="default.aspx" BaseViewID="1"/></viewProperties><viewFields><ViewFields><FieldRef Name="DocIcon" /><FieldRef Name="LinkFilename" /><FieldRef Name="Title" /><FieldRef Name="Range" /><FieldRef Name="Business_x0020_Group" /></ViewFields></viewFields>' $netAdminCred | tidy-xml



function global:GetWebPartProperties([string] $url, [string] $pageurl, [string] $storage="Shared", [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/WebPartPages.asmx')) {$url += '/_vti_bin/WebPartPages.asmx' }
	
	$query = ''
	if ('' -ne $pageurl) { $query += "<pageUrl>$pageurl</pageUrl>" }
	if ('' -ne $storage) { $query += "<storage>$storage</storage>" }
	
	$result = SoapRequest $url 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPartProperties' $query $netCred
	
	write-debug "GetWebPart2 Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.GetWebPartPropertiesResponse.GetWebPartPropertiesResult.WebParts.WebPart
}
function global:GetWebPartProperties2([string] $url, [string] $pageurl, [string] $storage="Shared", [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/WebPartPages.asmx')) {$url += '/_vti_bin/WebPartPages.asmx' }
	
	$query = ''
	if ('' -ne $pageurl) { $query += "<pageUrl>$pageurl</pageUrl>" }
	if ('' -ne $storage) { $query += "<storage>$storage</storage>" }
	$query += "<behavior>Version3</behavior>"
	
	$result = SoapRequest $url 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPartProperties2' $query $netCred
	
	write-debug "GetWebPart2 Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.GetWebPartProperties2Response.GetWebPartProperties2Result.WebParts.WebPart
}
# GetWebPartProperties2 "http://msw/AboutMicrosoft/Archives/ResearchTools/ImageViewer" "/AboutMicrosoft/Archives/ResearchTools/ImageViewer/Pages/SearchTest.aspx" -netcred $NetCred
# GetWebPartProperties2 "http://erichstehr/sites/Development/FFCDatabase" "Lists/Employees/DispForm.aspx" -cred $NetCred  | tidy-xml | out-file -enc UTF8 -FilePath DispForm.webparts.xml

function global:GetWebPart2([string] $url, [string] $pageurl, [string] $storageKey, [string] $storage="Shared", [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/WebPartPages.asmx')) {$url += '/_vti_bin/WebPartPages.asmx' }
	
	$query = ''
	if ('' -ne $pageurl) { $query += "<pageurl>$pageurl</pageurl>" }
	if ($null -ne $storageKey) { $query += "<storageKey>$storageKey</storageKey>" }
	if ('' -ne $storage) { $query += "<storage>$storage</storage>" }
	$query += "<behavior>Version3</behavior>"
	
	$result = SoapRequest $url 'http://microsoft.com/sharepoint/webpartpages' 'GetWebPart2' $query $netCred
	
	write-debug "GetWebPart2 Result= $(if ($result) {$result} else {'<null>'})"
	$resx = [xml]$result
	$resx.Envelope.Body.GetWebPart2Response.GetWebPart2Result
}
# GetWebPart2 "http://msw/AboutMicrosoft/Archives/ResearchTools/ImageViewer" "Pages/SearchTest.aspx" '{d83afffd-00e0-4060-8fc1-df04a23a96a7}' 'Shared' $NetCred


# 2011/02/06: not functional, claims no guids to look up
function global:GetKeywordTermsByGuids([string] $serverUrl, [string[]] $termIds, [int] $lcid=1033, [System.Net.NetworkCredential] $netCred=$null)
{
# termIDs from http://download.microsoft.com/download/8/5/8/858F2155-D48D-4C68-9205-29460FD7698F/[MS-EMMWS].pdf via http://social.technet.microsoft.com/Forums/en-US/sharepoint2010programming/thread/d66ad24f-a443-4c3f-b860-bc2a4c358290
	if (!$serverUrl.EndsWith('/_vti_bin/taxonomyclientservice.asmx')) {$serverUrl += '/_vti_bin/taxonomyclientservice.asmx' }
	
	$query += "<termIds>&lt;TermIdsForGetKeywordsClientService&gt;"
	$termIds | % { $query += "&lt;termId&gt;$_&lt;/termId&gt;" }
	$query += "&lt;/TermIdsForGetKeywordsClientServicegt;</termIds>"
	$query += "<lcid>$lcid</lcid>"
	
	$result = SoapRequest $serverUrl 'http://schemas.microsoft.com/sharepoint/taxonomy/soap' 'GetKeywordTermsByGuids' $query $netCred
	
	write-debug "GetKeywordTermsByGuids Result= $(if ($result) {$result} else {'<null>'})"
	$resx = [xml]$result
	$resx.Envelope.Body.GetKeywordTermsByGuidsResponse.GetKeywordTermsByGuidsResult
}
# GetKeywordTermsByGuids "http://sea-v-stehre" '6f5df138-3e4b-479f-b42d-a96ea65b769b' -netCred $NetCred

# 2011/09/02
function global:GetViewCollection([string] $url, [string]$listName, [System.Net.NetworkCredential] $netCred=$null) 
{
	if (!$url.EndsWith('/_vti_bin/Views.asmx')) {$url += '/_vti_bin/Views.asmx' }
	
	$query = "<listName>$listName</listName>"
	
	$result = SoapRequest $url $sharepointNamespace 'GetViewCollection' $query $netCred
	
	write-debug "GetViewCollection Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.GetViewCollectionResponse.GetViewCollectionResult.Views.View
	
}
# GetViewCollection 'http://erichstehr/sites/alphatesting/marketing' '{D87C3AF5-04BA-4F04-929A-EA03FD53EDA6}' $netCred

# 2011/09/02
function global:GetView([string] $url, [string]$listName, [string]$viewGuid, [System.Net.NetworkCredential] $netCred=$null) 
{
	if (!$url.EndsWith('/_vti_bin/Views.asmx')) {$url += '/_vti_bin/Views.asmx' }
	
	$query = "<listName>$listName</listName>"
	$query += "<viewName>$viewGuid</viewName>"
	
	$result = SoapRequest $url $sharepointNamespace 'GetView' $query $netCred
	
	write-debug "GetViewCollection Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.GetViewResponse.GetViewResult.View
	
}
# GetView 'http://erichstehr/sites/alphatesting/marketing' '{D87C3AF5-04BA-4F04-929A-EA03FD53EDA6}' '{15CB0AA1-BF8A-4BC1-BEAB-FACF1E3801FA}' $netCred

# 2012/04/05
function global:GetListAndView([string] $url, [string]$listName, [System.Net.NetworkCredential] $netCred=$null) 
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	
	$query = "<listName>$listName</listName>"
	
	$result = SoapRequest $url $sharepointNamespace 'GetListAndView' $query $netCred
	
	write-debug "GetListAndViewCollection Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.GetListAndViewResponse.GetListAndViewResult.ListAndView
	
}
# GetListAndView http://erichstehr/sites/Development/FFCDatabase Projects $netCred | tidy-xml
# GetListCollection http://erichstehr/sites/development/ffcdatabase | ? { $_.Title -eq 'Employees' } | % { (GetListItemsBySiteData http://erichstehr/sites/development/ffcdatabase $_.ID).data.row } | select ows_Employee,ows_PointsAwarded,ows_LastRewardLevel,ows_NextGrantableReward
# SoapRequest "http://ffc.loudtechinc.com/_vti_bin/Lists.asmx" $sharepointNamespace 'UpdateListItems' "<listName>Employees</listName><updates><Batch><Method ID='1' Cmd='Update'><Field Name='ID'>2</Field><Field Name='LastRewardLevel'>0</Field><Field Name='NextGrantableReward'>25</Field></Method></Batch></updates>" | tidy-xml
# GetListCollection http://erichstehr/sites/development/ffcdatabase 'Employees' | % { (GetListItemsBySiteData http://erichstehr/sites/development/ffcdatabase $_.ID).data.row } | select ows_Employee,ows_PointsAwarded,ows_LastRewardLevel,ows_NextGrantableReward

# 2012/07/09
function global:UpdateListItems([string] $url, [string]$listName, [string]$batchElem, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/Lists.asmx')) {$url += '/_vti_bin/Lists.asmx' }
	
	$query = "<listName>$listName</listName><updates>$batchElem</updates>"
	
	
	$result = SoapRequest $url $sharepointNamespace 'UpdateListItems' $query $netCred
	
	write-debug "UpdateListItems Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.UpdateListItemsResponse.UpdateListItemsResult.Results
	
}
# UpdateListItems "http://erichstehr/sites/devtesting" "Erich&apos;s Test List" "<Batch><Method ID='1' Cmd='Delete'><Field Name='ID'>2</Field><Field Name='Title'>Breaking change</Field></Method></Batch>" | tidy-xml

# $local = GetNamedListItemsBySiteData http://erichstehr/sites/devtesting/blog Posts | sort ows_PublishedDate
# $remote = GetNamedListItemsBySiteData http://groupvelocity.mackie.com/news Posts | sort ows_PublishedDate
# $local | sort ows_PublishedDate | % { $l = $_; $remote | ? { $_.ows_Title -eq $l.ows_Title } | select ows_ID,ows_Title,ows_PublishedDate,@{n='PublishedDate';e={$l.ows_PublishedDate}} }
# $local | sort ows_PublishedDate | % { $l = $_; $remote | ? { $_.ows_Title -eq $l.ows_Title } | % { $r = $_ ; UpdateListItems http://groupvelocity.mackie.com/news Posts "<Batch><Method ID='1' Cmd='Update'><Field Name='ID'>$($r.ows_ID)</Field><Field Name='PublishedDate'>$(([DateTime]$l.ows_PublishedDate).ToLocalTime().ToLocalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))</Field></Method></Batch>" } } | Tidy-xml

# 2012/12/06 : not correctly functioning on tested system. may be system instead of code _but_ ...
# BUGBUG: replace global: once functioning
function FBALogin([string] $url, [System.Net.NetworkCredential] $netCred=(get-credential "$env:USERDOMAIN\$env:USERNAME").GetNetworkCredential())
{
	if (!$url.EndsWith('/_vti_bin/Authentication.asmx')) {$url += '/_vti_bin/Authentication.asmx' }
	
	if (![string]::IsNullOrEmpty($netCred.Domain)) {
		$username = "w|$($NetCred.Domain)\$($NetCred.UserName)"
	} else {
		$username = $NetCred.UserName
	}
	$username = [System.Security.SecurityElement]::Escape($username)
	$query = "<username>$username</username><password>$([System.Security.SecurityElement]::Escape($NetCred.Password))</password>"
	
	$result = SoapRequest $url $sharepointNamespace 'Login' $query $netCred
	
	write-debug "FBALogin Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.LoginResponse.LoginResult
}
# FBALogin http://erichstehr:10080 (get-credential "$env:USERDOMAIN\$env:USERNAME").GetNetworkCredential()

# 2012/12/06
function global:FBAMode([string] $url)
{
	if (!$url.EndsWith('/_vti_bin/Authentication.asmx')) {$url += '/_vti_bin/Authentication.asmx' }
	
	$query = '' #"<username>$()</username><password>$()</password>"
	
	$result = SoapRequest $url $sharepointNamespace 'Mode' $query $netCred
	
	write-debug "FBALogin Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.ModeResponse.ModeResult
}
# FBAMode http://localhost

# 2012/12/20
function global:GetGroupCollectionFromUser([string] $url, [string]$userLoginName, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/UserGroup.asmx')) {$url += '/_vti_bin/UserGroup.asmx' }

	$query = "<userLoginName>$userLoginName</userLoginName>"
	
	$result = SoapRequest $url "${sharepointNamespace}directory/" 'GetGroupCollectionFromUser' $query $netCred
	
	write-debug "GetGroupCollectionFromUser Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.GetGroupCollectionFromUserResponse.GetGroupCollectionFromUserResult
}
# GetGroupCollectionFromUser http://erichstehr/sites/devtesting mackie\erich.stehr | tidy-xml
# GetGroupCollectionFromUser http://erichstehr/sites/devtesting mackie\SPTest1 | tidy-xml
# GetGroupCollectionFromUser http://erichstehr/sites/devtesting mackie\don.bannister | tidy-xml

# 2012/12/20
function global:GetAllUserCollectionFromWeb([string] $url, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/UserGroup.asmx')) {$url += '/_vti_bin/UserGroup.asmx' }

	$query = ""
	
	$result = SoapRequest $url "${sharepointNamespace}directory/" 'GetAllUserCollectionFromWeb' $query $netCred
	
	write-debug "GetAllUserCollectionFromWeb Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.GetAllUserCollectionFromWebResponse.GetAllUserCollectionFromWebResult.GetAllUserCollectionFromWeb.Users
}
# (GetAllUserCollectionFromWeb http://erichstehr/sites/devtesting).User | ft -AutoSize
# (GetAllUserCollectionFromWeb http://erichstehr/sites/devtesting).User | ft -AutoSize ID,Name,LoginName,Email,Sid

# 2012/12/20
function global:GetUserCollectionFromGroup([string] $url, [string]$groupName, [System.Net.NetworkCredential] $netCred=$null)
{
	if (!$url.EndsWith('/_vti_bin/UserGroup.asmx')) {$url += '/_vti_bin/UserGroup.asmx' }

	$query = "<groupName>$groupName</groupName>"
	
	$result = SoapRequest $url "${sharepointNamespace}directory/" 'GetUserCollectionFromGroup' $query $netCred
	
	write-debug "GetUserCollectionFromGroup Result= $(if ($result) {$result} else {'<null>'})"
	([xml]$result).Envelope.Body.GetUserCollectionFromGroupResponse.GetUserCollectionFromGroupResult
}
# GetUserCollectionFromGroup http://erichstehr/sites/devtesting incoming | tidy-xml

# 2012/12/20

#
# 
