# from http://blog.falchionconsulting.com/index.php/2011/04/retrieving-sharepoint-2010-feature-activations-using-windows-powershell/
# 2013/03/13 added global to keep it around
function global:Get-SPFeatureActivations() {
  <#
  .Synopsis
    Retrieves Feature activations for the given Feature Definition.
  .Description
    Retrieves the SPFeature object for each activation of the SPFeatureDefinition object.
  .Example
    Get-SPFeatureActivations TeamCollab
  .Parameter Identity
    The Feature name, ID, or SPFeatureDefinition object whose activations will be retrieved.
  .Parameter NeedsUpgrade
    If specified, only Feature activations needing upgrading will be retrieved.
  .Link
    Get-SPFeature
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
    [Alias("Feature")]
    [ValidateNotNullOrEmpty()]
    [Microsoft.SharePoint.PowerShell.SPFeatureDefinitionPipeBind]$Identity,
    
    [Parameter(Mandatory=$false, Position=1)]
    [switch]$NeedsUpgrade
  )
  begin { }
  process {
    $fd = $Identity.Read()
    switch ($fd.Scope) {
      "Farm" {
        [Microsoft.SharePoint.Administration.SPWebService]::AdministrationService.QueryFeatures($fd.ID, $NeedsUpgrade.IsPresent)
        break
      }
      "WebApplication" {
        [Microsoft.SharePoint.Administration.SPWebService]::QueryFeaturesInAllWebServices($fd.ID, $NeedsUpgrade.IsPresent)
        break
      }
      "Site" {
        foreach ($webApp in Get-SPWebApplication) {
          $webApp.QueryFeatures($fd.ID, $NeedsUpgrade.IsPresent)
        }
        break
      }
      "Web" {
        foreach ($site in Get-SPSite -Limit All) {
          $site.QueryFeatures($fd.ID, $NeedsUpgrade.IsPresent)
          $site.Dispose()
        }
        break
      }
    }
  }
  end { }
}
