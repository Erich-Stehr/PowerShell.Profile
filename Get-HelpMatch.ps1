##############################################################################
## Get-HelpMatch.ps1
##
## Search the PowerShell help documentation for a given keyword or regular
## expression.
## 
## Example:
##    Get-HelpMatch hashtable
##    Get-HelpMatch "(datetime|ticks)"
##
## From http://www.leeholmes.com/blog/GetHelpMatchSearchHelpAproposInPowerShell.aspx
##############################################################################

param($searchWord = $(throw "Please specify content to search for"))

$helpNames = $(get-help *)

foreach($helpTopic in $helpNames)
{
   $content = get-help -Full $helpTopic.Name | out-string
   if($content -match $searchWord)
   {
      $helpTopic | select Name,Synopsis
   } 
}

