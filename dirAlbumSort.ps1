dir $args | 
	select Name,@{n='SortName';e={if ($_.Name -match '^.*?_.*?_.*?[-_](\d+)[-_](\d+)-?') {"$(([int]$matches[1]).ToString('D2'))_$(([int]$matches[2]).ToString('D3'))"} else {$_.Name}}} | 
	sort SortName | 
	... Name
