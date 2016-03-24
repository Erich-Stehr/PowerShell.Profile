param ([string]$path="C:\Program Files\Common Files\microsoft shared\Web Server Extensions\14\TEMPLATE\LAYOUTS\1033\STYLES\Themable\SEARCH.CSS", [string[]]$target=@("!important","font-family:"))

filter FragmentCSSString()
{
	$s = $_
	while (($x = $s.IndexOfAny("{}")) -ge 0) {
		if ($x -gt 0) { $s.Substring(0,$x) }
		$s.Chars($x).ToString()
		$s = $s.Substring($x+1)
		if ([String]::IsNullOrEmpty($s)) {break;}
	}
	if ($s.Length -gt 0) {$s}
}

$inBrace = $false
$found = $false
$selectors = New-Object 'system.collections.generic.List[string]'
$css = New-Object 'system.collections.generic.List[string]'

Get-Content -Path $path |
	FragmentCssString |
	% {
		if ($_ -eq '{') {
			$inBrace = $true
		} elseif ($_ -eq '}') {
			if ($found) { # print the ones that match
				$selectors
				'{'
				$css
				'}'
			}
			# clear for the next set
			$selectors.Clear()
			$css.Clear()
			$found = $false
			$inBrace = $false
		} elseif (!$inBrace) {
			$selectors.Add($_)
		} else {
			$css.Add($_)
			$item = $_
			$target | %{ $found = $found -or ($item.ToUpper().Contains($_.ToUpper())) }
		}
	}
if ($selectors.Count -gt 0)
{
	$selectors
}
if ($css.Count -gt 0)
{
	$css
	throw "CSS file has unclosed style(s)!"
}
	