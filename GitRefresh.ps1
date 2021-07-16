param (
	[string[]]
	# branch names to pull instead of fetch, as they shouldn't be directly worked in ("master", "main", "dev")
	$PullBranch = @("master", "main", "dev")
)
dir $PSScriptRoot -exclude nongit | ? { $_.PsIsContainer } | % { ""; pushd -pass $_ | select -expandproperty Path ; $branchName = git branch --show-current ; $branchName ; if ($PullBranch.Contains($branchName)) { git pull --all -p } else { git fetch --all -p } ; GitRemoveTrackingBranchesNoLongerRemote.ps1 ; popd }