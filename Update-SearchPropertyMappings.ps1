param (
	[string] 
	# search application to deal with
	$searchApplication='Search Service Application'
	)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)

# data from http://technet.microsoft.com/en-us/library/ee890108.aspx (Windows PowerShell for SharePoint Server 2010 reference)
$ssa = Get-SPEnterpriseSearchServiceApplication $searchApplication -ea Stop

# http://www.sharepointstudio.com/Blog/Lists/Posts/Post.aspx?ID=38
$MPTypeMap = New-Object 'System.Collections.Generic.Dictionary[string,int]'
$MPTypeMap.Add("Text",1)
$MPTypeMap.Add("Integer?",2)
$MPTypeMap.Add("Decimal?",3)
$MPTypeMap.Add("DateTime?",4)
$MPTypeMap.Add("YesNo?",5)
$MPTypeMap.Add("Binary",6)

# <http://www.dotnetmafia.com/blogs/dotnettipoftheday/archive/2010/05/26/creating-enterprise-search-metadata-property-mappings-with-powershell.aspx> <http://msdn.microsoft.com/en-us/library/cc237865.aspx>
$CPTypeMap = New-Object 'System.Collections.Generic.Dictionary[string,int]'
$CPTypeMap.Add("Text",0x1f)
$CPTypeMap.Add("Integer?",0x13)
$CPTypeMap.Add("Decimal?",0x05)
$CPTypeMap.Add("DateTime?",0x40)
$CPTypeMap.Add("YesNo?",0x0b)
$CPTypeMap.Add("Binary",0x41) #4108 #65

$PeoplePropset = New-Object Guid '00110329-0000-0110-c000-000000111146'
$SharePointPropset = New-Object Guid '00130329-0000-0130-c000-000000131346'
$SharePointPortalPropset = New-Object Guid '00140329-0000-0140-c000-000000141446'

function VerifyCrawledProperty($name, $variantType=$CPTypeMap["Text"], 
		$category='SharePoint', $isNameEnum=$false, $propset=$SharePointPropset, 
		$isMappedToContents=$true) {
	$prop = Get-SPEnterpriseSearchMetadataCrawledProperty -SearchApplication $ssa -name $name -ea SilentlyContinue
	if ($null -eq $prop) {
		$prop = New-SPEnterpriseSearchMetadataCrawledProperty -Category $category -IsNameEnum $isNameEnum -Name $name -PropSet $propset -SearchApplication $ssa -VariantType $variantType -IsMappedToContents $isMappedToContents -ea Stop
	}
	# BUGBUG: not checking for proper types yet
	return $prop
}

function VerifyManagedProperty($name, $type=$MPTypeMap["Text"], 
		$enabledForScoping=$True, $fullTextQueryable=$True) {
	$prop = Get-SPEnterpriseSearchMetadataManagedProperty -Identity $name -SearchApplication $ssa -ea SilentlyContinue
	if ($null -eq $prop) {
		$prop = New-SPEnterpriseSearchMetadataManagedProperty -Name $name -SearchApplication $ssa -Type $type -EnabledForScoping $enabledForScoping -FullTextQueriable $fullTextQueriable -ea Stop
 	}
	# BUGBUG: not checking for proper types yet
	return $prop
}

function VerifyPropertyMapping($managedProperty, $crawledProperty) {
	$prop = Get-SPEnterpriseSearchMetadataMapping -ManagedProperty $managedProperty -CrawledProperty $crawledProperty -SearchApplication $ssa -ea SilentlyContinue
	if ($null -eq $prop) {
		$prop = New-SPEnterpriseSearchMetadataMapping -ManagedProperty $managedProperty -CrawledProperty $crawledProperty -SearchApplication $ssa -ea Stop
 	}
	# BUGBUG: not checking for proper types yet
	return $prop
}



function VerifyCrawlExtension($extension) {
	try { 
		Get-SPEnterpriseSearchCrawlExtension -Identity $extension -SearchApplication $ssa -ea Stop
	} catch {
		New-SPEnterpriseSearchCrawlExtension -Name $extension -SearchApplication $ssa -ea Stop
		write-warning "$extension added to search crawls; remember to 'Reset Index' and IISRESET before the full crawl to pick those up"
	}
}
#VerifyCrawlExtension '.jpeg'
#VerifyCrawlExtension '.jpg'
#VerifyCrawlExtension '.gif'
#VerifyCrawlExtension '.png'


function VerifyCrawlRule($path, $type) {
	try {
		Get-SPEnterpriseSearchCrawlRule -Identity $path -SearchApplication $ssa -ea Stop
	} catch {
		New-SPEnterpriseSearchCrawlRule -Path $path -SearchApplication $ssa -Type $type -ea Stop
	}
}
#VerifyCrawlRule 'http://*.aspx' 'ExclusionRule'

VerifyPropertyMapping (VerifyManagedProperty 'Name' ) (VerifyCrawledProperty 'urn:schemas-microsoft-com:sharepoint:portal:profile:PreferredName' -category 'People' -propset $PeoplePropset)
VerifyPropertyMapping (VerifyManagedProperty 'Manager' ) (VerifyCrawledProperty 'urn:schemas-microsoft-com:sharepoint:portal:profile:Manager' -category 'People' -propset $PeoplePropset)
VerifyPropertyMapping (VerifyManagedProperty 'Picture' ) (VerifyCrawledProperty 'urn:schemas-microsoft-com:sharepoint:portal:profile:PictureURL' -category 'People' -propset $PeoplePropset)

##New-SPEnterpriseSearchMetadataCrawledProperty -Category 'SharePoint' -IsNameEnum $false -Name 'ows_Brand' -PropSet '00130329-0000-0130-c000-000000131346' -SearchApplication $searchApplication -VariantType 31 -IsMappedToContents $True
##New-SPEnterpriseSearchMetadataManagedProperty -Name 'BTBrand' -SearchApplication $searchApplication -Type 1 -EnabledForScoping $True -FullTextQueriable $true 
#New-SPEnterpriseSearchMetadataMapping -SearchApplication $ssa -CrawledProperty (VerifyCrawledProperty 'ows_Brand') -ManagedProperty (VerifyManagedProperty 'BTBrand') 

#$assetsScope = New-SPEnterpriseSearchQueryScope Assets -Description 'Brand Tools scoping to Asset table' -DisplayInAdminUI $True -SearchApplication $searchApplication -CompilationType 1 
#New-SPEnterpriseSearchQueryScopeRule -RuleType Url -url "http://$([Environment]::MachineName)/BrandTools1" -Scope $assetsScope -FilterBehavior 'Include' -ManagedProperty 'BTBrand' -MatchingString "http://$([Environment]::MachineName)/BrandTools1/Asset" -UrlScopeRuleType 'Folder'
#New-SPEnterpriseSearchQueryScopeRule -RuleType Url -url "http://$([Environment]::MachineName)/BrandTools1/PhysicalAsset" -Scope $assetsScope -FilterBehavior 'Include' -ManagedProperty 'BTBrand' -MatchingString "http://$([Environment]::MachineName)/BrandTools1/PhysicalAsset" -UrlScopeRuleType 'Folder'

#$QAScope = New-SPEnterpriseSearchQueryScope QA -Description 'Brand Tools scoping to QAData' -DisplayInAdminUI $True -SearchApplication $searchApplication -AlternateResultsPage "http://$([Environment]::MachineName)/BrandTools1/SitePages/QASearchResults.aspx" -CompilationType 1 
#New-SPEnterpriseSearchQueryScopeRule -RuleType Url -url "http://$([Environment]::MachineName)/BrandTools1/Lists/QAData" -Scope $QAScope -FilterBehavior 'Include' -MatchingString "http://$([Environment]::MachineName)/BrandTools1/Lists/QAData" -UrlScopeRuleType 'Folder'



<#
.SYNOPSIS
	Updates search property mappings
.DESCRIPTION
	Verifies the existance of the search crawled properties and the managed 
	properties then verifies that the minimal mappings are in place
	
	BUGBUG: must be edited for each project
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	the Microsoft.Office.Server.Search.Administration.Mapping's being verified
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
#>
