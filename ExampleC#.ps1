#http://sadomovalex.blogspot.com/2012/09/write-c-code-in-powershell-scripts.html?
$assemblies = (
    "Microsoft.SharePoint, Version=14.0.0.0, Culture=neutral, PublicKeyToken=71e9bce111e9429c"
    )
 
$source = @"
using System;
using Microsoft.SharePoint;
 
namespace Test
{
    public static class ScriptExample
    {
        public static void EnumerateWebs(string url)
        {
            using (SPSite site = new SPSite(url))
            {
                foreach (SPWeb web in site.AllWebs)
                {
                    Console.WriteLine(web.Url);
                    web.Dispose();
                }
            }
        }
    }
}
"@
 
$url = "http://example.com"
Add-Type -ReferencedAssemblies $assemblies -TypeDefinition $source -Language CSharp 
[Test.ScriptExample]::EnumerateWebs($url)
