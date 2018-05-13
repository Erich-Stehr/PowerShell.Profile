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

dotnet new webapi --name "${solutionName}Client" --no-restore
dotnet add "${solutionName}Client/${solutionName}Client.csproj" package Microsoft.Orleans.Client --no-restore
dotnet add "${solutionName}Client/${solutionName}Client.csproj" package Microsoft.Extensions.Logging.Console --no-restore
dotnet add "${solutionName}Client/${solutionName}Client.csproj" reference "${solutionName}Contracts/${solutionName}Contracts.csproj"

dotnet new sln --name ${solutionName}
dotnet sln "${solutionName}.sln" add "${solutionName}Contracts/${solutionName}Contracts.csproj"
dotnet sln "${solutionName}.sln" add "${solutionName}Grains/${solutionName}Grains.csproj"
dotnet sln "${solutionName}.sln" add "${solutionName}Silo/${solutionName}Silo.csproj"
dotnet sln "${solutionName}.sln" add "${solutionName}Client/${solutionName}Client.csproj"

dotnet build