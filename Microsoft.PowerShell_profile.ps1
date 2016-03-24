function mergetxt {
	param ([string]$files = "*.nws", [string]$target = ((split-path $pwd -leaf) + '.txt'))
	dir $files | %{ add-content -LiteralPath $target -value ((get-content -LiteralPath $_ -readCount ([long]::MaxValue))+"`r`n") }
}
# Load posh-git example profile
. "$(split-path $PROFILE.CurrentUserCurrentHost)\Modules\posh-git\profile.example.ps1"

