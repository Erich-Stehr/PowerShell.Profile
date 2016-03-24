# From 2006/12/07 news://microsoft.public.windows.powershell/OgyoaxkGHHA.3780@TK2MSFTNGP02.phx.gbl
# Tweaked 2007/03/17 to add hash type parameter
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
