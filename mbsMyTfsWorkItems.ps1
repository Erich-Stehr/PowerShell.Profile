$tfs = get-tfs http://msitvstf2:8080/tfs/vstfat02
$project = $tfs.wit.Projects.Item("ECIT_MBS_CMS") # ft -wrap -auto Name,Uri,ID
$storedQuery = $project.StoredQueries | ? { $_.Name -eq 'My Work items' }
$workItems = $tfs.wit.Query($storedQuery.QueryText, @{project=$($project.Name)})
$workItems | 
	select ID,@{n='Priority';e={$_.Fields.Item("Priority").Value}},
		@{n='Severity';e={$_.Fields.Item("Severity").Value}},
		@{n='WorkItemType';e={$_.Fields.Item("Work Item Type").Value}},
		State,
		@{n='FinishDate';e={$_.Fields.Item("Finish Date").Value}},
		Title |
	sort FinishDate |
	Export-Csv -Path MyWorkItems.csv