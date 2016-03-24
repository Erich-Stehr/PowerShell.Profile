param ($path=$(throw "Must have a .csv to work with"), $destination=$(throw "Must place the data somewhere..."))
gc $path | 
	% { $_.TrimEnd(',') } |
	ConvertFrom-Csv |
	select @{n='ProductType';e={$_.ITEM_TYPE}},@{n='SeriesName';e={"$($_.BRAND) $($_.MODEL_GROUP)"}},@{n='ProductName';e={$_.MODEL}} |
	sort ProductType,SeriesName,ProductName |
	Export-Csv -Path $destination
	