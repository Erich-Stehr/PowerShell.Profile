﻿dir | ? { $_.PsIsContainer } | % { ""; pushd -pass $_ | select -expandproperty Path ; git branch --show-current ; git pull --all -p ; GitRemoveTrackingBranchesNoLongerRemote.ps1 ; popd }
