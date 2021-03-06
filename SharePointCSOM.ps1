# portions from <http://blog.blumenthalit.com/blog/Lists/Posts/Post.aspx?ID=171> <http://www.sharepoint-reference.com/Blog/Lists/Posts/Post.aspx?ID=21>
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client.Runtime")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client.Publishing")
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client.Taxonomy")
#Add-Type -Path "$sphive\ISAPI\Microsoft.SharePoint.Client.dll" -ea Stop

$global:localCred = Get-Credential -UserName ${env:USERNAME}@microsoft.com -Message "Local credentials for later use"
$global:thisCred = [Net.CredentialCache]::DefaultNetworkCredentials
if ($null -eq $localCred) { $localCred = $thisCred }

function global:New-CsomSpoContext(
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
	[string]
	# site to work with, usually https://*.microsoft.com/
	$siteUrl, 
    [PsCredential]$credential=$(Get-Credential -Message "SPO credentials for $siteUrl")
	)
{
    trap {break;} # old-style halting stop
	$ctx = New-Object Microsoft.SharePoint.Client.ClientContext($siteUrl) 
	$credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($credential.UserName, $credential.Password) 
    if ($null -eq $credentials) { 
        throw "Could not acquire SP Online credentials!"
    }
	$ctx.Credentials = $credentials
	$ctx
}
# $ctx = New-CsomSpoContext 'https://microsoft.sharepoint.com/teams/PeakSandbox' v-erichs@microsoft.com ; $ctx.Load($ctx.Web.Lists); $ctx.ExecuteQuery(); $ctx.Web.Lists | ft -auto -wrap Title,ID,Hidden

# $oFile = $ctx.Web.GetFileByServerRelativeUrl('/teams/PeakSandbox/SitePages/Home.aspx'); $ctx.Load($oFile.ListItemAllFields); $li = $oFile.ListItemAllFields; $ppage = [Microsoft.SharePoint.Client.Publishing.PublishingPage]::GetPublishingPage($ctx, $li); $ppage.ServerObjectIsNull -eq $null <# true #>

function global:New-CsomContext(
	[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
	[string]
	# site to work with
	$siteUrl, 
	[System.Net.ICredentials]
	$cred=[Net.CredentialCache]::DefaultNetworkCredentials
	)
{
	$ctx = New-Object Microsoft.SharePoint.Client.ClientContext($siteUrl)
	if ($null -eq $cred) {
		$ctx.AuthenticationMode = [Microsoft.SharePoint.Client.ClientAuthenticationMode]::Anonymous
	} else {
		$ctx.Credentials = $cred
	}
	$ctx
}
# $context = New-CSOMContext http://peak-erichs-sp/sites/ExecComms
 
# swiped portions from http://adicodes.com/adding-web-part-to-page-with-powershell/
function global:AddWebPartToPage(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
	[string]$pageRelativeUrl,
	[Xml.XmlNode]$WebpartData,
	[string]$ZoneName,
	[int]$ZoneIndex=0,
	[switch]$WipeSameNamedWebParts=$true
	)
{
	$context.Load($context.Web);
	$context.ExecuteQuery();
	$oFile = $context.Web.GetFileByServerRelativeUrl($pageRelativeUrl);
	$context.Load($oFile);
	$context.ExecuteQuery();
	$wpm = $oFile.GetLimitedWebPartManager([Microsoft.Sharepoint.Client.WebParts.PersonalizationScope]::Shared); 
	$context.Load($wpm);
	$context.ExecuteQuery();
	# get name from webpartData 
	$xns = New-Object System.Xml.XmlNamespaceManager $WebpartData.OwnerDocument.NameTable
	$xns.AddNamespace('wp2', "http://schemas.microsoft.com/WebPart/v2")
	$xns.AddNamespace('wp3', "http://schemas.microsoft.com/WebPart/v3")
	$name = $webpartData.SelectSingleNode("/webParts/wp3:webPart/wp3:data/wp3:properties/wp3:property[@name='Title']|/wp2:WebPart/wp2:Title",$xns).InnerText
	if ($WipeSameNamedWebParts) {
		if ($name -ne $null) {
	        Write-Verbose "Wiping any web parts named '$name'"
	        $partdefs = $context.LoadQuery($wpm.WebParts);
        	$context.ExecuteQuery();
	        $namedParts = $partdefs | ? { $context.Load($_.WebPart); $context.ExecuteQuery(); $_.WebPart.Title -eq $name } # don't modify collection while enumerating
	        Write-Verbose "Wiping $($namedParts.Count) web parts"
	        $namedParts | % { $_.DeleteWebPart() }
	        $context.ExecuteQuery();
		}
	}
    #Add Web Part
	Write-Verbose "Adding web part $name"
    $oWebPartDefinition = $wpm.ImportWebPart($WebpartData.OuterXml);
    $wpNew = $wpm.AddWebPart($oWebPartDefinition.WebPart, $ZoneName, $ZoneIndex);
    $context.ExecuteQuery();
}
# $dwp = [xml]""; $dwp.Load("$env:USERPROFILE\Documents\Visual Studio 2012\Projects\ExecComms20\WebParts\Venue.JS.webpart"); AddWebPartToPage $context "/sites/ExecComms/Pages/default.aspx" $dwp.DocumentElement "TopLeft" 1 -wipe:$false -verbose
# $dwp2 = [xml]""; $dwp2.Load("$env:USERPROFILE\Documents\Visual Studio 2012\Projects\ExecComms20\WebParts\Venues.dwp"); AddWebPartToPage $context "/sites/ExecComms/Pages/default.aspx" $dwp2.DocumentElement "Header" 1 -wipe -verbose
# $cqwp.Load("$pwd\CBQ - All Speakers.webpart"); AddWebPartToPage $context '/teams/ExecComms/Pages/ViewKeyEvent.aspx' $cqwp.DocumentElement "Main" 5 -wipe -verbose
# $vkej.Load("$pwd\WebParts\ViewKeyEventsJS.webpart"); AddWebPartToPage $context '/teams/ExecComms/Pages/ViewKeyEvent.aspx' $vkej.DocumentElement "Main" 1 -wipe -verbose
# $csomEventWp.Load("$pwd\ExecEvents-CSOM.dwp"); AddWebPartToPage $context '/teams/ExecComms/SteveBallmer/Event1/Pages/default.aspx' $csomEventWp.DocumentElement "Right" 1 -wipe -verbose

function global:UpdateWebParts(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
	[string]$pageServerRelativeUrl,
    [ScriptBlock]
    # returns true for each WebPartDefinition returned from $partdefs (=$wpm.WebParts) to be processed by $updateBlock
    $selectBlock={$true},
    [ScriptBlock]
    # 'update's the selected web parts, may just dump information
    $updateBlock={}
	)
{
	$context.Load($context.Web);
	$context.ExecuteQuery();
	$oFile = $context.Web.GetFileByServerRelativeUrl($pageServerRelativeUrl);
	$context.Load($oFile);
	$context.ExecuteQuery();
	$wpm = $oFile.GetLimitedWebPartManager([Microsoft.Sharepoint.Client.WebParts.PersonalizationScope]::Shared); 
	$context.Load($wpm);
	$context.ExecuteQuery();

	$partdefs = $context.LoadQuery($wpm.WebParts);
    $context.ExecuteQuery();
	$targets = $partdefs | ? { $context.Load($_.WebPart); $context.Load($_.WebPart.Properties); $context.ExecuteQuery(); & $selectBlock } # don't modify collection while enumerating
	Write-Verbose "Updating $($targets.Count) web parts"
	$targets | % $updateBlock
	$context.ExecuteQuery();
}
# UpdateWebParts $context "/sites/ExecComms/Pages/default.aspx" -updateBlock { New-Object PSObject -property @{'Title'=$_.WebPart.Title; "Id"=$_.ID; "ListGuid"=$_.WebPart.Properties["ListGuid"]; "ListDisplayName"=$_.WebPart.Properties["ListDisplayName"]} }
# UpdateWebParts $context "/sites/ExecComms/Pages/default.aspx" { $_.WebPart.Title.StartsWith('Venues JS') } -updateBlock { $wpd = $_; $context.Load($context.Web.Lists); $context.ExecuteQuery(); $context.Web.Lists | ? { $_.Title -eq $wpd.WebPart.Properties["ListDisplayName"] } | % { $wpd.WebPart.Properties["ListGuid"] = $_.ID.ToString() ; $wpd.WebPart.Properties["ListName"] = "" }; $wpd.SaveWebPartChanges() } -verbose
# UpdateWebParts $context "/sites/ExecComms/Pages/default.aspx" { $_.WebPart.Title.StartsWith('Venues JS') } -updateBlock { $_.WebPart.Properties["ParameterBindings"] } -verbose
# UpdateWebParts $context "/sites/ExecComms/Pages/default.aspx" { $_.WebPart.Title.StartsWith('Venues JS') } -updateBlock { $_.DeleteWebPart() } -verbose

# UpdateWebParts $context "/sites/ExecComms/Pages/ViewKeyEvent.aspx" { $_.WebPart.Title -eq 'View Key Events JS' } -updateBlock { $_.WebPart.Properties.FieldValues.GetEnumerator() | ? { $_.Key -match "1"} } -verbose


# checkin
# checkout 
# publish
# from <http://www.hartsteve.com/2013/06/sharepoint-csom-powershell-examples>
        # $pubPage.ListItem.File.CheckIn("", [Microsoft.SharePoint.Client.CheckinType]::MajorCheckIn) 
        # $pubPage.ListItem.File.Publish("") 
        # $pubPage.ListItem.File.Approve("") 

function global:CsomCheckoutUrl(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
	[string]$pageServerRelativeUrl
)
{
    trap {throw "CsomCheckoutUrl:$pageServerRelativeUrl :$_"; }
    $context.Load($context.Web); $context.ExecuteQuery();
    $oF = $context.Web.GetFileByServerRelativeUrl($pageServerRelativeUrl); $context.Load($oF); $context.ExecuteQuery();
    if ($oF.ListItemAllFields -eq $null) {
        Write-Warning "ListItemAllFields is null: $pageServerRelativeUrl"
    } else {
        try {
        $context.Load($oF.ListItemAllFields); $context.ExecuteQuery();
        if ($oF.ListItemAllFields.ParentList -eq $null) {
            Write-Warning "ListItemAllFields is null: $pageServerRelativeUrl"
        } else {
            $context.Load($oF.ListItemAllFields.ParentList); $context.ExecuteQuery();
        }
        } catch {
            Write-Warning "Caught exception verifying ListItemAllFields.ParentList on ${pageServerRelativeUrl}: $_"
        }
    }
    if ($oF.ListItemAllFields.ParentList.ForceCheckout) {
        if ($oF.CheckOutType -eq [Microsoft.SharePoint.Client.CheckOutType]::None) {
            Write-Verbose "Checking out $pageServerRelativeUrl"
            $oF.CheckOut(); $context.ExecuteQuery();
        }
    }
    return $oF
}

# $oFile = CsomCheckoutUrl $context "$serverRelativeUrl/Pages/default.aspx"

function global:CsomCheckinUrl(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.File] $oFile,
    [string]$checkInComment="",
    [Microsoft.SharePoint.Client.CheckinType]$checkinType=[Microsoft.SharePoint.Client.CheckinType]::MajorCheckIn, 
    [switch]$publish=$true, 
    [switch]$approve=$true
) 
{
    trap {break;}
    if ($oFile.ListItemAllFields.ParentList.ForceCheckout) {
        if ($oFile.CheckOutType -ne [Microsoft.SharePoint.Client.CheckOutType]::None) {
            $oFile.CheckIn($checkInComment, $checkinType); $context.ExecuteQuery()
            if ($publish) { $oFile.Publish($checkInComment) } 
            if ($approve -and $oFile.ListItemAllFields.ParentList.EnableModeration) { $oFile.Approve($checkInComment) }
            $context.ExecuteQuery()
        }
    }
}
# CsomCheckinUrl $context $oFile


function Export-CsomTaxonomy(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context
    # TODO: object properties (including LCIDs) for TermStores, Groups, TermSets, Terms; batching tohandle timeouts
)
{
    function HandleTermSetItem($termSetItem, $xtermSetItem) {
    # recurse over the sub-terms of $termSetItem to include them in the XML of $xtermSetItem
        $terms = $context.LoadQuery($termSetItem.Terms)
        $context.ExecuteQuery()
        $terms = @($terms)
        Write-Verbose "$($terms.Count) terms"
        $terms | % {
            $term = $_
            Write-Verbose "$($term.Name) ID = $($term.Id)"
            $xterm = $xtermSetItem.AppendChild($value.CreateElement("Term"))
            [void]$xterm.SetAttribute("Name", $term.Name)
            [void]$xterm.SetAttribute("id", $term.Id)
            HandleTermSetItem $term $xterm
        }
    }

    $value = [xml]"<Taxonomy></Taxonomy>"
    $doc = $value.documentElement

    # from <http://geeks.ms/blogs/lmanez/archive/2013/08/29/deploying-managed-metadata-fields-declaratively-in-sharepoint-2013-online-office-365.aspx>
    $taxonomySession = [Microsoft.SharePoint.Client.Taxonomy.TaxonomySession]::GetTaxonomySession($context);
    $taxonomySession.UpdateCache();
    $context.Load($taxonomySession);
    $context.ExecuteQuery();

    $termStores = $context.LoadQuery($taxonomySession.TermStores);
    $context.ExecuteQuery();
    Write-Verbose "$($termStores.Count) termstores"

    @($termStores) | % {
        $termStore = $_;
        Write-Verbose "$($termStore.Name) ID = $($termStore.Id)"
		$xtermstore = $doc.AppendChild($value.CreateElement("TermStore"))
		[void]$xtermstore.SetAttribute("Name", $termStore.Name)
		[void]$xtermstore.SetAttribute("id", $termStore.Id)
        $groups = $context.LoadQuery($termStore.Groups)
        $context.ExecuteQuery();
        $groups = @($groups) # otherise $groups.Count returns collection of n 1's for the n items
        Write-Verbose "$($groups.Count) groups"
        $groups | % {
            $group = $_
            Write-Verbose "$($group.Name) ID = $($group.Id)"
		    $xgroup = $xtermstore.AppendChild($value.CreateElement("TermGroup"))
		    [void]$xgroup.SetAttribute("Name", $group.Name)
		    [void]$xgroup.SetAttribute("id", $group.Id)
            $termSets = $context.LoadQuery($group.TermSets)
            $context.ExecuteQuery()
            $termSets = @($termSets)
            Write-Verbose "$($termSets.Count) termsets"
            $termSets | % {
                $termSet = $_
                Write-Verbose "$($termSet.Name) ID = $($termSet.Id)"
                $xtermSet = $xgroup.AppendChild($value.CreateElement("TermSet"))
                [void]$xtermSet.SetAttribute("Name", $termSet.Name)
                [void]$xtermSet.SetAttribute("id", $termSet.Id)
                #recurse on TermSetItem for sub-terms
                HandleTermSetItem $termSet $xtermSet
            }
        }
    }
    return $value
}
# $ctx = New-CsomSpoContext -siteUrl https://microsoft.sharepoint.com/teams/ExecComms v-erichs@microsoft.com; (Export-CsomTaxonomy $ctx -verbose).get_OuterXml()
# $ctx = New-CsomSpoContext -siteUrl https://microsoft.sharepoint.com/teams/ExecComms v-erichs@microsoft.com; (Export-CsomTaxonomy $ctx -verbose).Save('.\taxonomy.xml')


function global:Export-CsomTaxonomyFile(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
    [Parameter(Mandatory=$true)]
    [string] $path
    # TODO: object properties (including LCIDs) for TermStores, Groups, TermSets, Terms; batching tohandle timeouts
    # Uses XmlWriter (stream) instead of an in-memory XmlDocument
)
{
    function HandleTermSetItem($termSetItem) {
    # recurse over the sub-terms of $termSetItem to include them in the XML of $xtermSetItem
        $terms = $context.LoadQuery($termSetItem.Terms)
        $context.ExecuteQuery()
        $terms = @($terms)
        Write-Verbose "$($terms.Count) terms"
        $terms | % {
            $term = $_
            Write-Verbose "$($term.Name) ID = $($term.Id)"
            $w.WriteStartElement("Term")
            $w.WriteAttributeString("Name", $term.Name)
            $w.WriteAttributeString("id", $term.Id)
            HandleTermSetItem $term
            $w.WriteEndElement()
            $w.Flush() # for debugging
        }
    }

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.OmitXmlDeclaration = $false
    $settings.NewLineOnAttributes = $true

    $p = [System.IO.Path]::Combine($PWD, $path)
    $w = [System.Xml.XmlWriter]::Create($p, $settings)
    
    $w.WriteStartDocument($true)
    $w.WriteStartElement("Taxonomy");

    # from <http://geeks.ms/blogs/lmanez/archive/2013/08/29/deploying-managed-metadata-fields-declaratively-in-sharepoint-2013-online-office-365.aspx>
    $taxonomySession = [Microsoft.SharePoint.Client.Taxonomy.TaxonomySession]::GetTaxonomySession($context);
    $taxonomySession.UpdateCache();
    $context.Load($taxonomySession);
    $context.ExecuteQuery();

    $termStores = $context.LoadQuery($taxonomySession.TermStores);
    $context.ExecuteQuery();
    Write-Verbose "$($termStores.Count) termstores"

    @($termStores) | % {
        $termStore = $_;
        Write-Verbose "$($termStore.Name) ID = $($termStore.Id)"
        $w.WriteStartElement("TermStore")
        $w.WriteAttributeString("Name", $termStore.Name)
        $w.WriteAttributeString("id", $termStore.Id)
        $groups = $context.LoadQuery($termStore.Groups)
        $context.ExecuteQuery();
        $groups = @($groups) # otherise $groups.Count returns collection of n 1's for the n items
        Write-Verbose "$($groups.Count) groups"
        $groups | % {
            $group = $_
            Write-Verbose "$($group.Name) ID = $($group.Id)"
            $w.WriteStartElement("TermGroup")
            $w.WriteAttributeString("Name", $group.Name)
            $w.WriteAttributeString("id", $group.Id)
            $termSets = $context.LoadQuery($group.TermSets)
            $context.ExecuteQuery()
            $termSets = @($termSets)
            Write-Verbose "$($termSets.Count) termsets"
            $termSets | % {
                $termSet = $_
                Write-Verbose "$($termSet.Name) ID = $($termSet.Id)"
                $w.WriteStartElement("TermSet")
                $w.WriteAttributeString("Name", $termSet.Name)
                $w.WriteAttributeString("id", $termSet.Id)
                #recurse on TermSetItem for sub-terms
                HandleTermSetItem $termSet
                $w.WriteEndElement() # TermSet
            }
            $w.WriteEndElement() # TermGroup
        }
        $w.WriteEndElement() # TermStore
    }
    $w.WriteEndElement() #Taxonomy

    $w.WriteEndDocument()        
    $w.Close()
}
# $ctx = New-CsomSpoContext -siteUrl https://microsoft.sharepoint.com/teams/ExecComms v-erichs@microsoft.com; Export-CsomTaxonomyFile $ctx '.\taxonomy-xw.xml' -verbose

function global:Get-CsomAllSiteColumns(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $ctx
)
{
    $value = $ctx.LoadQuery($ctx.Web.Fields)
    $ctx.ExecuteQuery()

    return @($value) # form PowerShell collection instead of Microsoft.SharePoint.Client.ClientQueryableResult`1[[Microsoft.SharePoint.Client.Field, Microsoft.SharePoint.Client, Version=15.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c]]
}

function Import-CsomTaxonomyFile(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [string]$path,
    [string]
    # which subtrees in the file $path are being imported?
    $xpath="/"

    # TODO: object properties (including LCIDs) for TermStores, Groups, TermSets, Terms; batching tohandle timeouts
)
{
}


# inspired by http://www.sharepointnutsandbolts.com/2013/12/Using-CSOM-in-PowerShell-scripts-with-Office365.htm
function global:Enable-CsomFeature(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    # $context.Site or $context.Web to be activated in
	$WebOrSite,
	[Parameter(Mandatory=$true)]
    # will try as GUID or as DisplayName
    $featureId,
    [switch] $force=$false
)
{
    trap {break;} # old style halting stop
    $featureGuid = [Guid]::Empty
    if ($featureId -is [GUID]) {
        $featureGuid = $featureId
    } elseif (![Guid]::TryParse($featureId, [ref]$featureGuid)) {
        throw "Can't interpret $featureId as GUID"
    }

    $context.Load($WebOrSite); $context.ExecuteQuery();
    $context.Load($WebOrSite.Features); $context.ExecuteQuery();
    $WebOrSite.Features.Add($featureGuid, $force, [Microsoft.SharePoint.Client.FeatureDefinitionScope]::Site);
    # FeatureDefinitionScope.Site comes from the sandbox
    $context.ExecuteQuery();

}

# inspired by http://www.sharepointnutsandbolts.com/2013/12/Using-CSOM-in-PowerShell-scripts-with-Office365.htm
function global:Disable-CsomFeature(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    # $context.Site or $context.Web to be activated in
	$WebOrSite,
	[Parameter(Mandatory=$true)]
    # will try as GUID or as DisplayName
    $featureId,
    [switch] $force=$false
)
{
    trap {break;} # old style halting stop
    $featureGuid = [Guid]::Empty
    if ($featureId -is [GUID]) {
        $featureGuid = $featureId
    } elseif (![Guid]::TryParse($featureId, [ref]$featureGuid)) {
        throw "Can't interpret $featureId as GUID"
    }

    $context.Load($WebOrSite); $context.ExecuteQuery();
    $context.Load($WebOrSite.Features); $context.ExecuteQuery();
    $WebOrSite.Features.Remove($featureGuid, $force);
    $context.ExecuteQuery();

}

# from an SP server (for .DisplayName or other properties beyond DefinitionId): $context.Load($context.Web.Features); $context.ExecuteQuery(); $features = @($context.Web.Features.GetEnumerator()) ; $features | % { Get-SPFeature $_.DefinitionId } | select Id,DisplayName

function global:Get-CsomListByTitle(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [string]$listTitle
)
# loads $list object, not just bring it back unexecuted
{
    $list = $context.Web.Lists.GetByTitle($listTitle); $context.ExecuteQuery()
    $context.Load($list); $context.ExecuteQuery()
    return $list
}

function global:Remove-CsomListByTitle(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [string]$listTitle,
    [switch]$WhatIf=$WhatIfPreference
)
{
    $list = $context.Web.Lists.GetByTitle($listTitle)
    $context.ExecuteQuery()
    if (($null -eq $list) -or $list.ServerObjectIsNull) { return }
    if ($WhatIf) {
        $state = $WarningPreference
        $warningPreference = "Continue"
        Write-Warning "Would have removed $listTitle on $($context.Web.Url)"
        $warningPreference = $state
    } else {
        Write-Verbose "Removing $listTitle on $($context.Web.Url)"
        $list.DeleteObject()
        $context.ExecuteQuery()
    }
}

function global:Get-CsomListById(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [GUID]$listGuid,
    [Microsoft.SharePoint.Client.Web]$web=$context.Web
)
{
    $list = $web.Lists.GetById($listGuid)
    $context.Load($list); $context.ExecuteQuery();
    ,$list
}

function global:Get-CsomWebTemplates(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
    [int]
    #LCID of desired template language
    $lcid=1033,
    [int]
    # template compatibility level (0 for site compatibility level)
    $overrideCompatLevel=0
)
{
    $context.Load($context.Site); $context.ExecuteQuery()
    $wts = $context.Site.GetWebTemplates($lcid, $overrideCompatLevel); $context.Load($wts); $context.ExecuteQuery()
    return @($wts)
}

function global:Remove-CsomWeb(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [string]$serverRelativeWebUrl,
    [switch]$WhatIf=$WhatIfPreference
)
{
    $web = $context.Site.OpenWeb($serverRelativeWebUrl)
    $context.ExecuteQuery()
    if (($null -eq $web) -or $web.ServerObjectIsNull) { return }
    if ($WhatIf) {
        $state = $WarningPreference
        $warningPreference = "Continue"
        Write-Warning "Would have removed $serverRelativeWebUrl"
        $warningPreference = $state
    } else {
        Write-Verbose "Removing web $serverRelativeWebUrl"
        $web.DeleteObject()
        $context.ExecuteQuery()
    }
}

$justGuidRe = "^[A-Za-z0-9]{8}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{12}$" #http://www.regexlib.com/Search.aspx?k=guid
$guidRe = "([A-Za-z0-9]{8}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{12})" # anywhere in line, grouping
$guidRe = "([{|\(]?[0-9a-fA-F]{8}[-]?([0-9a-fA-F]{4}[-]?){3}[0-9a-fA-F]{12}[\)|}]?)"
# $context.Load($context.Web.Features); $context.ExecuteQuery()
# $context.Web.Features | ... DefinitionId | out-file -enc ASCII $pwd\SandboxWebFeatures.txt
# $sandboxWebFeatureGuids = gc .\SandboxWebFeatures.txt | ? { $_ -match $guidRe } | % {[GUID]$_ } 
# gc ONET.xml | % { if ($_ -match $guidRe ) { write-output ([GUID]$Matches[0]) } } | ? { !$sandboxWebFeatureGuids.Contains($_) }

function global:Get-CsomSiteColumnReferences(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [string] 
    # could be Name or GUID
    $columnName,
    [switch]$Confirm=$ConfirmPreference
)
{
    # handle the difference between name and GUID
    try {
        $guid = [GUID]$columnName
        $scanBlock = { 
            try { 
                $field = $_.Fields.GetById($guid); $context.Load($field); $context.ExecuteQuery();
                $field
            } catch {
                if ($_.ToString() -notmatch 'Invalid field name.') {throw;}
            }
        }
    } catch {
        $scanBlock = { 
            try { 
                $field = $_.Fields.GetByInternalNameOrTitle($columnName); $context.Load($field); $context.ExecuteQuery();
                $field
            } catch {
                if ($_.ToString() -notmatch 'does not exist.') {throw;}
            }
        }
   }

    # CSOM doesn't include AllWebs, so we'll need to walk the tree....
    function RecurseWebs(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [Microsoft.SharePoint.Client.Web] $web
    )
    {
        $context.Load($web.Lists); $context.ExecuteQuery();
        $web.Lists | % {
            $list = $_;
            $context.Load($list); $context.ExecuteQuery();
            $context.Load($list.Fields); $context.ExecuteQuery();
            $field = (. $scanBlock)
            if ($field -ne $null) {
                New-Object PSObject -Property @{FieldId=$field.Id; ListId=$list.Id; WebId=$web.Id; ListUrl="$($web.ServerRelativeUrl)##$($list.Title)"} 
                #New-Object PSObject -Property @{Field=$field; List=$list; Web=$web} 
            }
        }
        $context.Load($web.Webs); $context.ExecuteQuery();
        $web.Webs.GetEnumerator() | % {
            RecurseWebs $context $_
        }
    }

    $context.Load($context.Site); $context.ExecuteQuery();
    $web = $context.Site.RootWeb; $context.Load($web); $context.ExecuteQuery();
    RecurseWebs $context $web
    $cts = $context.Site.RootWeb.ContentTypes; $context.Load($cts); $context.ExecuteQuery();
    $cts.GetEnumerator() | % {
            $field = (. $scanBlock)
            if ($field -ne $null) {
                New-Object PSObject -Property @{FieldId=$field.Id;FieldStaticName=$field.StaticName; ContentTypeId=$_.Id; ContentTypeName=$_.Name} 
            }
    }


}

# Get-CsomSiteColumnReferences  $context '{2ab9e8de-6244-48a1-93d3-3ab2a630beeb}'
# Get-CsomSiteColumnReferences  $context '{2ab9e8db-6244-48a1-93d3-3ab2a630beeb}'
# Get-CsomSiteColumnReferences  $context 'Executives

function global:Get-CsomContentTypeReferences(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [string]$contentId="0x"
)
{
    $scanBlock = {
        try { 
            $l = $_
            $l.ContentTypes.GetEnumerator() | % {
                $ct = $_; $context.Load($ct); $context.ExecuteQuery();
                if ($ct.Id.StringValue.StartsWith($contentId)) { 
                    $ct 
                }
            }
        } catch {
            if ($_.ToString() -notmatch 'Invalid field name.') {throw;}
        }
    }

    # CSOM doesn't include AllWebs, so we'll need to walk the tree....
    function RecurseWebs(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [Microsoft.SharePoint.Client.Web] $web
    )
    {
        $context.Load($web.Lists); $context.ExecuteQuery();
        $web.Lists | % {
            $list = $_;
            $context.Load($list); $context.ExecuteQuery();
            $context.Load($list.ContentTypes); $context.ExecuteQuery();
            $ct = (. $scanBlock)
            if ($ct -ne $null) {
                New-Object PSObject -Property @{WebId=$web.Id; ListId=$list.Id; ContentTypeId=$ct.Id; ContentTypeName=$ct.Name} 
                #New-Object PSObject -Property @{Field=$field; List=$list; Web=$web} 
            }
        }
        $context.Load($web.Webs); $context.ExecuteQuery();
        $web.Webs.GetEnumerator() | % {
            RecurseWebs $context $_
        }
    }

    $context.Load($context.Site); $context.ExecuteQuery();
    $web = $context.Site.RootWeb; $context.Load($web); $context.ExecuteQuery();
    RecurseWebs $context $web
}
# Get-CsomContentTypeReferences $context "0x0120D520A8"
# Get-CsomContentTypeReferences $context "0x010085EC78BE64F9478AAE3ED069093B9963"

function global:Remove-CsomWeb(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    $webSiteRelativeUrl,
    [switch]$WhatIf=$WhatIfPreference
)
{
    $web = $context.Site.OpenWeb($webSiteRelativeUrl); $context.Load($web); $context.ExecuteQuery()
    if ($WhatIf) {
        Write-Warning "WhatIf: would have removed $($web.Url)"
    } else {
        Write-Verbose "Removing $($web.Url)"
        $web.DeleteObject(); $context.ExecuteQuery();
    }
}

#Remove-CsomWeb $context "$($context.Site.ServerRelativeUrl)/Exec1/Event1"
#Remove-CsomWeb $context "$($context.Site.ServerRelativeUrl)/Exec1"

function global:RepairLookupFieldTarget(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.FieldCollection] $fields,
	[Parameter(Mandatory=$true)]
	[string]$fieldName,
	[Parameter(Mandatory=$true)]
	[GUID]$webId,
	[Parameter(Mandatory=$true)]
	[GUID]$listId
)
{
    $field = $fields.GetByInternalNameOrTitle($fieldName); $context.Load($field); $context.ExecuteQuery()
    $xml = [xml]$field.SchemaXml
    Write-Debug $xml.OuterXml
    $xml.Field.WebId = $webId.ToString('B')
    $xml.Field.List = $listId.ToString('B')
    $field.SchemaXml = $xml.OuterXml
    Write-Debug $xml.OuterXml
    $field.UpdateAndPushChanges($true);
    $context.ExecuteQuery()
}

if ($false) {
$context.Load($context.Web); 
$context.Load($context.Web.Lists); 
$context.Load($context.Web.Fields);
$context.ExecuteQuery(); 
$templists = ( 'Venues','BreakoutVenues','KeyEvents','Divisions','Executives' | % { $x = $context.Web.Lists.GetByTitle($_); $context.Load($x); $context.ExecuteQuery(); $x });
$webId = [guid]$context.Web.Id
$fields = $context.Web.Fields;
RepairLookupFieldTarget $context $fields 'Venue' $webId $templists[0].Id
RepairLookupFieldTarget $context $fields 'BreakoutVenue' $webId  $templists[1].Id
RepairLookupFieldTarget $context $fields 'KeyEvent' $webId $templists[2].Id
RepairLookupFieldTarget $context $fields 'Division' $webId $templists[3].Id
RepairLookupFieldTarget $context $fields 'Executive' $webId  $templists[4].Id
RepairLookupFieldTarget $context $fields 'Executives' $webId  $templists[4].Id

$field = $context.Web.Fields.GetByInternalNameOrTitle('Phase'); $context.Load($field); $context.ExecuteQuery()
$xml = [xml]$field.SchemaXml
$xml.Field.CHOICES.InnerXml = @'
<CHOICE>0 – Pending Approval</CHOICE>
<CHOICE>1 – Approved Not Started</CHOICE>
<CHOICE>2 – Content In Progress</CHOICE>
<CHOICE>3 – Design In Progress</CHOICE>
<CHOICE>4 – Content Complete</CHOICE>
<CHOICE>5 – Event Archived</CHOICE>
<CHOICE>6 – Not Approved</CHOICE>
<CHOICE>7 – Cancelled</CHOICE>		
<CHOICE></CHOICE>
'@
$field.SchemaXml = $xml.OuterXml
$xml.OuterXml
$field.UpdateAndPushChanges($true);
$context.ExecuteQuery()

$Field.SchemaXml='<Field ID="{2ab9e85a-6244-48a1-93d3-3ab2a630beeb}" DisplayName="Venue" StaticName="Venue" Name="Venue" Type="Lookup" Group="ExecComms" DisplaceOnUpgrade="TRUE" List="{82b3ab4d-16f5-4223-aa21-01fa544fc03b}" WebId="{9a10a4b0-44e1-4b3e-a645-17af7e82b6df}" ShowField="Title" Description="" SourceID="{9a10a4b0-44e1-4b3e-a645-17af7e82b6df}" Version="16"></Field>'
#$Field.SchemaXml='<Field ID="{2ab9e85a-6244-48a1-93d3-3ab2a630beeb}" DisplayName="Venue" StaticName="Venue" Name="Venue" Type="Choice" FillInChoice="TRUE" Group="ExecComms" DisplaceOnUpgrade="TRUE" Description="" ><CHOICES><CHOICE></CHOICE></CHOICES><Default></Default></Field>'
$Field.UpdateAndPushChanges($true);
$context.ExecuteQuery()
# failed to change in lists KeyEvents, SLTEvents, ExecEvents; can't shift from int to text/string; manually recreated by Whitney

$field = $context.Web.Fields.GetByInternalNameOrTitle('CommType')
$context.Load($field); $context.ExecuteQuery()
$xml = [xml]$field.SchemaXml
$xml.Field.CHOICES.InnerXml = @'
<CHOICE>Speech</CHOICE>
<CHOICE>PPT</CHOICE>
<CHOICE>Video</CHOICE>
<CHOICE>Email</CHOICE>
<CHOICE>Press 1:1</CHOICE>
<CHOICE>Press Conference</CHOICE>
<CHOICE>Field Visit</CHOICE>
<CHOICE>Other</CHOICE>
'@
$field.SchemaXml = $xml.OuterXml
$xml.OuterXml
$field.UpdateAndPushChanges($true);
$context.ExecuteQuery()
}


function global:CsomImplicitLoadQuery(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
	<#[Microsoft.SharePoint.Client.ClientObject]#> $object=$context.Web,
	[Parameter(Mandatory=$true)]
	[string]$propertyName="Webs"
)
{
    if (!$object."$property".AreItemsAvailable) {
        $context.Load($object); $context.ExecuteQuery();
        $context.Load($object."$property"); $context.ExecuteQuery();
    }
    $object."$property" | % { $context.Load($_); $context.ExecuteQuery(); $_ }
}

# $webs = CsomImplicitLoadQuery $context $context.Web Webs

## from <http://www.enjoysharepoint.com/Articles/Details/working-with-list-using-sharepoint-2013-client-object-model-186.aspx>
# $context.Load($context.Web.ListTemplates); $context.ExecuteQuery(); $context.Web.ListTemplates | sort ListTemplateTypeKind | select Name,ListTemplateTypeKind
# $creationInfo = New-Object Microsoft.SharePoint.Client.ListCreationInformation
# $creationInfo.TemplateType = 150
# $creationInfo.Title = "Milestones"
# $creationInfo.Description = "Project Milestones"
# $web = $context.Site.OpenWeb("/teams/ExecComms/SteveBallmer/Event1")
# $context.Load($web); $context.ExecuteQuery()
# $list = $web.Lists.Add($creationInfo); $list.Update(); $context.ExecuteQuery();

# repairing broken and partially replaced dependant lookups
if ($false) {
    $context = New-CsomSpoContext https://microsoft.sharepoint.com/teams/ExecComms $localCred
    $context.Load($context.Web); $context.ExecuteQuery()
    $context.Load($context.Web.Webs); $context.ExecuteQuery()
    $webs = $context.Web.Webs.GetEnumerator() | % { $context.Load($_); $_ } ; $context.ExecuteQuery()
    $execlists = $webs | % { $l = $_.Lists.GetByTitle("ExecEvents"); $context.Load($l); $l } ; $context.ExecuteQuery();
    $execlists | %{ $l = $_; $context.Load($l); $context.ExecuteQuery(); $context.Load($l.Fields); $context.ExecuteQuery(); $l.Fields.GetByInternalNameOrTitle('Key_x0020_Event_x003A_ID0') }
}
if ($false) {
    $listname = "ExecEvents"
    $brokenGuid = [guid]'23c35193-85d8-40ce-ac80-521c23dadb67'
    $replacementGuid = [guid]'eed9da6e-e6cf-4069-bb0e-74dea8b29bf6'
    $columnName = 'Executive_x003A_ID'
    $brokenGuid = [guid]'af808ae1-5dad-43fe-8d68-b0ec9928b51e'
    $replacementGuid = [guid]'28a830ed-3890-4dee-b56a-b4f13655d45e'
    $columnName = 'Key_x0020_Events_x003A_ID'
    $webUrls = '/teams/ExecComms/Exec1','/teams/ExecComms/LisaBrummel','/teams/ExecComms/SteveBallmer','/teams/ExecComms/TonyBates'

    $webUrls | % {
        $web = $context.site.OpenWeb($_); $context.Load($web); $context.ExecuteQuery();
        $list = $web.Lists.GetByTitle($listname); $context.Load($list); $context.ExecuteQuery();
        $targetfields = $list.Fields.GetById($brokenGuid),$list.Fields.GetById($replacementGuid); $context.Load($targetfields[0]),$context.Load($targetfields[1]); $context.ExecuteQuery();
        if (($targetfields[0].InternalName) -and ($targetfields[1].InternalName)) {
            Write-Verbose "Deleting $($targetfields[0].ID)/$($targetfields[0].InternalName)"
            $targetfields[0].DeleteObject(); $context.ExecuteQuery();
            Write-Verbose "Resetting $($targetfields[1].ID)/$($targetfields[1].InternalName)"
            $xml = [xml]$targetfields[1].SchemaXml
            $xml.Field.Name = $columnName
            $targetfields[1].SchemaXml = $xml.OuterXml
            $targetfields[1].Update(); $context.ExecuteQuery();
        } else {
            Write-Warning "don't have both in $($web.Url)"
        }
    }
}
if ($false) {
$webexec1 = $context.Site.OpenWeb('/teams/ExecComms/Exec1'); $context.Load($webexec1); $context.ExecuteQuery()
#$context.Load($webexec1.Fields); $context.ExecuteQuery();
$webexec1Fields = $context.LoadQuery($webExec1.Fields); $context.ExecuteQuery()
$exec1Events = $webexec1.Lists.GetByTitle('ExecEvents'); $context.Load($exec1events); $context.ExecuteQuery()
$context.Load($exec1events.Fields); $context.ExecuteQuery()
#$exec1events.Fields.Count
#163
$keyfields = $exec1events.Fields.GetEnumerator() | ? { $_.Title -match 'Key Event' }
#$keyfields.Count
#3
$keyfields | select id,InternalName,StaticName
$keyfields[2].SchemaXml = $keyfields[2].SchemaXml -replace '_ID0','_ID'
$keyfields[2].Update(); $context.ExecuteQuery()
$keyfields[2].SchemaXml
}

function global:Fill-CsomToFields(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context
)
{
    $context.Load($context.Web); 
    $context.Load($context.Web.Lists); 
    $context.Load($context.Web.Webs); 
    $context.ExecuteQuery(); # broken out to avoid timeouts and hangups!
    $context.Load($context.Web.Fields);
    $context.ExecuteQuery(); 
}

function global:Fill-Csom(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientObject] $cliobj
)
{
    $cliobj.Context.Load($cliobj); $cliobj.Context.ExecuteQuery()
    $cliobj
}

function global:Repair-CsomFieldLookups(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
    [HashTable]$mapGuids=@{},
    [switch]$useLastStructure=$false,
    [switch]$WhatIf=$WhatIfPreference
)
# Goes over entire site collection looking for broken Lookup fields. Handles LookupList, LookupWebId, LookupField, (PrimaryFieldId)
{
    # load structure, guid->ClientObject, as there isn't an equivalent to AllWebs($guid)
    if (!$useLastStructure -or ($global:structure.Count -eq 0)) {
        $global:structure = @{}
    
        $context.Load($context.Site); $context.Load($context.Site.RootWeb); $context.ExecuteQuery(); 
        #$structure[[GUID]$context.Site.ID] = $context.Site # Site doesn't have a fields collection, leave it out
    
        function StructureRecurse([Parameter(ValueFromPipeline=$true)]$web) {
            Write-Verbose "Structure load of web $($web.Title) <$($web.ServerRelativeUrl)>"
            $context.Load($web.Lists); $context.Load($web.Webs); $context.ExecuteQuery()
            $structure[[GUID]$Web.ID] = $web
            $web.Lists.GetEnumerator() | %{
                $context.Load($_); $context.ExecuteQuery(); 
                $structure[[GUID]$_.ID] = $_
            }
            $web.Webs.GetEnumerator() | %{ $context.Load($_); $context.ExecuteQuery();  StructureRecurse $_ }
        }
        StructureRecurse $context.Site.RootWeb
    }
    Write-Verbose "Structure loaded, beginning verification"
    
    function RepairFieldWeb(
        $fieldWeb,
        $fieldList,
        $field
    )
    {
        $guid = [guid]$field.LookupWebId
        $web = $structure[$guid]
        if ($web -eq $null) {
            Write-Warning "Missing LookupWebId $guid in field $($field.Title)/$($field.Id) of List $($fieldList.Title)/$($fieldList.Id) of Web $($fieldWeb.Url)(/$($fieldWeb.Id))"

        }
        $web
    }

    function RepairFieldList(
        $fieldWeb,
        $fieldList,
        $targetWeb,
        $field
    )
    {
        if ($field.LookupList -eq [string]::Empty) {
            return $null # Docs empty LookupList is a virtual list, ignoring
        } 
        if ($field.LookupList -eq 'AppPrincipals') {
            return $null # Known issue, ignoring #http://blog.hametbenoit.info/Lists/Posts/Post.aspx?ID=446&goback=%2Egde_1869506_member_183986845#%21
        } 
        try { 
             $guid = [guid]$field.LookupList 
             $list = $structure[$guid]
        } catch { 
            $guid = $null;
            try {
                $list = $targetWeb.Lists.GetByTitle($field.LookupList); $context.Load($list); $context.ExecuteQuery() 
            } catch {
                $list = $null 
            }
        }
        if ($list -eq $null) {
            Write-Warning "Missing LookupList $($field.LookupList) in field $($field.Title)/$($field.Id) of List $($fieldList.Title)/$($fieldList.Id) of Web $($fieldWeb.Url)(/$($fieldWeb.Id))"

        }
        $list
    }

    function RepairFieldLookupField(
        $fieldWeb,
        $fieldList,
        $targetWeb,
        $targetList,
        $fields,
        $field
    )
    {
        try { $guid = [guid]$field.LookupField } catch { $guid = $null }
        try {
            if ($guid -eq $null) {
                $targetField = $targetList.Fields.GetByInternalNameOrTitle($field.LookupField); $context.Load($targetField); $context.ExecuteQuery()
            } else {
                $targetField = $targetList.Fields.GetById($guid); $context.Load($targetField); $context.ExecuteQuery()
            }
        } catch {
            $targetField = $null
        }
        if ([string]::IsNullOrEmpty($targetField.SchemaXml)) { #is it loaded yet, there will always be a client object produced, but does it have data?
            Write-Warning "Missing LookupField $($field.LookupField) in field $($field.Title)/$($field.Id) of List $($fieldList.Title)/$($fieldList.Id) of Web $($fieldWeb.Url)(/$($fieldWeb.Id))"

        }
        $list
    }

    function RepairFieldPrimaryFieldId(
        $fieldWeb,
        $fieldList,
        $targetWeb,
        $targetList,
        $fields,
        $field
    )
    {
        try { $guid = [guid]$field.PrimaryFieldId } catch { $guid = $null }
        try {
            if ($guid -eq $null) {
                $targetField = $fieldList.Fields.GetByInternalNameOrTitle($field.PrimaryFieldId); $context.Load($targetField); $context.ExecuteQuery()
            } else {
                $targetField = $fieldList.Fields.GetById($guid); $context.Load($targetField); $context.ExecuteQuery()
            }
        } catch {
            $targetField = $null
        }
        if ([string]::IsNullOrEmpty($targetField.SchemaXml)) { #is it loaded yet, there will always be a client object produced, but does it have data?
            Write-Warning "Missing PrimaryFieldId $($field.PrimaryFieldId) in field $($field.Title)/$($field.Id) of List $($fieldList.Title)/$($fieldList.Id) of Web $($fieldWeb.Url)(/$($fieldWeb.Id))"

        }
        $targetField
    }

    function Repair-Field(
        $fieldParent,
        $fields,
        $field
    )
    {
        if ($field -isnot [Microsoft.SharePoint.Client.FieldLookup]) {
            return
        }
        if ($field -is [Microsoft.SharePoint.Client.FieldUser]) {
            return
        }
        if ($field -is [Microsoft.SharePoint.Client.Taxonomy.TaxonomyField]) {
            return
        }
        if ($fieldParent -is [Microsoft.SharePoint.Client.List]) {
            $fieldWeb = $fieldParent.ParentWeb; $context.Load($fieldWeb); $context.ExecuteQuery()
            $fieldList = $fieldParent
        } else {
            $fieldList = $null
            $fieldWeb = $fieldParent
        }
        Write-Verbose "Field $($field.Title)/$($field.Id) of List $($fieldList.Title)/$($fieldList.Id) of Web $($fieldWeb.Url)(/$($fieldWeb.Id))"
        $web = RepairFieldWeb $fieldWeb $fieldList $field #.LookupWebId
        $list = RepairFieldList $fieldWeb $fieldList $web $field #.LookupList
        if ($list -ne $null) { # BUGBUG: LookupList == 'Docs', 
            $lookupfield = RepairFieldLookupField $fieldWeb $fieldList $web $list $fieldParent.Fields $field #.LookupField
            if (![string]::IsNullOrEmpty($field.PrimaryFieldId)) {
                $primaryField = RepairFieldPrimaryFieldId $fieldWeb $fieldList $web $list $fieldParent.Fields $field #.PrimaryFieldId
            }
        }
    }
    
    $structure.GetEnumerator() | %{
        $id = $_.Key; $obj = $_.Value;
        Write-Verbose "$($obj.Title) <$($obj.Url)> $($obj.Hidden)"
        if (!($obj.Hidden)) {
            $context.Load($obj.Fields); $context.ExecuteQuery()
            $obj.Fields.GetEnumerator() | % { Repair-Field $obj (,$obj.Fields) $_ } # handles both lists and webs, quack!
        }
    }
        
}


function global:Remove-CsomSiteColumnReferences(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [string] 
    # could be Name or GUID
    $columnName,
    [string]
    # regular expression to match list name in order to delete 
    $titleRegularExpression="*"

)
# deletes the field from the lists using it
{
    # handle the difference between name and GUID
    try {
        $guid = [GUID]$columnName
        $scanBlock = { 
            try { 
                $field = $_.Fields.GetById($guid); $context.Load($field); $context.ExecuteQuery();
                $field
            } catch {
                if ($_.ToString() -notmatch 'Invalid field name.') {throw;}
            }
        }
    } catch {
        $scanBlock = { 
            try { 
                $field = $_.Fields.GetByInternalNameOrTitle($columnName); $context.Load($field); $context.ExecuteQuery();
                $field
            } catch {
                if ($_.ToString() -notmatch 'does not exist.') {throw;}
            }
        }
   }

    # CSOM doesn't include AllWebs, so we'll need to walk the tree....
    function RecurseWebs(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
    [Microsoft.SharePoint.Client.Web] $web
    )
    {
        $context.Load($web.Lists); $context.ExecuteQuery();
        $web.Lists | % {
            $list = $_;
            $context.Load($list); $context.ExecuteQuery();
            $context.Load($list.Fields); $context.ExecuteQuery();
            $field = (. $scanBlock)
            if ($field -ne $null) {
                New-Object PSObject -Property @{FieldId=$field.Id; ListId=$list.Id; WebId=$web.Id; ListUrl="$($web.ServerRelativeUrl)##$($list.Title)"} 
                if ($list.Title -match $titleRegularExpression) {
                    Write-Warning "deleting: $($web.ServerRelativeUrl)##$($list.Title)"
                    $field.DeleteObject(); $context.ExecuteQuery(); 
                }
            }
        }
        $context.Load($web.Webs); $context.ExecuteQuery();
        $web.Webs.GetEnumerator() | % {
            RecurseWebs $context $_
        }
    }

    $context.Load($context.Site); $context.ExecuteQuery();
    $web = $context.Site.RootWeb; $context.Load($web); $context.ExecuteQuery();
    RecurseWebs $context $web
}

# Remove-CsomSiteColumnReferences $context 'a4e7b3e1-1b0a-4ffa-8426-c94d4cb8cc57' -titleRegularExpression 'Events$' |fl

function global:Reset-FieldDefault (
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
	[Parameter(Mandatory=$true)]
	[string] $webServerRelativeUrl,
	[Parameter(Mandatory=$true)]
	[string] $listTitle,
	[Parameter(Mandatory=$true)]
	[string] $fieldName,
	[Parameter(Mandatory=$true)]
	[string] $defaultValue,
	[switch] $hideEdit=$false,
	[switch] $hideNew=$false,
	[switch] $hideView=$false,
	[switch] $showEdit=$false,
	[switch] $showNew=$false,
	[switch] $showView=$false
)
{
    $context.Load($context.Site); $context.ExecuteQuery();
    $web = $context.Site.OpenWeb($webServerRelativeUrl); $context.Load($web); $context.ExecuteQuery();
    $list = $web.Lists.GetByTitle($listTitle); $context.Load($list); $context.ExecuteQuery();
    try {
        $guid = [guid]$fieldName
        $field = $list.Fields.GetById($guid);
    } catch {
        $field = $list.Fields.GetByInternalNameOrTitle($fieldName)
    }   
    $context.Load($field); $context.ExecuteQuery();
    $field.DefaultValue = $defaultValue;
    if ($hideEdit) { $field.SetShowInEditForm($false) }
    if ($hideNew)  { $field.SetShowInNewForm($false) }
    if ($hideView) { $field.SetShowInDisplayForm($false) }
    if ($showEdit) { $field.SetShowInEditForm($true) }
    if ($showNew)  { $field.SetShowInNewForm($true) }
    if ($showView) { $field.SetShowInDisplayForm($true) }
    $field.Update(); $context.ExecuteQuery()
}

if ($false) {

    $cq = new-object Microsoft.SharePoint.Client.CamlQuery
    $cq.ViewXml = '<View><Query><Where>' +
			'<Neq><FieldRef Name="ID"/><Value Type="Counter">0</Value></Neq>' +
			'</Where>' + 
			'<OrderBy><FieldRef Name="ID" Ascending="TRUE"/></OrderBy>' + 
			'</Query>' + 
			'<RowLimit>100</RowLimit>' +
            '</View>'
    $executives = $context.Web.Lists.GetByTitle('Executives') ; $context.Load($executives); $context.ExecuteQuery()
    $execItems = $executives.GetItems($cq); $context.Load($execItems); $context.ExecuteQuery()
    $execItems.GetEnumerator() | % { $id = $_["ID"]; $name = $_["FullName"]; "$id;#$name" }
    
    $divisions = $context.Web.Lists.GetByTitle('Divisions') ; $context.Load($divisions); $context.ExecuteQuery()
    $divItems = $divisions.GetItems($cq); $context.Load($divItems); $context.ExecuteQuery()
    $divItems.GetEnumerator() | % { $id = $_["ID"]; $name = $_["Title"]; "$id;#$name" }

    @{Url='/teams/ExecComms/SteveBallmer';Executive='1;#Steve Ballmer';Division='1;#Chief Executive Officer'},
    @{Url='/teams/ExecComms/TonyBates';;Executive='2;#Tony Bates';Division='5;#Business Development & Evangelism'},
    @{Url='/teams/ExecComms/LisaBrummel';;Executive='3;#Lisa Brummel';Division='9;#Human Resources'},
    @{Url='/teams/ExecComms/QiLu';;Executive='4;#Qi Lu';Division='4;#Applications and Services'},
    @{Url='/teams/ExecComms/TerryMyerson';;Executive='6;#Terry Myerson';Division='13;#Operating Systems'},
    @{Url='/teams/ExecComms/SatyaNadella';;Executive='7;#Satya Nadella';Division='6;#Cloud & Expertise'},
    @{Url='/teams/ExecComms/BradSmith';;Executive='8;#Brad Smith';Division='10;#Legal & Corporate Affairs'},
    @{Url='/teams/ExecComms/KirillTatarinov';;Executive='9;#Kirill Tatarinov';Division='12;#Microsoft Business Solutions'},
    @{Url='/teams/ExecComms/KevinTurner';;Executive='10;#Kevin Turner';Division='14;#Sales, Marketing & Services Group'},
    @{Url='/teams/ExecComms/JudsonAlthoff';;Executive='11;#Judson Althoff';Division='14;#Sales, Marketing & Services Group'},
    @{Url='/teams/ExecComms/JeanPhilippeCourtois';;Executive='12;#Jean-Philippe Courtois';Division='14;#Sales, Marketing & Services Group'},
    @{Url='/teams/ExecComms/AmyHood';;Executive='13;#Amy Hood';Division='8;#Finance'},
    @{Url='/teams/ExecComms/JulieLarsonGreen';;Executive='14;#Julie Larson;#Green';Division='7;#Devices & Studios'},
    @{Url='/teams/ExecComms/MarkPenn';;Executive='15;#Mark Penn';Division='3;#Advertising & Strategy'},
    @{Url='/teams/ExecComms/TamiReller';;Executive='16;#Tami Reller';Division='11;#Marketing'},
    @{Url='/teams/ExecComms/EricRudder';;Executive='17;#Eric Rudder';Division='2;#Advanced Strategy & Research'},
    @{Url='/teams/ExecComms/ThomGruhler';;Executive='19;#Thom Gruhler ';Division='11;#Marketing'},
    @{Url='/teams/ExecComms/ChrisCapossela';;Executive='30;#Chris Capossela';Division='14;#Sales, Marketing & Services Group'} | % {
        Reset-FieldDefault $context $_["Url"] "ExecEvents" "Executive" $_["Executive"] -hideEdit -hideNew
        Reset-FieldDefault $context $_["Url"] "ExecEvents" "Division" $_["Division"] -hideEdit -hideNew
    }
}

function global:Get-CsomSiteAllWebsAndLists(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
    [switch]$includeWebs=$true,
    [switch]$includeLists=$true
)
# return HashTable keyed by [GUID] valued by .Web and .List objects. Either type may be filtered out.
{
    $structure = @{}
    
    $context.Load($context.Site); $context.Load($context.Site.RootWeb); $context.ExecuteQuery(); 
    #$structure[[GUID]$context.Site.ID] = $context.Site # Site doesn't have a fields collection, leave it out
    
    function StructureRecurse([Parameter(ValueFromPipeline=$true)]$web) {
        Write-Verbose "Structure load of web $($web.Title) <$($web.ServerRelativeUrl)>"
        $context.Load($web.Lists); $context.Load($web.Webs); $context.ExecuteQuery()
        if ($includeWebs) { $structure[[GUID]$Web.ID] = $web }
        if ($includeLists) {
            $web.Lists.GetEnumerator() | %{
                $context.Load($_); $context.ExecuteQuery(); 
                $structure[[GUID]$_.ID] = $_
            }
        }
        $web.Webs.GetEnumerator() | %{ $context.Load($_); $context.ExecuteQuery();  StructureRecurse $_ }
    }
    StructureRecurse $context.Site.RootWeb
    $structure
}

# (Get-CsomSiteAllWebsAndLists $context -includeLists:$false).GetEnumerator() | ? { $_.Key -ne $context.Site.RootWeb.Id} | %{ $w = $_.Value; $W.Title; $W.Navigation.UseShared = $true; $w.Update(); $context.ExecuteQuery() }


function global:Upload-CsomFile(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
    [string]
    # path of source file
    $source,
    [string]
    # server-relative URL for new file
    $destination,
    [switch]$overwrite=$false
)
{
    $filestr = [System.IO.File]::OpenRead($source);
    [Microsoft.SharePoint.Client.File]::SaveBinaryDirect($context, $destination, $filestr, $overwrite);
}
# Upload-CsomFile $context "$pwd\.gitignore" '/sites/ExecComms/gitignore.txt' -overwrite


function global:Download-CsomFile(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
    [string]
    # server-relative URL of source 'file'
    $source, 
    [string]
    # path to destination file
    $destination
)
{
    $fileInfo = [Microsoft.SharePoint.Client.File]::OpenBinaryDirect($context, $source);
    try {
        $fileStream = [System.IO.File]::Create($destination)
        $fileInfo.Stream.CopyTo($fileStream);
    } finally {
        $fileStream.Close();
        $fileStream.Dispose();
        $fileInfo.Dispose();
    }
}
# Download-CsomFile $context '/sites/ExecComms/default.aspx' "$pwd\default.aspx"
# Download-CsomFile $ctx /teams/ExecComms/AmyHood/Lists/ExecEvents/NewFormAddNewExecEvent.aspx "$pwd\NewFormAddNewExecEvent.aspx"
# Download-CsomFile $context /sites/ExecComms/Exec1/Lists/ExecEvents/NewForm.aspx "$pwd\NewForm.aspx"

function global:-CsomStream(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
    [System.IO.Stream]
    # source stream (.CanRead -eq $true)
    $source,
    [string]
    # server-relative URL for new file
    $destination,
    [switch]$overwrite=$false
)
{
    [Microsoft.SharePoint.Client.File]::SaveBinaryDirect($context, $destination, $source, $overwrite);
}
# Upload-CsomStream $memoryStream '/sites/ExecComms/Home.aspx'

function global:Download-CsomStream(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
    [string]
    # server-relative URL of source 'file'
    $source)
{
    $fileInfo = [Microsoft.SharePoint.Client.File]::OpenBinaryDirect($context, $source);
    return $fileInfo.Stream
}
# $networkStream = Download-CsomStream $context '/sites/ExecComms/default.aspx'; $memoryStream = new-object System.IO.MemoryStream; $networkStream.CopyTo($memoryStream); $networkStream.Close(); $memoryStream.Seek(0, [System.IO.SeekOrigin]::Begin); $sr = new-object System.IO.StreamReader ($memoryStream, [System.Text.Encoding]::UTF8); $sr.ReadToEnd()

function global:Get-CsomContent(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] $context,
    [string]
    # server-relative URL of source 'file'
    $source,
    [System.Text.Encoding]
    $encoding=[System.Text.Encoding]::UTF8
)
{
    $networkStream = Download-CsomStream $context $source; 
    #$memoryStream = new-object System.IO.MemoryStream; 
    #$networkStream.CopyTo($memoryStream); 
    #$networkStream.Close(); 
    #$memoryStream.Seek(0, [System.IO.SeekOrigin]::Begin); 
    #$sr = new-object System.IO.StreamReader ($memoryStream, $encoding);
    $sr = new-object System.IO.StreamReader ($networkStream, $encoding);
    $sr.ReadToEnd()
    $sr.Close() # also closes constructor-passed stream
}
# Get-CsomContent $context '/sites/ExecComms/default.aspx'

function global:Verify-CsomField(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.List] $list,
	[Parameter(Mandatory=$true)]
    [string]
    # internal name of field
    $fieldName,
	[Parameter(Mandatory=$true)]
    [string]
    # Type of field
    $fieldType,
	[HashTable]
	# hashtable of additional field properties
	$fieldProps = @{},
	[Microsoft.SharePoint.Client.AddFieldOptions]
	# field add options, [Microsoft.SharePoint.AddFieldOptions]::AddFieldToDefaultView etc.
	$fieldOptions = [Microsoft.SharePoint.Client.AddFieldOptions]::DefaultValue
)
{
	$context = $list.Context
	$field = $null
	try {
		Write-Verbose "Verifying list $($list.Title) has field $fieldName"
		$field = $list.Fields.GetByInternalNameOrTitle($fieldName)
		$context.Load($field); $context.ExecuteQuery()
		# BUGBUG: verify field data against fieldProps and field options against fieldOptions
	} catch {
		Write-Verbose "Creating in list $($list.Title) field $fieldName"
		$xml = [xml]"<Field />"
		$root = $xml.DocumentElement
		$root.SetAttribute("InternalName", $fieldName)
		$root.SetAttribute("Type", $fieldType)
		if (!$fieldProps.Contains("DisplayName")) { $fieldProps["DisplayName"]=$fieldName }
		$fieldProps.GetEnumerator() | % { if ($_ -ne $null) { Write-Debug $_ ; $root.SetAttribute($_.Key, $_.Value) } }
		# BUGBUG: child elements!
		if (!$PSCmdlet.ShouldProcess("list $($list.Title) field $fieldName", "Creating field")) {
			Write-Warning  "WhatIf: would have created field $($fieldName) on $($list.Title)"
		} else {
			$field = $list.Fields.AddFieldAsXml($root.OuterXml, $fieldOptions -band [Microsoft.SharePoint.Client.AddFieldOptions]::AddFieldToDefaultView, $fieldOptions) 
			$list.Update()
			$context.ExecuteQuery()
		}
	}
	$field
}
# Verify-CsomField $list Processed DateTime @{"ShowInNewForm"="FALSE";"ShowInEditForm"="FALSE"} -Verbose -Debug

function global:Verify-CsomList(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.ClientContext] 
	# Context/web to create list in
	$context,
	[Parameter(Mandatory=$true)]
    [string]
    # Title of List
    $ListName,
    [int]
    # Type of List (default [Microsoft.SharePoint.Client.ListTemplateType]::GenericList, see also Web.ListTemplates..ListTemplateTypeKind, however one can't CSOM create from a gallery custom template i.e. Site.GetCustomListTemplates($ctx.Web).)
    $TemplateType=$([int][Microsoft.SharePoint.Client.ListTemplateType]::GenericList),
	[HashTable]
	# hashtable of additional List properties (cf. ListCreationInformation properties)
	$ListProps = @{}
	)
{
	$list = $null
	try {
		Write-Verbose "Verifying List $ListName"
		$List = $context.Web.Lists.GetByTitle($ListName)
		$context.Load($List); $context.ExecuteQuery()
		# BUGBUG: verify List data against ListProps
	} catch {
		Write-Verbose "Creating List $ListName"
		$lci = New-Object Microsoft.SharePoint.Client.ListCreationInformation
		# Go over $ListProps first to prevent override of .Title or .TemplateType
		$ListProps.GetEnumerator() | % {
			if ($_ -ne $null) { Write-Debug $_.Key ; $lci."$($_.Key)" = $_.Value }
		}
		$lci.Title = $ListName 
		$lci.TemplateType = $TemplateType 
		if (!$PSCmdlet.ShouldProcess($ListName, "Create List")) {
			Write-Warning  "WhatIf: would have created List $($ListName)"
		} else {
			$List = $context.Web.Lists.Add($lci) 
			$list.Update()
			$context.ExecuteQuery()
		}
	}
	$list
}
# Verify-CsomList $context Generic -ListProps @{Description="Generic list by validation check"} -Verbose -Debug

function global:Get-CsomUserById(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.Web] $web,
	[Parameter(Mandatory=$true)]
    [int]$lookupId
)
# gets .Client.User from web based on lookupId
{
    $user = $web.GetUserById($lookupId)
    $context.Load($user); $context.ExecuteQuery()
    return $user
}
# "`"$((Get-CsomUserById $context.Web $_['group_2'].LookupId).LoginName)`""

function global:ForEach-CsomListItem(
	[Parameter(Mandatory=$true)]
	[Microsoft.SharePoint.Client.List] $list,
    [ScriptBlock]
	# statement block to be executed for each list item, passed in as $_
	$process={$val = New-Object PSObject; $li = $_; "ID","Title" | % { add-member -inputObject $val NoteProperty "$_" $li["$_"] -force }; $val},
    [ScriptBlock]
	# statement block to be executed prior to individual list items
	$begin={},
    [ScriptBlock]
	# statement block to be executed after all individual list items
	$end={},
    [string]
	# ViewXml (CAML Query)
	$viewXml="<View><Query><Where><IsNotNull><FieldRef Name='ID'/></IsNotNull></Where></Query></View>"
)
# executes $block over each item returned from the query in $viewXml on $list 
{
	. $begin
	$query = New-Object Microsoft.SharePoint.Client.CamlQuery
	$query.ViewXml = $viewXml
	$items = $list.GetItems($query)
	$list.Context.Load($items); $list.Context.ExecuteQuery();

	Write-Debug "query returned $($items.Count)"
	$items.GetEnumerator() | % $process 
	. $end
}
# ForEach-CsomListItem -list (Get-CsomListByTitle $context "XhubSiteRequestForm")
# ForEach-CsomListItem -list (Get-CsomListByTitle $context "XhubSiteRequestForm") -viewXml "<View><Query><Where><IsNotNull><FieldRef Name='ID'/></IsNotNull></Where></Query><ViewFields><FieldRef Name='ID'/><FieldRef Name='Title'/></ViewFields></View>",





