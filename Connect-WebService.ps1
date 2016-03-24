############################################################################## 
## Connect-WebService.ps1 
## 
## Connect to a given web service, and create a type that allows you to 
## interact with that web service. 
## 
## Example: 
## 
##     $wsdl = "http://terraserver.microsoft.com/TerraService2.asmx?WSDL" 
##     $terraServer = Connect-WebService $wsdl 
##     $place = New-Object Place 
##     $place.City = " Redmond " 
##     $place.State = "WA" 
##     $place.Country = " USA " 
##     $facts = $terraserver.GetPlaceFacts($place) 
##     $facts.Center 
## http://www.leeholmes.com/blog/CallingAWebserviceFromPowerShell.aspx 2007/02/27
############################################################################## 
param([string] $wsdlLocation = $(throw "Please specify a WSDL location")) 
  
## Create the web service cache, if it doesn't already exist 
if(-not (Test-Path Variable:\Lee.Holmes.WebServiceCache)) 
{ 
    ${GLOBAL:Lee.Holmes.WebServiceCache} = @{} 
} 
  
## Check if there was an instance from a previous connection to 
## this web service. If so, return that instead. 
$oldInstance = ${GLOBAL:Lee.Holmes.WebServiceCache}[$wsdlLocation] 
if($oldInstance) 
{ 
    $oldInstance 
    return 
} 
  
## Load the required Web Services DLL 
[void] [Reflection.Assembly]::LoadWithPartialName("System.Web.Services") 
  
## Download the WSDL for the service, and create a service description from 
## it. 
$wsdlPath = [IO.Path]::GetTempFileName() 
  
$wc = new-object System.Net.WebClient 
$wc.DownloadFile($wsdlLocation, $wsdlPath) 
  
## Ensure that we were able to fetch the WSDL 
if(-not (Test-Path $wsdlPath)) 
{ 
    return 
} 
  
$serviceDescription = 
    [Web.Services.Description.ServiceDescription]::Read($wsdlPath) 
Remove-Item $wsdlPath 
  
## Ensure that we were able to read the WSDL into a service description 
if(-not (Test-Path Variable:\serviceDescription)) 
{ 
    return 
} 
  
## Import the web service into a CodeDom 
$serviceNamespace = New-Object System.CodeDom.CodeNamespace 
$codeCompileUnit = New-Object System.CodeDom.CodeCompileUnit 
$serviceDescriptionImporter = 
    New-Object Web.Services.Description.ServiceDescriptionImporter 
$serviceDescriptionImporter.AddServiceDescription( 
    $serviceDescription, $null, $null) 
[void] $codeCompileUnit.Namespaces.Add($serviceNamespace) 
[void] $serviceDescriptionImporter.Import( 
    $serviceNamespace, $codeCompileUnit) 
  
## Generate the code from that CodeDom into a string 
$generatedCode = New-Object Text.StringBuilder 
$stringWriter = New-Object IO.StringWriter $generatedCode 
$provider = New-Object Microsoft.CSharp.CSharpCodeProvider 
$provider.GenerateCodeFromCompileUnit($codeCompileUnit, $stringWriter, $null) 
  
## Compile the source code. 
$references = @("System.dll", "System.Web.Services.dll", "System.Xml.dll") 
$compilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters 
$compilerParameters.ReferencedAssemblies.AddRange($references) 
$compilerParameters.GenerateInMemory = $true 
  
$compilerResults = 
    $provider.CompileAssemblyFromSource($compilerParameters, $generatedCode) 
  
## Write any errors if generated.         
if($compilerResults.Errors.Count -gt 0) 
{ 
    $errorLines = "" 
    foreach($error in $compilerResults.Errors) 
    { 
        $errorLines += "`n`t" + $error.Line + ":`t" + $error.ErrorText 
    } 
  
    Write-Error $errorLines 
    return 
} 
## There were no errors.  Create the webservice object and return it. 
else 
{ 
    ## Get the assembly that we just compiled 
    $assembly = $compilerResults.CompiledAssembly 
  
    ## Find the type that had the WebServiceBindingAttribute. 
    ## There may be other "helper types" in this file, but they will 
    ## not have this attribute 
    $type = $assembly.GetTypes() | 
        Where-Object { $_.GetCustomAttributes( 
            [System.Web.Services.WebServiceBindingAttribute], $false) } 
  
    if(-not $type) 
    { 
        Write-Error "Could not generate web service proxy." 
        return 
    } 
  
    ## Create an instance of the type, store it in the cache, 
    ## and return it to the user. 
    $instance = $assembly.CreateInstance($type) 
    ${GLOBAL:Lee.Holmes.WebServiceCache}[$wsdlLocation] = $instance 
    $instance 
} 
