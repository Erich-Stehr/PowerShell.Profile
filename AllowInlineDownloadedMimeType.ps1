# http://www.pdfsharepoint.com/sharepoint-2010-and-pdf-integration-series-part-1/
param ($webappUrl, [string]$mimeType="application/pdf")
$webApp = Get-SPWebApplication $webappUrl
If ($webApp.AllowedInlineDownloadedMimeTypes -notcontains $mimeType)
{
  $webApp.AllowedInlineDownloadedMimeTypes.Add($mimeType)
  $webApp.Update()
  "$mimeType added and saved to $webappUrl."
} Else {
  "$mimeType is already allowed in $webappUrl."
}

