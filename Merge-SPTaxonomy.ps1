param (
	[string] 
	# (local) site url to work with
	$siteUrl=$(throw "Requires (local) site URL to work with"),
	[object] 
	# Group name to find/create termSet in (default: search and fail if not present)
	$GroupName=$null,
	[string] 
	# termset to work with within group
	$termSetName=$(throw "Requires specific termset to work with"),
	[string] 
	# term to root work with within termset (default has termset as root)
	$rootTermName=$null,
	[object[]] 
	# properties of pipeline input in inheritance order ("Level1","Level2",...,"Leaf")
	$property=$("Brand","Model_Group","Model"),
	[object[]] 
	# properties of pipeline input to attach to leaf term
	$ItemProperty=$("Item_Type"),
	[string] 
	# property of pipeline input with comma/semicolon separated synonyms for the leaf term
	$SynonymProperty="Synonyms",
	[switch] 
	# mark terms not specified in pipeline input as Deprecated
	$DeprecateMissing=$false,
	[switch] 
	# pass terms down to next stage of pipeline
	$PassThru=$false,
	[switch] 
	# prevents commit of changes
	$nocommit=$false,
	[switch] 
	# don't recreate existing taxonomy session (for use in tests)
	$reuseTest=$false
)
begin {	
	# check for error causing states
	[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)
	if (![System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Taxonomy")) {
	        trap { break; }
	        throw "Can't load Microsoft.SharePoint.Taxonomy!"
	}

function GetTermsFrom($obj, [string]$name) {
	$term = $null
	if (!([String]::IsNullOrEmpty($name))) {
		# Term.GetTerms works from the termstore and doesn't find uncommited adds
		#$terms = $obj.GetTerms($name, $lcid, $false<#defaultLabelOnly#>, 
		#		[Microsoft.SharePoint.Taxonomy.StringMatchOption]::ExactMatch, 
		#		2, $false<#trimUnavailable#>)
		#if ($terms.Count -eq 1) {
		#	$term = $terms[0]
		#}
		$term = $obj.Terms[$name]
	}
	return $term
}

function AddTermCustomPropertyMulti([Microsoft.SharePoint.Taxonomy.Term]$term, [string]$propName, [string]$propValue) {
	if ("Description".Equals($propName, [StringComparison]::OrdinalIgnoreCase)) {
		$term.SetDescription($propValue, $lcid)
	} else {
		$coll = $term.CustomProperties
		$i = 0
		$lim = $coll.Count
		foreach ($key in $coll.Keys) {
			if ($null -eq $key) { continue; }
			if ($key.StartsWith($propName)) {
				++$i; # keep track of matching entry count
			}
		}
		if ($i -eq 0) {
			# not there yet, use proper name
			$term.SetCustomProperty($propName, $propValue)
		} else {
			# multiples being added, suffix with prior count for uniqueness
			# TODO: check for unexpected existance of generated propName
			$term.SetCustomProperty("$propName$i", $propValue)
		}
	}
}

function FullwidthNormalization([string]$s)
# replaces taxonomy special ASCII characters '[;"<>|\t]' with their Unicode 
# Fullwidth forms, leaving '&',([char]0xff06) for the CreateTerm handling
{
	$s.Replace(';',([char]0xff1b)).Replace('"',([char]0xff02)).Replace('<',([char]0xff1c)).Replace('>',([char]0xff1e)).Replace('|',([char]0xff5c)).Replace("`t","¯")
}

function CheckNameCharacters([string]$name)
# performs FullWidthNormalization, for use with all Label's
{
	if ($invalidNameCharacters.IsMatch($name)) {
		$newName = FullwidthNormalization $name
		Write-Warning "Name $name contains invalid characters, reassigned $newName"
		$name = $newName
	}
	$name
}

function GetExtendedTermPath($termSetItem)
# find termSetItem's extended path (termsetName[;term path])
{
	if (($null -ne $termSetItem) -and ($termSetItem -is [Microsoft.SharePoint.Taxonomy.TermSetItem])) {
		$termpath = [String]::Empty
		if ($termSetItem -is [Microsoft.SharePoint.Taxonomy.Term]) {
			$termpath = "$($termSetItem.TermSet.Name);$($termSetItem.GetPath())"
		} else {
			$termpath = $termSetItem.Name
		}
		return $termpath
	}
	return ""
}

$handledTerms = New-Object 'System.Collections.Generic.Dictionary[string,Microsoft.SharePoint.Taxonomy.TermSetItem]'
function HandledTerm($termSetItem)
# cache the term by extended path (termsetName[;term path]) in $handledTerms dictionary
{
	if (($null -ne $termSetItem) -and ($termSetItem -is [Microsoft.SharePoint.Taxonomy.TermSetItem])) {
		$termpath = GetExtendedTermPath $termSetItem
		$handledTerms[$termpath]=[Microsoft.SharePoint.Taxonomy.TermSetItem]$termSetItem
	}
}

	$site = Get-SPSite $siteUrl

	#$script:DebugPreference = [System.Management.Automation.ActionPreference]::Continue

	if (!$reuseTest -or ($null -eq $taxoSession)) {
		$taxoSession = New-Object "Microsoft.SharePoint.Taxonomy.TaxonomySession" $site
	}
	$termStore = $taxoSession.DefaultSiteCollectionTermStore
	# Since TermStore is a service application, other non-defaults are doubtful
	$lcid = $termStore.DefaultLanguage
	
	$groups = @()
	if (!([string]::IsNullOrEmpty($GroupName))) {
		$groups = @($termStore.Groups[$GroupName])
		if (($groups.Count -lt 1) -or ($null -eq $groups[0])) {
			Write-Verbose "Creating group $GroupName"
			$groups = @($termStore.CreateGroup($GroupName))
		}
	} else {
		$groups = @($termStore.Groups)
	}
	$termset = $groups | 
		% { 
			try { 
				$_.TermSets[$termSetName] 
			} catch {
				# on failure, ignore; we didn't want it anyway
			} 
		} |
		? { $_ -ne $null }
	if (($termset -eq $null) -or ($termset -is [Array])){ 
		trap { break; }
		throw "Couldn't resolve termSetName $($termSetName)"
	}
	$rootTerm = $termset
	if (!([String]::IsNullOrEmpty($rootTermName))) {
		$rootTerm = GetTermsFrom $termset $rootTermName
	}
	if (($rootTerm -eq $null) -or ($rootTerm.Count)) {
		trap { break; }
		throw "Couldn't resolve rootTerm $($rootTermName)"
	}
	$needsCommit = $false
	$invalidNameCharacters = [Regex]'[;"<>|\t]'
	[Void](HandledTerm $rootTerm)
}
process {
	if ($null -eq $_) { write-debug "null input" ; continue }
	$row = $_
	Write-Debug "Row=${row}:$(gtn -input $row)"
	$last = $rootTerm
	$property | %{
		$term = $null
		try {
			Write-Debug "Property=$_"
			$name = $row.($_)
			Write-Debug "Processing $name"
			if ([string]::IsNullOrEmpty($name)) {
				Write-Warning "No data for property $_ in item $row"
				continue;
			}
			$name = CheckNameCharacters $name
			$term = GetTermsFrom $last $name 
			[void](HandledTerm $term)
		} catch {
			Write-Error $_
			break;
		}
		if ($null -ne $term) {
			$last = $term
		} else {
			$last = $last.CreateTerm($name, $lcid)
			$needsCommit = $true
		}
		[Void](HandledTerm $last)
	}
	$ItemProperty | %{
		if ($null -ne $_) {
		Write-Debug "ItemProperty=$_"
		$propValue = $row.($_)
		if ($null -ne $propValue) {
			AddTermCustomPropertyMulti $last $_ $propValue 
			# TermSet.GetTermsWithCustomProperty(string, string, boolean)
			$needsCommit = $true
			}
		}
	}
	$currentSynonyms = $row.($synonymProperty)
	if (![string]::IsNullOrEmpty($currentSynonyms))
	{
		$currentSynonyms.Split(",;".ToCharArray(), 
				[StringSplitOptions]::RemoveEmptyEntries) |
			% {
				$name = CheckNameCharacters $_.Trim()
				if ([string]::IsNullOrEmpty($name)) { continue; }
				$label = $null
				try { $label = $last.Labels[$name] } catch { <# leave null if not there #> }
				if ($null -eq $label) {
					$label = $last.CreateLabel($name, $lcid, $false)
				}
			}
		
	}
	if ($PassThru) {
		$last
	}
}
end {
	if ($DeprecateMissing) {
		# Term.GetTerms requires committing first, not there yet
		#$rootTerm.GetTerms([Int32]::MaxValue) |
		function RecurseTerms($obj) {
			if ($null -ne $obj) {
				$obj.Terms
				$obj.Terms | % { RecurseTerms $_ }
			}
		}
		RecurseTerms $rootTerm |
			%{
				$termpath = GetExtendedTermPath $_
				if (!$handledTerms.ContainsKey($termpath)) {
					$_.Deprecate($true)
				}
			}
	}
	if (!$nocommit) {
		if ($needsCommit) {
			$termStore.CommitAll()
		}
		Remove-Variable taxoSession
		Remove-Variable termStore
		Remove-Variable groups
		Remove-Variable termset
	}
}




		
<#
.SYNOPSIS
	Merge/load Managed Metadata Service taxonomy from pipeline
.DESCRIPTION
	Verifies/creates the terms to match the input tuples, rooted in the 
	termstore/termset/rootnode given the inheritance paths in each input tuple 
	named by the Property list and attaching custom	properties named 
	by the ItemProperty list to the leaf Term.
.INPUTS
	pipelined PSObject's
.OUTPUTS
	Term[] of leaf Term's (if -PassThru specified)
.COMPONENT	
	Microsoft.SharePoint.PowerShell
	Microsoft.SharePoint.Taxonomy
.EXAMPLE
	invoke-sqlcommand.ps1 -sql 'SELECT Item_type,Brand,Model_Group,Model ...' |
		Merge-SP2010Taxonomy.ps1 -siteUrl 'http://server' 
				-termSetName 'Loud Tech Inc' 
				-property "Brand","Model_Group","Model"
				-itemProperty "Item_type"
#>
