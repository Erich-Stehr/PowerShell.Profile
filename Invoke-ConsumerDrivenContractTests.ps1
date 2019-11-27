param ([string]$testPackage = "BECU.Services.Mortgage.Interop.MemberProfile.Tests", [Hashtable]$endpointReplacements=$null, [string]$projectName = "RelosContractTests")

dotnet new nunit --framework netcoreapp2.1 --name $projectName
Push-Location $projectName
$project = ".\${projectName}.csproj"

# switch project to full framework 4.7.2, dotnet.exe won't do it itself
$projectDoc = [xml](get-content $project)
$projectDoc.Project.PropertyGroup.TargetFramework = "net472"
$projectDoc.Save("$PWD\$project")

dotnet add $project package $testPackage -n
dotnet add $project package NUnit.ConsoleRunner -n
del -rec -force UnitTest1.cs, obj # don't need the example tests, just the Interop ones

dotnet publish $project -o Tests

# bring in config files and tools

$packs = (dotnet list $project package | select-string '\>\s+(?<packagename>\S+)\s+(?<requested>\S+)\s+(?<resolved>\S+)\s*$')
$packs | % {
    $packagename = $_.Matches[0].Groups['packagename'].Value
    $resolved = $_.Matches[0].Groups['resolved'].Value
    if ($packagename -like '*BECU*') {
        copy-item "~\.nuget\packages\${packagename}\${resolved}\lib\net471\*.config" Tests
    } elseif ($packagename -eq 'nunit') {
        $nunitVersion = "${resolved}.0"
    } elseif ($packagename -eq 'NUnit.ConsoleRunner') {
        $runner = "~\.nuget\packages\${packagename}\${resolved}\tools\nunit3-console.exe"
        $runner
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
    $updatedConfig = $true
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
            $updatedConfig = $true
        }
    }
}

if ($updatedConfig) {
    $testDllConfigDoc.Save("$PWD\Tests\${testPackage}.dll.config")
    Write-Verbose -Verbose "$PWD\Tests\${testPackage}.dll.config saved"
}

cd Tests
& $runner "${testPackage}.dll"

Pop-Location