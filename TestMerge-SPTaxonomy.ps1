param (
	[string] 
	# (local) site url to work with
	$siteUrl="http://erichstehr/sites/development",
	[string] 
	# name of termset to create/merge within TestMerge group
	$termSetName="MergeTest",
	[switch] 
	# remove the to-be-generated termset before starting 
	$purgeTermset=$false
)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
if (![System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Taxonomy")) {
        trap { break; }
        throw "Can't load Microsoft.SharePoint.Taxonomy!"
}

$site = Get-SPSite $siteUrl

$script:DebugPreference = [System.Management.Automation.ActionPreference]::Continue

$taxoSession = New-Object "Microsoft.SharePoint.Taxonomy.TaxonomySession" $site
$termStore = $taxoSession.DefaultSiteCollectionTermStore
# Since TermStore is a service application, other non-defaults are doubtful
$lcid = $termStore.DefaultLanguage
$group = $termStore.Groups["Testing"]
if ($group -eq $null) {
	Write-Debug "Creating group Testing"
	$group = $termStore.CreateGroup("Testing")
	$group.AddGroupManager("$([Environment]::UserDomainName)\$([Environment]::UserName)")
}
if ($purgeTermset) {
	$termSet = $group.TermSets[$termSetName]
	if ($null -ne $termSet) {
		Write-Debug "Deleting termset $termSetName"
		$termSet.Delete()
		$termStore.CommitAll()
	}
} 
$termSet = $group.TermSets[$termSetName]
if ($null -eq $termSet) {
	Write-Debug "Creating termset $termSetName"
	$termSet = $group.CreateTermSet($termSetName)
	$termStore.CommitAll()
}

$samples =
(New-Object PSObject -Property @{ ITEM_TYPE="4 PACK"; BRAND="ALVAREZ"; MODEL_GROUP="REGENT"; MODEL="RD8"; Synonyms="RD8A, RD8-A" }),
(New-Object PSObject -Property @{ ITEM_TYPE="DREADNOUGHT ACOUSTIC"; BRAND="ALVAREZ"; MODEL_GROUP="REGENT"; MODEL="RD8" }),
(New-Object PSObject -Property @{ ITEM_TYPE="DREADNOUGHT ACOUSTIC ELECTRIC"; BRAND="ALVAREZ"; MODEL_GROUP="REGENT"; MODEL="RD8" }),
(New-Object PSObject -Property @{ ITEM_TYPE="GC PROPRIETARY"; BRAND="CRATE"; MODEL_GROUP="PALOMINO"; MODEL="V8" }),
(New-Object PSObject -Property @{ ITEM_TYPE="ACCESSORIES"; BRAND="MACKIE INDUSTRIAL"; MODEL_GROUP="ACCESSORIES"; MODEL="ART 12`" GRILL" })

# From comment to http://rkeithhill.wordpress.com/2010/09/19/determining-scriptdir-safely/
function ScriptRoot { Split-Path $MyInvocation.ScriptName }

$samples[1] | . "$(ScriptRoot)\Merge-SPTaxonomy.ps1" $siteUrl -termSet $termSetName -nocommit -property ITEM_TYPE
if ($termset.GetAllTerms().Count -ne 1)
{
	trap { break; }
	throw "Incorrect `$termset.GetAllTerms().Count=$($termset.GetAllTerms().Count) instead of 1"
}

$samples[1] | . "$(ScriptRoot)\Merge-SPTaxonomy.ps1" $siteUrl -termSet $termSetName -nocommit -property ITEM_TYPE,BRAND -itemproperty $null
if ($termset.GetAllTerms().Count -ne 2)
{
	trap { break; }
	throw "Incorrect `$termset.GetAllTerms().Count=$($termset.GetAllTerms().Count) instead of 2"
}

$samples | . "$(ScriptRoot)\Merge-SPTaxonomy.ps1" $siteUrl -termSet $termSetName -nocommit -pass
if ($termset.GetAllTerms().Count -ne 9)
{
	trap { break; }
	throw "Incorrect `$termset.GetAllTerms().Count=$($termset.GetAllTerms().Count) instead of 9"
}
if ($termSet.Terms["ALVAREZ"].Terms["REGENT"].Terms["RD8"].CustomProperties.Count -ne 3) {
	trap { break; }
	throw "Alvarez Regent RD8 CustomProperties has only $($termSet.Terms["ALVAREZ"].Terms["REGENT"].Terms["RD8"].CustomProperties.Count) instead of 3"
}
if ($termSet.Terms["ALVAREZ"].Terms["REGENT"].Terms["RD8"].Labels.Count -ne 3) {
	trap { break; }
	throw "Alvarez Regent RD8 Labels has $($termSet.Terms["ALVAREZ"].Terms["REGENT"].Terms["RD8"].Labels.Count) instead of 3"
}
if ($termSet.Terms["ALVAREZ"].Terms["REGENT"].Labels.Count -ne 1) {
	trap { break; }
	throw "Alvarez Regent Labels has $($termSet.Terms["ALVAREZ"].Terms["REGENT"].Labels.Count) instead of 1"
}

#skip first sample, verify first sample is marked obsolete
$i = 0 ; $samples | ? { $i++ -ne 3 } | . "$(ScriptRoot)\Merge-SPTaxonomy.ps1" $siteUrl -termSet $termSetName -nocommit -pass -DeprecateMissing -reuseTest
if ($null -eq $termSet.Terms["CRATE"]) {
	trap { break; }
	throw "`"CRATE`" doesn't exist"
}
if (!$termSet.Terms["CRATE"].IsDeprecated) {
	trap { break; }
	throw "`"CRATE`" wasn't deprecated"
}
if (!$termSet.Terms["CRATE"].Terms["PALOMINO"].IsDeprecated) {
	trap { break; }
	throw "`"CRATE`".`"PALOMINO`" wasn't deprecated"
}
if (!$termSet.Terms["CRATE"].Terms["PALOMINO"].Terms["V8"].IsDeprecated) {
	trap { break; }
	throw "`"CRATE`".`"PALOMINO`".`"V8`" wasn't deprecated"
}
if ($termSet.Terms["ALVAREZ"].IsDeprecated) {
	trap { break; }
	throw "`"ALVAREZ`" was deprecated"
}

<#
.SYNOPSIS
	Provides testing for Merge-SPTaxonomy.ps1
.DESCRIPTION

.INPUTS
	does not accept pipeline
.OUTPUTS
	status objects
.COMPONENT	
	Microsoft.SharePoint.PowerShell
	Microsoft.SharePoint.Taxonomy
.EXAMPLE
#>
