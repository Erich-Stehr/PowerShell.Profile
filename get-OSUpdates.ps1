#http://www.wintellect.com/CS/blogs/jrobbins/archive/2010/09/09/what-is-different-between-the-os-s-on-two-machines.aspx
# modified to query history correctly and to output an object stream instead of strings to host
$updateSearcher = new-object -com "Microsoft.Update.Searcher"
$updateCount= $updateSearcher.GetTotalHistoryCount()
$updateSearcher.QueryHistory(0,$updateCount) | Sort-Object -Property Date | Select-Object Date,Title