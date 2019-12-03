[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingCmdletAliases", "", Target="del|%|cd")]
param ([int]$passnumber=1, [string]$testPackage = "BECU.Services.Mortgage.Interop.MemberProfile.Tests", [Hashtable]$endpointReplacements=$null, [string]$projectName = "RelosContractTests")

$location = "${env:SYSTEM_DEFAULTWORKINGDIRECTORY}"
if ($location -eq "") {
    $location = $PWD
}
Write-Verbose -Verbose "Location: $location"

if ($passnumber -eq 1) {
    del -rec -force "${location}\${projectName}" -ea SilentlyContinue
    dotnet new nunit --framework net471 --name $projectName -o "${location}\${projectName}" --no-restore
    Push-Location "$location\$projectName"
    $project = "$location\$projectName\${projectName}.csproj"
    Write-Verbose -Verbose "$project saved initially"

    dotnet add $project package $testPackage -n
    dotnet add $project package NUnit.ConsoleRunner -n
    Write-Verbose -Verbose "removing unneeded sample tests"
    del -rec -force UnitTest1.cs
}

if ($passnumber -eq 2) {
    Push-Location "$location\$projectName"
    # needs TFS task to restore through NuGet in order to use service connection
    Write-Verbose -Verbose "publishing Tests project"
    dotnet publish $project -o Tests

    # bring in config files and tools

    Write-Verbose -Verbose "collecting package data/configs for $project"
    $packs = (dotnet list $project package | select-string '\>\s+(?<packagename>\S+)\s+(?<requested>\S+)\s+(?<resolved>\S+)\s*$')
    $packs | % {
        $packagename = $_.Matches[0].Groups['packagename'].Value
        $resolved = $_.Matches[0].Groups['resolved'].Value
        if ($packagename -like '*BECU*') {
            copy-item "~\.nuget\packages\${packagename}\${resolved}\lib\net471\*.config" Tests
        } elseif ($packagename -eq 'nunit') {
            $script:nunitVersion = "${resolved}.0"
        } elseif ($packagename -eq 'NUnit.ConsoleRunner') {
            $script:runner = "~\.nuget\packages\${packagename}\${resolved}\tools\nunit3-console.exe"
            $script:runner
        }
    }

    # update test bindingRedirect's to match nunit version in use
    $testDllConfigDoc = [xml](Get-Content "$PWD\Tests\${testPackage}.dll.config")
    $testNsmgr = new-object System.Xml.XmlNamespaceManager $testDllConfigDoc.NameTable
    $testNsmgr.AddNamespace("asm", "urn:schemas-microsoft-com:asm.v1") # handle assemblyBinding namespace
    $rtXpath = "/configuration/runtime"
    # $bindingXpath = "asm:assemblyBinding[starts-with(asm:dependentAssembly/asm:assemblyIdentity/@name, 'nunit')]"
    $bindingXpath = "asm:assemblyBinding"
    $assemblyBindingDoc = [xml]@"
<configuration>
<runtime>
<assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">
<dependentAssembly>
<assemblyIdentity name="nunit.framework" publicKeyToken="2638cd05610744eb" culture="neutral" />
<bindingRedirect oldVersion="0.0.0.0-${nunitVersion}" newVersion="${nunitVersion}" />
</dependentAssembly>
</assemblyBinding>
</runtime>
</configuration>
"@
    $asmBindNsmgr = new-object System.Xml.XmlNamespaceManager $assemblyBindingDoc.NameTable
    $asmBindNsmgr.AddNamespace("asm", "urn:schemas-microsoft-com:asm.v1")
    $runtimeNode = $testDllConfigDoc.SelectSingleNode($rtXpath)
    $updatedConfig = $false

    $assemblyBindingDoc.SelectNodes("$rtXpath/$bindingXpath", $asmBindNsmgr) | % {
        # for each of the new bindings, either replace or append in test .dll.config
        $newBind = $_
        $newBindName = $newBind.dependentAssembly.assemblyIdentity.name
        $oldBind = $runtimeNode.SelectSingleNode("${bindingXpath}[asm:dependentAssembly/asm:assemblyIdentity/@name = '$newBindName']", $testNsmgr)
        $importedNewBind = $testDllConfigDoc.ImportNode($newBind, $true)
        $script:updatedConfig = $true
        if ($oldBind -eq $null) {
            [void]$runtimeNode.AppendChild($importedNewBind)
        } else {
            [void]$runtimeNode.ReplaceChild($importedNewBind, $oldBind)
        }
        Write-Verbose -Verbose "$newBindName updated"
    }

    # update test config to point to correct endpoints
    if ($endpointReplacements -ne $null) {
        $testDllConfigDoc.SelectNodes("/configuration/system.serviceModel/client/endpoint", $testNsmgr) | % {
            if ($endpointReplacements.ContainsKey($_.address)) {
                Write-Verbose -Verbose "$($_.address) updating to $($endpointReplacements[$_.address])"
                $_.address = $endpointReplacements[$_.address]
                $script:updatedConfig = $true
            }
        }
    }

    if ($updatedConfig) {
        $testDllConfigDoc.Save("$PWD\Tests\${testPackage}.dll.config")
        Write-Verbose -Verbose "$PWD\Tests\${testPackage}.dll.config saved"
    }

    cd Tests
    & $runner "${testPackage}.dll"
}

Pop-Location