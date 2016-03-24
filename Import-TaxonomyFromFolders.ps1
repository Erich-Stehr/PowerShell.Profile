param (
	[string] 
	# (local) url of document to work with
	$documentUrl=$(throw "Requires document URL to work with"),
	[Object[]]
	# additional terms to include in the import
	$AdditionalTerms=@()
	)
# check for error causing states
[void](get-pssnapin Microsoft.SharePoint.PowerShell -ea stop)

$site = new-object Microsoft.SharePoint.SPSite $documentUrl
$taxoSession = Get-SPTaxonomySession -Site $site
$web = $site.OpenWeb()
$document = $web.GetFile($documentUrl)
$library = $document.DocumentLibrary
$folderPath = $document.ServerRelativeUrl.Substring($library.RootFolder.ServerRelativeUrl.Length)
$fragments = New-Object 'System.Collections.ArrayList'
$fragments.AddRange((split-path $folderPath -parent ).Split('\', [StringSplitOptions]::RemoveEmptyEntries))
$fragments.AddRange($AdditionalTerms)

$listItem = $document.Item
$listItem.Fields | 
	? { $_ -ne $null } |
	? { $_.TypeAsString.StartsWith('TaxonomyFieldType') } |
	% {
		$field = $_
		$termset = $taxoSession.TermStores[$_.SspId].GetTermSet($_.TermSetId)
		$terms = New-Object Microsoft.SharePoint.Taxonomy.TaxonomyFieldValueCollection $field
		$fragments | 
			%{ $termset.GetTerms($_, $false) } | 
			%{ 
				if ($null -ne $_) { 
					$val = New-Object Microsoft.SharePoint.Taxonomy.TaxonomyFieldValue($field)
					#BUGBUG?: add to existing values for term instead of replacing?
					$val.TermGuid = $_.Id.ToString()
					$val.Label = $_.Name
					$terms.Add($val) 
				}
			}
		if (($field.AllowMultipleValues) -and ($terms.Count -ne 0)){
			$field.SetFieldValue($listItem, $terms)
		} elseif ($terms.Count -gt 1) {
			Write-Warning "Multiple returns on single value field $($listItem.ID):$($listItem.DisplayName) $($field.InternalName)/$($field.Title)"
			$field.SetFieldValue($listItem, $terms[0])
		} elseif ($terms.Count -eq 1) {
			$field.SetFieldValue($listItem, $terms[0])
		}
	}
try {	
	$listItem.Update()
} catch {
	Write-Warning "'$documentUrl' unable to update list item: $_"
}


<#
.SYNOPSIS
	Attach taxonomy terms to document based on containing folder structure
.DESCRIPTION
	Assuming that the folder structures in the document library are based
	on the taxonomy terms available, this script fragments the document's path,
	checks the TaxonomyFields on the document, and for each TaxonomyField finds
	the terms in the fragments and applies them to the document.
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	string[] status messages
.COMPONENT	
	Microsoft.SharePoint.PowerShell
.EXAMPLE
	Import-TaxonomyFromFolders http://erichstehr/sites/alphatesting/marketing/ViewDocuments/Ampeg/2010%20Catalog/Ampeg_2010_Catalog_lowres.pdf
#>
