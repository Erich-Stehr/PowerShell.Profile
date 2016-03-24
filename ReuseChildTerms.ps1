param (
	[string] 
	# path of parent termset/term holding the children to be copied "termset;term[;term...]"
	$sourceTermPath=$(throw "Requires source term path"),
	[string] 
	# path of parent termset/term the children are being reused to
	$destinationTermPath=$(throw "Requires destination term path to hold children"),
	[string] 
	# (local) site url to work with
	$siteUrl=$(throw "Requires (local) site URL to work with"),
	[object] 
	# term store to work with (default is [TaxonomySession]::DefaultSiteCollectionTermStore)
	$termStore=$null,
	[switch] 
	# reuse the entire branch ($true) or just the child term ($false, default)
	$reuseBranch=$false,
	[switch] 
	# prevents commit of changes
	$nocommit=$false
	)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
if (![System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Taxonomy")) {
	trap { break; }
	throw "Can't load Microsoft.SharePoint.Taxonomy!" 
}

$site = Get-SPSite $siteUrl
$script:DebugPreference = [System.Management.Automation.ActionPreference]::Continue
$termSeparator = [Microsoft.SharePoint.Taxonomy.TaxonomyField]::TaxonomyMultipleTermDelimiter
$taxoSession = New-Object "Microsoft.SharePoint.Taxonomy.TaxonomySession" $site
if ($null -eq $termStore) {
	$termStore = $taxoSession.DefaultSiteCollectionTermStore
} elseif ($termStore -isnot [Microsoft.SharePoint.Taxonomy.TermStore]) {
	trap { break;}
	$termStore = $taxoSession.TermStores[$termStore]
}

function ConvertTo-TermSetItem([string] $path)
{
	$fragments = $path.Split($termSeparator, [StringSplitOptions]::RemoveEmptyEntries)
	
	$termset = $taxoSession.GetTermSets($fragments[0], $termStore.DefaultLanguage)
	$term = $termset
	for ($i = 1; $i -lt $fragments.Count; ++$i) {
		$newTerm = $null
		try { $newTerm = $term.Terms[$fragments[$i]] } 
		catch { throw "Missing term name $($termset.Name)$termSeparator$($term.GetPath())$termSeparator$($fragments[$i]) : $_" }
		$term = $newTerm
	}
	$term
}

$source = ConvertTo-TermSetItem $sourceTermPath
$dest = ConvertTo-TermSetItem $destinationTermPath
$errorFlag = $false
$source.Terms | %{ 
	$thisTerm = $_
	try {
		$dest.ReuseTerm($thisTerm, $reuseBranch) 
	} catch {
		$errorFlag = $true
		throw "Unable to reuse $(thisTerm.Name): $_"; continue;
	}
}

if (!$nocommit -and !$errorFlag) {
	$dest.TermStore.CommitAll()
}
<#
.SYNOPSIS
	set up reused terms from a given TermSetItem's child Term's
.DESCRIPTION
	x
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	the reused Term's
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	ReuseChildTerms.ps1 "MarketingPortal" "Brands" http://erichstehr/sites/alphatesting -nocommit
#>
