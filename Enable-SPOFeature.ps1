﻿##########################################################################################
#    Name:           Enable-SPOFeature   
#    Description:    This script enables a feature using CSOM
#    Usage:          .\Enable-SPOFeature -User "name@server.onmicrosoft.com" -Password "Password" -Url "https://sposite.sharepoint.com/" -Feature "4aec7207-0d02-4f4f-aa07-b370199cd0c7" -Scope Site -Sandbox $true -Force $true
#    Creator:        Luis Manez <http://geeks.ms/blogs/lmanez/archive/2013/09/29/office-365-enable-disable-feature-from-power-shell-using-csom.aspx>
# Modified v-erichs 20131118 to use proper parameter types/attributes
##########################################################################################

param(
	[Parameter(Mandatory=$true)]
    [string]
    #  user in the Office 365 tenant 
    $user, 
	[Parameter(Mandatory=$true)]
    [string]
    # user password 
    $password, 
	[Parameter(Mandatory=$true)]
    [string]
    # Full URL to the site or web 
    $url, 
	[Parameter(Mandatory=$true)]
    [string]
    # Feature Id (GUID)
    $feature, 
	[Parameter(Mandatory=$true)]
    [ValidateSet("Site","Web")]
    [string]
    # Site / Web. Scope of the feature that we want to activate
    $scope, 
    [switch]
    # indicates if the solution where the feature lives is a Farm solution or a Sandbox solution
    $sandbox=$true, 
    [switch]
    # Re-enable feature if is already activated 
    $force=$false)

Add-Type -Path "c:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.dll"

function GetClientContext($url, $user, $password) {
   $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
   
   $context = New-Object Microsoft.SharePoint.Client.ClientContext($url)
   $credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($user, $securePassword)
   $context.Credentials = $credentials
   
   return $context
}

# MAIN CODE
#

$featureId = [GUID]($feature)
$clientContext = GetClientContext $url $user $password
write-host "Conected to SharePoint OK"

if ($scope.ToLower() -eq "web") {
    $features = $clientContext.Web.Features
} else {
    $features = $clientContext.Site.Features
}

$featureDefinitionScope = [Microsoft.SharePoint.Client.FeatureDefinitionScope]::Farm  
if ($sandbox) {
    $featureDefinitionScope = [Microsoft.SharePoint.Client.FeatureDefinitionScope]::Site
}

$clientContext.Load($features)
$clientContext.ExecuteQuery()


$features.Add($featureId, $force, $featureDefinitionScope)
try {
    $clientContext.ExecuteQuery()
    write-host "Feature activated"
}
catch {
    write-host "An error ocurred activating Feature. Error detail: $($_)"
}