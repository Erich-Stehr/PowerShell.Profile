
# SetupEnterpriseSearch.ps1
#
# Original script for SharePoint 2010 beta2 by Gary Lapointe ()
#
# Modified by Søren Laurits Nielsen (soerennielsen.wordpress.com):
#
# Purpose: In addition to setup an enterprise search across multiple servers, it can now be used to setup a working 
# search setup on a single server install in non-domain mode with a complete install role (as opposed to the stand-alone option)
#
# Modified to fix some errors since some cmdlets have changed a bit since beta 2 and added support for "ShareName" for 
# the query component. It is required for non DC computers. 
# 
# Modified to support "localhost" moniker in config file. 
#
# Note: Accounts, Shares and directories specified in the config file must be setup before hand.
#
# Usage: 
#     Start-EnterpriseSearch <config file>
#
# e.g.:
#     Start-EnterpriseSearch "<path>\searchconfig.xml"
#
# Notes on usage: 
#   In order to setup a single server non-domain SharePoint dev machine follow the guidance here: ...
#

#In order to be able to single step the script in PowerShell IDE load SharePoint snapin if not present.
if( (Get-PSSnapIn Microsoft.SharePoint.Powershell -ErrorAction:SilentlyContinue) -eq $null ){
    #Load SharePoint snapin, apparently not started throught the SharePoint powershell
    . "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\14\CONFIG\POWERSHELL\Registration\sharepoint.ps1"
}

function Start-EnterpriseSearch([string]$settingsFile = "Configurations.xml") {
    #SLN: Added support for local host
    [xml]$config = (Get-Content $settingsFile) -replace( "localhost", $env:computername )
    $svcConfig = $config.Services.EnterpriseSearchService 
 
    $searchSvc = Get-SPEnterpriseSearchServiceInstance -Local
    if ($searchSvc -eq $null) {
        throw "Unable to retrieve search service."
    }

    #SLN: Create the network share (will report an error if exist)
    #default to primitives 
    $s = """" + $svcConfig.ShareName + "=" + $svcConfig.IndexLocation + """"
    Write ("Creating network share " + $s)
    net share $s "/GRANT:WSS_WPG,CHANGE"


    #SLN: Does NOT set the service account, uses the default as Set-SPEnterpriseSearchService 
    # have a hard time understanding it without an actual secure password (which you don't have by looking up the 
    # manager service account).
    
    #Write-Host "Getting $($svcConfig.Account) account for search service..."
    #$searchSvcManagedAccount = (Get-SPManagedAccount -Identity $svcConfig.Account -ErrorVariable err -ErrorAction SilentlyContinue)
    #if ($err) {
    #    $searchSvcAccount = Get-Credential $svcConfig.Account 
    #    $searchSvcManagedAccount = New-SPManagedAccount -Credential $searchSvcAccount
    #}

    Get-SPEnterpriseSearchService | Set-SPEnterpriseSearchService  `
      -ContactEmail $svcConfig.ContactEmail -ConnectionTimeout $svcConfig.ConnectionTimeout `
      -AcknowledgementTimeout $svcConfig.AcknowledgementTimeout -ProxyType $svcConfig.ProxyType `
      -IgnoreSSLWarnings $svcConfig.IgnoreSSLWarnings -InternetIdentity $svcConfig.InternetIdentity -PerformanceLevel $svcConfig.PerformanceLevel
    

    Write-Host "Setting default index location on search service..."

    $searchSvc | Set-SPEnterpriseSearchServiceInstance -DefaultIndexLocation $svcConfig.IndexLocation -ErrorAction SilentlyContinue -ErrorVariable err

    $svcConfig.EnterpriseSearchServiceApplications.EnterpriseSearchServiceApplication | ForEach-Object {
        $appConfig = $_

        #Try and get the application pool if it already exists
        $pool = Get-ApplicationPool $appConfig.ApplicationPool
        $adminPool = Get-ApplicationPool $appConfig.AdminComponent.ApplicationPool

        $searchApp = Get-SPEnterpriseSearchServiceApplication -Identity $appConfig.Name -ErrorAction SilentlyContinue

        if ($searchApp -eq $null) {
            Write-Host "Creating enterprise search service application..."
            $searchApp = New-SPEnterpriseSearchServiceApplication -Name $appConfig.Name `
                -DatabaseServer $appConfig.DatabaseServer `
                -DatabaseName $appConfig.DatabaseName `
                -FailoverDatabaseServer $appConfig.FailoverDatabaseServer `
                -ApplicationPool $pool `
                -AdminApplicationPool $adminPool `
                -Partitioned:([bool]::Parse($appConfig.Partitioned)) `
                -SearchApplicationType $appConfig.SearchServiceApplicationType
        } else {
            Write-Host "Enterprise search service application already exists, skipping creation."
        }

        $installCrawlSvc = (($appConfig.CrawlServers.Server | where {$_.Name -eq $env:computername}) -ne $null)
        $installQuerySvc = (($appConfig.QueryServers.Server | where {$_.Name -eq $env:computername}) -ne $null)
        $installAdminCmpnt = (($appConfig.AdminComponent.Server | where {$_.Name -eq $env:computername}) -ne $null)
        $installSyncSvc = (($appConfig.SearchQueryAndSiteSettingsServers.Server | where {$_.Name -eq $env:computername}) -ne $null)

        if ($searchSvc.Status -ne "Online" -and ($installCrawlSvc -or $installQuerySvc)) {
            $searchSvc | Start-SPEnterpriseSearchServiceInstance
        }

        if ($installAdminCmpnt) {
            Write-Host "Setting administration component..."
            Set-SPEnterpriseSearchAdministrationComponent -SearchApplication $searchApp -SearchServiceInstance $searchSvc
        }

        $crawlTopology = Get-SPEnterpriseSearchCrawlTopology -SearchApplication $searchApp | where {$_.CrawlComponents.Count -gt 0 -or $_.State -eq "Inactive"}

        if ($crawlTopology -eq $null) {
            Write-Host "Creating new crawl topology..."
            $crawlTopology = $searchApp | New-SPEnterpriseSearchCrawlTopology
        } else {
            Write-Host "A crawl topology with crawl components already exists, skipping crawl topology creation."
        }
 
        if ($installCrawlSvc) {
            $crawlComponent = $crawlTopology.CrawlComponents | where {$_.ServerName -eq $env:ComputerName}
            if ($crawlTopology.CrawlComponents.Count -eq 0 -and $crawlComponent -eq $null) {
                $crawlStore = $searchApp.CrawlStores | where {$_.Name -eq "$($appConfig.DatabaseName)_CrawlStore"}
                Write-Host "Creating new crawl component..."
                $crawlComponent = New-SPEnterpriseSearchCrawlComponent -SearchServiceInstance $searchSvc -SearchApplication $searchApp -CrawlTopology $crawlTopology -CrawlDatabase $crawlStore.Id.ToString() -IndexLocation $appConfig.IndexLocation
            } else {
                Write-Host "Crawl component already exist, skipping crawl component creation."
            }
        }

        $queryTopology = Get-SPEnterpriseSearchQueryTopology -SearchApplication $searchApp | where {$_.QueryComponents.Count -gt 0 -or $_.State -eq "Inactive"}

        if ($queryTopology -eq $null) {
            Write-Host "Creating new query topology..."
            $queryTopology = $searchApp | New-SPEnterpriseSearchQueryTopology -Partitions $appConfig.Partitions
        } else {
            Write-Host "A query topology with query components already exists, skipping query topology creation."
        }

        if ($installQuerySvc) {
            $queryComponent = $queryTopology.QueryComponents | where {$_.ServerName -eq $env:ComputerName}
            #if ($true){ #$queryTopology.QueryComponents.Count -eq 0 -and $queryComponent -eq $null) {
            if ($queryTopology.QueryComponents.Count -eq 0 -and $queryComponent -eq $null) {
                $partition = ($queryTopology | Get-SPEnterpriseSearchIndexPartition)
                Write-Host "Creating new query component..."
                $queryComponent = New-SPEnterpriseSearchQueryComponent -IndexPartition $partition -QueryTopology $queryTopology -SearchServiceInstance $searchSvc -ShareName $svcConfig.ShareName
                Write-Host "Setting index partition and property store database..."
                $propertyStore = $searchApp.PropertyStores | where {$_.Name -eq "$($appConfig.DatabaseName)_PropertyStore"}
                $partition | Set-SPEnterpriseSearchIndexPartition -PropertyDatabase $propertyStore.Id.ToString()
            } else {
                Write-Host "Query component already exist, skipping query component creation."
            }
        }

        if ($installSyncSvc) {            
            #SLN: Updated to new syntax
            Start-SPServiceInstance (Get-SPServiceInstance | where { $_.TypeName -eq "Search Query and Site Settings Service"}).Id
        }

        #Don't activate until we've added all components
        $allCrawlServersDone = $true
        $appConfig.CrawlServers.Server | ForEach-Object {
            $server = $_.Name
            $top = $crawlTopology.CrawlComponents | where {$_.ServerName -eq $server}
            if ($top -eq $null) { $allCrawlServersDone = $false }
        }

        if ($allCrawlServersDone -and $crawlTopology.State -ne "Active") {
            Write-Host "Setting new crawl topology to active..."
            $crawlTopology | Set-SPEnterpriseSearchCrawlTopology -Active -Confirm:$false

            Write-Host -ForegroundColor Red "Waiting on Crawl Components to provision..."

            while ($true) {
                $ct = Get-SPEnterpriseSearchCrawlTopology -Identity $crawlTopology -SearchApplication $searchApp
                $state = $ct.CrawlComponents | where {$_.State -ne "Ready"}
                if ($ct.State -eq "Active" -and $state -eq $null) {
                    break
                }

                Write-Host -ForegroundColor Red "Waiting on Crawl Components to provision..."
                Start-Sleep 5
            }

            # Need to delete the original crawl topology that was created by default
            $searchApp | Get-SPEnterpriseSearchCrawlTopology | where {$_.State -eq "Inactive"} | Remove-SPEnterpriseSearchCrawlTopology -Confirm:$false
        }

        $allQueryServersDone = $true
        $appConfig.QueryServers.Server | ForEach-Object {
            $server = $_.Name
            $top = $queryTopology.QueryComponents | where {$_.ServerName -eq $server}
            if ($top -eq $null) { $allQueryServersDone = $false }
        }

        #Make sure we have a crawl component added and started before trying to enable the query component
        if ($allCrawlServersDone -and $allQueryServersDone -and $queryTopology.State -ne "Active") {
            Write-Host "Setting query topology as active..."
            $queryTopology | Set-SPEnterpriseSearchQueryTopology -Active -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable err

            Write-Host -ForegroundColor Red "Waiting on Query Components to provision..."
            while ($true) {
                $qt = Get-SPEnterpriseSearchQueryTopology -Identity $queryTopology -SearchApplication $searchApp
                $state = $qt.QueryComponents | where {$_.State -ne "Ready"}
                if ($qt.State -eq "Active" -and $state -eq $null) {
                    break
                }

                Write-Host -ForegroundColor Red "Waiting on Query Components to provision..."
                Start-Sleep 5
            }

            # Need to delete the original query topology that was created by default
            $searchApp | Get-SPEnterpriseSearchQueryTopology | where {$_.State -eq "Inactive"} | Remove-SPEnterpriseSearchQueryTopology -Confirm:$false
        }

        $proxy = Get-SPEnterpriseSearchServiceApplicationProxy -Identity $appConfig.Proxy.Name -ErrorAction SilentlyContinue
        if ($proxy -eq $null) {
            Write-Host "Creating enterprise search service application proxy..."
            $proxy = New-SPEnterpriseSearchServiceApplicationProxy -Name $appConfig.Proxy.Name -SearchApplication $searchApp -Partitioned:([bool]::Parse($appConfig.Proxy.Partitioned))
        } else {
            Write-Host "Enterprise search service application proxy already exists, skipping creation."
        }

        if ($proxy.Status -ne "Online") {
            $proxy.Status = "Online"
            $proxy.Update()
        }

        $proxy | Set-ProxyGroupsMembership $appConfig.Proxy.ProxyGroup
    }
}

 
 
function Set-ProxyGroupsMembership([System.Xml.XmlElement[]]$groups, [Microsoft.SharePoint.Administration.SPServiceApplicationProxy[]]$InputObject)
{
    begin {}
    process {
        $proxy = $_
        
        #Clear any existing proxy group assignments
        Get-SPServiceApplicationProxyGroup | where {$_.Proxies -contains $proxy} | ForEach-Object {
            $proxyGroupName = $_.Name
            if ([string]::IsNullOrEmpty($proxyGroupName)) { $proxyGroupName = "Default" }
            $group = $null
            [bool]$matchFound = $false
            foreach ($g in $groups) {
                $group = $g.Name
                if ($group -eq $proxyGroupName) { 
                    $matchFound = $true
                    break 
                }
            }
            if (!$matchFound) {
                Write-Host "Removing ""$($proxy.DisplayName)"" from ""$proxyGroupName"""
                $_ | Remove-SPServiceApplicationProxyGroupMember -Member $proxy -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
        
        foreach ($g in $groups) {
            $group = $g.Name

            $pg = $null
            if ($group -eq "Default" -or [string]::IsNullOrEmpty($group)) {
                $pg = [Microsoft.SharePoint.Administration.SPServiceApplicationProxyGroup]::Default
            } else {
                $pg = Get-SPServiceApplicationProxyGroup $group -ErrorAction SilentlyContinue -ErrorVariable err
                if ($pg -eq $null) {
                    $pg = New-SPServiceApplicationProxyGroup -Name $name
                }
            }
            
            $pg = $pg | where {$_.Proxies -notcontains $proxy}
            if ($pg -ne $null) { 
                Write-Host "Adding ""$($proxy.DisplayName)"" to ""$($pg.DisplayName)"""
                $pg | Add-SPServiceApplicationProxyGroupMember -Member $proxy 
            }
        }
    }
    end {}
}

function Get-ApplicationPool([System.Xml.XmlElement]$appPoolConfig) {
    #Try and get the application pool if it already exists
    #SLN: Updated names
    $pool = Get-SPServiceApplicationPool -Identity $appPoolConfig.Name -ErrorVariable err -ErrorAction SilentlyContinue
    if ($err) {
        #The application pool does not exist so create.
        Write-Host "Getting $($appPoolConfig.Account) account for application pool..."
        $managedAccount = (Get-SPManagedAccount -Identity $appPoolConfig.Account -ErrorVariable err -ErrorAction SilentlyContinue)
        if ($err) {
            $accountCred = Get-Credential $appPoolConfig.Account
            $managedAccount = New-SPManagedAccount -Credential $accountCred
        }
        Write-Host "Creating application pool $($appPoolConfig.Name)..."
        $pool = New-SPServiceApplicationPool -Name $appPoolConfig.Name -Account $managedAccount
    }
    return $pool
}


