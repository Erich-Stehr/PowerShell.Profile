# Modified from <http://gigi.nullneuron.net/gigilabs/getting-organised-with-microsoft-orleans-2-0-in-net-core/>
[CmdletBinding(ConfirmImpact=[System.Management.Automation.ConfirmImpact]::Medium,SupportsShouldProcess=$false)]
#[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string] 
	# Name of solution (creates subdirectory in $pwd if not already in one of same name)
	$solutionName=$(throw "Requires name of solution to create")
	)
if ((Split-Path $pwd -Leaf) -ne $solutionName) {
    cd (md (Join-Path $pwd $solutionName))
}

dotnet new classlib --name "${solutionName}Contracts" --no-restore
dotnet add "${solutionName}Contracts/${solutionName}Contracts.csproj" package Microsoft.Orleans.Core.Abstractions --no-restore
dotnet add "${solutionName}Contracts/${solutionName}Contracts.csproj" package Microsoft.Orleans.OrleansCodeGenerator.Build 

dotnet new classlib --name "${solutionName}Grains" --no-restore
dotnet add "${solutionName}Grains/${solutionName}Grains.csproj" package Microsoft.Orleans.Core.Abstractions --no-restore
dotnet add "${solutionName}Grains/${solutionName}Grains.csproj" package Microsoft.Orleans.OrleansCodeGenerator.Build --no-restore
dotnet add "${solutionName}Grains/${solutionName}Grains.csproj" reference "${solutionName}Contracts/${solutionName}Contracts.csproj"

dotnet new console --name "${solutionName}Silo" --no-restore
dotnet add "${solutionName}Silo/${solutionName}Silo.csproj" package Microsoft.Orleans.Server --no-restore
dotnet add "${solutionName}Silo/${solutionName}Silo.csproj" package Microsoft.Extensions.Logging.Console --no-restore
dotnet add "${solutionName}Silo/${solutionName}Silo.csproj" package OrleansDashboard --no-restore
dotnet add "${solutionName}Silo/${solutionName}Silo.csproj" reference "${solutionName}Contracts/${solutionName}Contracts.csproj"
dotnet add "${solutionName}Silo/${solutionName}Silo.csproj" reference "${solutionName}Grains/${solutionName}Grains.csproj"
$siloCs = [IO.File]::ReadAllText("$PWD/${solutionName}Silo/Program.cs")
$newSiloMain = @"
        public static async Task Main(string[] args)
        {
            var siloBuilder = new SiloHostBuilder()
                .UseLocalhostClustering()
                .UseDashboard(options => { })
                .Configure<ClusterOptions>(options =>
                {
                    options.ClusterId = "dev";
                    options.ServiceId = "${solutionName}";
                })
                .Configure<EndpointOptions>(options =>
                    options.AdvertisedIPAddress = IPAddress.Loopback)
                .ConfigureLogging(logging => logging.AddConsole());

            using (var host = siloBuilder.Build())
            {
                await host.StartAsync();

                Console.ReadLine();
            }
        }
"@
"using Microsoft.Extensions.Logging;", "using Orleans;", "using Orleans.Configuration;", "using Orleans.Hosting;", "using System.Net;", "using System.Threading.Tasks;", ([regex]'(?m)static void Main[^}]*?}').Replace($siloCs, $newSiloMain) | Out-File -enc ASCII "${solutionName}Silo/Program.cs"
"Placed tutorial silo Main"
$xdoc = [xml](gc "$PWD/${solutionName}Silo/${solutionName}Silo.csproj")
[void]$xdoc.Project.PropertyGroup.AppendChild($xdoc.CreateElement("LangVersion"))
$xdoc.Project.PropertyGroup.LangVersion = "latest"
$xdoc.Save("$PWD/${solutionName}Silo/${solutionName}Silo.csproj")
"set Silo to use latest C# (for async Main)"

dotnet new webapi --name "${solutionName}Client" --no-restore
dotnet add "${solutionName}Client/${solutionName}Client.csproj" package Microsoft.Orleans.Client --no-restore
dotnet add "${solutionName}Client/${solutionName}Client.csproj" package Microsoft.Extensions.Logging.Console --no-restore
dotnet add "${solutionName}Client/${solutionName}Client.csproj" reference "${solutionName}Contracts/${solutionName}Contracts.csproj"
$clientCs = [IO.File]::ReadAllText("$PWD/${solutionName}Client/Startup.cs")
$newCreateClientCode = @"
        private IClusterClient CreateOrleansClient()
        {
            var clientBuilder = new ClientBuilder()
                .UseLocalhostClustering()
                .Configure<ClusterOptions>(options =>
                {
                    options.ClusterId = "dev";
                    options.ServiceId = "${solutionName}";
                })
                .ConfigureLogging(logging => logging.AddConsole());

            var client = clientBuilder.Build();
            client.Connect(async ex =>
                {  // replace Console with actual logging
                    Console.WriteLine(ex);
                    Console.WriteLine("Retrying...");
                    await Task.Delay(3000);
                    return true;
                }
                ).Wait();

            return client;
        }
"@
$newClientCode = ([regex]'(?m)(public Startup\([^}]*?})').Replace($clientCs, "`$1`r`n`r`n$newCreateClientCode")
$newDIClientCode = @"
var orleansClient = CreateOrleansClient();
            services.AddSingleton<IClusterClient>(orleansClient);

            `$1
"@
$newClientCode = ([regex]'(?m)(services\.AddMvc)').Replace($newClientCode, $newDIClientCode)
"using Orleans;",
"using Orleans.Configuration;",
"using System.Net;",
$newClientCode |
    Out-File -enc ASCII "${solutionName}Client/Startup.cs"




dotnet new sln --name ${solutionName}
dotnet sln "${solutionName}.sln" add "${solutionName}Contracts/${solutionName}Contracts.csproj"
dotnet sln "${solutionName}.sln" add "${solutionName}Grains/${solutionName}Grains.csproj"
dotnet sln "${solutionName}.sln" add "${solutionName}Silo/${solutionName}Silo.csproj"
dotnet sln "${solutionName}.sln" add "${solutionName}Client/${solutionName}Client.csproj"

dotnet build