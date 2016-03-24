param (
    [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
    [string[]]$filePath,

    [Parameter(Mandatory=$True)]
    [string]$vmName,
    
    [string]$transferDir = 'Transfer',

    [string]$configXmlPath,
    
    [string]$machinesXmlPath
)
Begin {
    $PIPELINEINPUT = (-not $PSBOUNDPARAMETERS.ContainsKey("filePath"))
    
    function ScriptRoot { Split-Path $MyInvocation.ScriptName }

    if ([String]::IsNullOrWhiteSpace($configXmlPath)) {
        $configXmlPath = "$(Split-Path (ScriptRoot))\Service\ScraperService.exe.config"
    }
    if ([String]::IsNullOrWhiteSpace($machinesXmlPath)) {
        $machinesXmlPath = "$(Split-Path (ScriptRoot))\Service\VirtualMachines.xml"
    }
    
    # Check that commands we need are available
    ###########################################

    if (!(Get-Command New-AzureStorageContext))
    {
        throw "Could not find Azure PowerShell cmdlets. Be sure you have the Azure PowerShell tools installed"
    }

    if (!(Get-Command .\XPathScanner.ps1))
    {
        throw "Could not find XPathScanner.ps1. Check scraperservice\Tools"
    }

    # Check that all the files we're looking for exist
    ##################################################

    if (!(Test-Path $configXmlPath))
    {
        throw "Could not find config file with account keys at ${configXmlPath}. Be sure the path is correct"
    }

    if (!(Test-Path $machinesXmlPath))
    {
       throw "Could not find the VM description file at ${machinesXmlPath}. Be sure the path is correct"
    }

    # Read VirutalMachines.xml to get the account and share names
    #############################################################

    $machineInfo = dir $machinesXmlPath | .\XPathScanner.ps1 -xpath "//Machine[@Name='${vmName}']" | Select -Property StorageAccount, FileShare

    if ($machineInfo -eq $null)
    {
        $validMachines = dir $machinesXmlPath | .\XPathScanner.ps1 -xpath "//Machine" | Select -Property Name
        throw "The VM name specified was not found (names are case-sensitive). Valid names are `n`n$($validMachines.Name -join "`n")"
    }

    # Read config file to get the account key
    #########################################

    $cnxnStringEl = dir $configXmlPath | .\XPathScanner.ps1 -xpath "//connectionStrings/add[@name='$($machineInfo.StorageAccount)']"

    if ($cnxnStringEl -eq $null)
    {    
        throw "The Azure connection string could not be found in the config file"
    }

    $cnxnString = $cnxnStringEl.connectionString
    $key = $cnxnString.Substring($cnxnString.IndexOf("AccountKey=") + "AccountKey=".length)

    # Set up Azure context 
    ######################

    $context = New-AzureStorageContext $machineInfo.StorageAccount $key
    $share = Get-AzureStorageShare -Name $machineInfo.FileShare -Context $context
    $dirReference = $share.GetRootDirectoryReference().GetDirectoryReference("${transferDir}")

    if (!($dirReference.Exists()))
    {
        throw "Directory ${transferDir} does not exist in the given file share"
    }
    
# From 2006/12/07 news://microsoft.public.windows.powershell/OgyoaxkGHHA.3780@TK2MSFTNGP02.phx.gbl
# Tweaked 2007/03/17 to add hashClassname parameter
function Get-Hash
{
	param(
	     [string]$path,
	     [string]$format="X2",
	     [string]$hashClassname="System.Security.Cryptography.MD5")
	begin
	{
	     if (!$hashClassname.Contains(".")) { $hashClassname = "System.Security.Cryptography." + $hashClassname }
	     $hashAlgorithm = invoke-expression "[$hashClassname]::Create()"
	
	     function ProcessObject($object)
	     {
	         if($object -is [IO.FileInfo])
	         {
	             ProcessFile $object.FullName
	         }
	         elseif($object -is [IO.DirectoryInfo])
	         {
	             # skip directories...
	         }
	         elseif($object -and $object.Path)
	         {
	             ProcessFile $object.Path
	         }
	         elseif($object)
	         {
	            ProcessFile $object
	         }
	     }
	     function ProcessFile([string]$filesToProcess)
	     {
	         foreach($pathInfo in (resolve-path $filesToProcess))
	         {
	             $stream = $null;
	             trap
	             {
	                 ## We have to be sure that we close the file stream
	                 ## if any exceptions are thrown.
	                 if ($stream -ne $null)
	                 {
	                     $stream.Close();
	                 }
	             }
	
	             $file=[System.IO.FileInfo]$pathInfo.Path
	
	             $stream = $file.OpenRead();
	             $hashByteArray = $hashAlgorithm.ComputeHash($stream);
	             $stream.Close();
	
	             $result=1 | Select Text, Bytes, Path
	             $result.Text=[String]::Join("", ($hashByteArray | %{ "{0:$format}" -f $_ }) )
	             $result.Bytes=$hashByteArray
	             $result.Path=$file.FullName
	
	             $result
	          }
	     }
	}
	process
	{
	     ProcessObject $_
	}
	end
	{
	     ProcessObject $path
	}
}

    function Upload($path) {
        $fileName = [IO.Path]::GetFileName($path)
        $file = [IO.FileInfo]$path
        $fileMD5 = [Convert]::ToBase64String((Get-Hash $path).Bytes)

        $fileRequestOptions = new-object Microsoft.WindowsAzure.Storage.File.FileRequestOptions
        $fileRequestOptions.StoreFileContentMD5 = $true
        $fileRequestOptions.UseTransactionalMD5 = $true
        $fileRequestOptions.DisableContentMD5Validation = $false

        do {
			$fileReference = $null
            while ($null -eq $fileReference) {
				$fileReference = $dirReference.GetFileReference($fileName)
				if ($null -eq $fileReference) {
					Write-Warning "Could not get file reference for $filename; sleeping 15 seconds before retry"
					sleep 15
                }
            }
            $fileReference.UploadFromFile($path, [IO.FileMode]::OpenOrCreate, $null, $fileRequestOptions)
            $fileReference.FetchAttributes()
            Write-Debug "Local $file ${fileMD5}: Remote $($fileReference.Properties.Length) $($fileReference.Properties.ContentMD5)"
        } until ($fileReference.Properties.Length -eq $file.Length -and $fileMD5 -eq $fileReference.Properties.ContentMD5)
    }
}
Process {
    if ($PIPELINEINPUT) {
        Upload $_
    } else {
        $filePath | % {
            Upload $_
        }
    }
}
End {
}

<#
.SYNOPSIS
    Upload the specified file to the a ScraperService VM

.EXAMPLE
	PS> Send-File -filePath D:\helloworld.txt -vmName RITool001
        
    Upload D:\helloworld.txt to RITool001\z$\Transfer
    
.EXAMPLE
    PS> dir *-scr-req.xml | Send-File -vmName RITool003 -transferDir RequestsIn
        
    Upload all the request XML files in the given directory to the RequetsIn folder on RITool003

.EXAMPLE
    PS> dir ..\Service\VirtualMachines.xml | .\XpathScanner.ps1 -xpath "//Machine" | Select -ExpandProperty Name | % { dir *.zip | .\Send-File.ps1 -vmName $_ }
    
    Send all the zip files in the current directory to the Transfer directory of all VMs
#>