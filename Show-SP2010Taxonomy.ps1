param (
	[string] 
	# (local) site url to work with
	$siteUrl=$(throw "Requires (local) site URL to work with"),
	[object] 
	# term store to work with (default is [TaxonomySession]::DefaultSiteCollectionTermStore)
	$termStoreName=$null,
	[object[]] 
	# group(s) to work with within term store (default is all)
	$groupNames=$null,
	[object[]] 
	# termset(s) to work with within group(s) (default is all)
	$termSetNames=$null,
	[object[]] 
	# term(s) to work with within termset(s) (default is all)
	$termNames=$null
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
if ($VerifyTermStores) {
	$defaultTermStore = $taxoSession.DefaultKeywordsTermStore
	if ($null -eq $defaultTermStore) {
		trap { continue; }
		throw "No default keywords term store configured/accessible!" 
	}
	$defaultTermStore
	$defaultSiteTermStore = $taxoSession.DefaultSiteCollectionTermStore
	if ($null -eq $defaultSiteTermStore) {
		trap { continue; }
		throw "No default site keywords term store configured/accessible!" 
	}
	$defaultSiteTermStore
}

$termStore = $taxoSession.DefaultSiteCollectionTermStore
if (![string]::IsNullOrEmpty($termStoreName)) {
	$termStore = $taxoSession.TermStores[$termStoreName]
}
Write-Debug "Termstore $($termStore.Id) $($termStore.Name)"

$groups = @()
if ([string]::IsNullOrEmpty($groupNames)) {
	$groups = @($termStore.Groups)
} else {
	$groups = @($groupNames | %{ $termStore.Groups[$_] } | ? { $_ -ne $null })
}
if ($groups -eq $null) { $groups = @() }
$groups | %{ Write-Debug "Group $($_.Id) $($_.TermStore.Name):$($_.Name)" }

$termsets = @()
if ([string]::IsNullOrEmpty($termSetNames)) {
	$termsets = @($groups | % { $_.TermSets })
} else {
	$termsets = @($groups | 
		% { 
			ForEach ($ts in $termSetNames) { 
				try { 
					$_.TermSets[$ts] 
				} catch {
					# on failure, ignore; we didn't want it anyway
				} 
			} 
		} |
		? { $_ -ne $null }
		)
}
if ($termsets -eq $null) { $termsets = @() }
$termsets | %{ Write-Debug "TermSet $($_.Id) $($_.TermStore.Name):$($_.Group.Name):$($_.Name)" }

function ShowTermFullName([Microsoft.SharePoint.Taxonomy.Term] $term) {
	$segments = New-Object 'System.Collections.Generic.List[string]'
	$t = $term
	while ($t -ne $null) {
		$segments.Add($t.Name)
		$t = $t.Parent
	}
	$segments.Add($term.TermSet.Name)
	$segments.Add($term.TermSet.Group.Name)
	$segments.Add($term.TermStore.Name)
	$segments.Reverse()
	[string]::Join(':',$segments.ToArray())
}

$termsets | %{ $_.GetAllTerms() } | 
	? { [string]::IsNullOrEmpty($termNames) -or ($termNames -contains $_.Name) } |
	%{ 
		@{
			FullName=<#(ShowTermFullName $_)#>$_.GetPath();
			Name=$_.Name;
			TermId=$_.Id;
			Term=$_
		} |	New-HashObject
	}

<#
.SYNOPSIS
	Dump taxonomy terms from siteUrl
.DESCRIPTION
	x
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
#>
