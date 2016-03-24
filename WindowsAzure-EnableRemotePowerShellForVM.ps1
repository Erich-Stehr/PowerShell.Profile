# https://github.com/sandrinodimattia/WindowsAzure-EnableRemotePowerShellForVM
param 
(
	[string]$publishProfilePath = $(throw "publishProfilePath is required."), 
	[string]$subscriptionId = $(throw "subscriptionId is required."), 
	[string]$cloudServiceName = $(throw "cloudServiceName is required."),
	[string]$vmName = $(throw "vmName is required.")
)

$assemblies = ( 
    "System",
    "System.Xml",
    "System.Data",
    "System.Core",
    "System.Xml.Linq",
    "System.Data.DataSetExtensions",
    "Microsoft.CSharp"
    ) 

$source = @" 
using System;
using System.IO;
using System.Net;
using System.Linq;
using System.Xml.Linq;
using System.Net.Security;
using System.Collections.Generic;
using System.Security.Cryptography.X509Certificates;

public static class VirtualMachineRemotePowerShell
{
	private static readonly XNamespace XmlnsWindowsAzure = "http://schemas.microsoft.com/windowsazure";
	private static readonly XNamespace XmlnsInstance = "http://www.w3.org/2001/XMLSchema-instance";

	/// <summary>
	/// Enable remote PowerShell by finding the public port for Remote PowerShell, downloading the HTTPS certificate and installing it locally in the trusted root.
	/// </summary>
	/// <param name="publishSettingsPath"></param>
	/// <param name="subscriptionName"></param>
	/// <param name="cloudServiceName"></param>
	/// <param name="virtualMachineName"></param>
	public static void Enable(string publishSettingsPath, string subscriptionName, string cloudServiceName, string virtualMachineName)
	{
		Console.WriteLine("\r\n  Enabling Remote PowerShell on {0} for {1} (in {2}.cloudapp.net)\r\n", Environment.MachineName, virtualMachineName, cloudServiceName);

		var certificate = GetCertificateFromPublishProfile(publishSettingsPath);
		var subscriptionId = GetSubscriptionId(publishSettingsPath, subscriptionName);
		using (var cloudServiceDescription = GetCloudService(certificate, subscriptionId, cloudServiceName))
		{
			var remotePowerShellPort = GetPublicPort(cloudServiceDescription, virtualMachineName, 5986);
			Console.WriteLine("   > Found remote port: " + remotePowerShellPort);

			var remotePowerShellUrl = String.Format("https://{0}.cloudapp.net:{1}", cloudServiceName, remotePowerShellPort);
			Console.WriteLine("   > Fetching certificate from: {0}", remotePowerShellUrl);

			DownloadAndInstallCertificate(remotePowerShellUrl);

			Console.WriteLine("\r\n  You can now use one of the following commands to connect to your session\r\n");
			Console.WriteLine("     Enter-PSSession -ComputerName {0}.cloudapp.net -Port {1} -Credential <myUsername> -UseSSL", cloudServiceName, remotePowerShellPort);
			Console.WriteLine("     Invoke-Command -ConnectionUri https://{0}.cloudapp.net:{1} -Credential <myUsername> -ScriptBlock {{ dir c:\\ }}\r\n", cloudServiceName, remotePowerShellPort);
		}
	}

	/// <summary>
	/// Parse the publish profile to get the certificate.
	/// </summary>
	/// <param name="publishProfilePath"></param>
	/// <returns></returns>
	private static X509Certificate2 GetCertificateFromPublishProfile(string publishProfilePath)
	{
		Console.WriteLine("   > Loading certificate from publish profile: {0}", publishProfilePath);

		return new X509Certificate2(Convert.FromBase64String(
			XDocument.Load(publishProfilePath).Descendants("PublishProfile").Single().Attribute("ManagementCertificate").Value));
	}

	/// <summary>
	/// Get the subscription ID.
	/// </summary>
	/// <param name="publishProfilePath"></param>
	/// <param name="subscriptionName"></param>
	/// <returns></returns>
	private static string GetSubscriptionId(string publishProfilePath, string subscriptionName)
	{
		Console.WriteLine("   > Loading subscription ID from publish profile: {0}", publishProfilePath);

		var subscription = XDocument.Load(publishProfilePath).Descendants("PublishProfile").Single().Elements("Subscription").Where(s => s.HasAttributes && s.Attribute("Name").Value == subscriptionName).SingleOrDefault();
		if (subscription == null)
			throw new InvalidOperationException("Unable to find subscription: " + subscriptionName);
		return subscription.Attribute("Id").Value;
	}

	/// <summary>
	/// Get the description of the Cloud Service from the management API.
	/// </summary>
	/// <param name="certificate"></param>
	/// <param name="subscriptionId"></param>
	/// <param name="cloudServiceName"></param>
	/// <returns></returns>
	private static Stream GetCloudService(X509Certificate2 certificate, string subscriptionId, string cloudServiceName)
	{
		Console.WriteLine("   > Loading Cloud Service: {0}", cloudServiceName);
		Console.WriteLine("      - Subscription ID: {0}", subscriptionId);
		var request = (HttpWebRequest)WebRequest.Create(
			String.Format("https://management.core.windows.net/{0}/services/hostedservices/{1}/deploymentslots/{2}",
			subscriptionId, cloudServiceName, "Production"));
		request.Headers["x-ms-version"] = "2012-03-01";
		request.ClientCertificates.Add(certificate);
		return request.GetResponse().GetResponseStream();
	}

	/// <summary>
	/// Get the public port for a specific 
	/// </summary>
	/// <param name="cloudServiceXml"></param>
	/// <param name="virtualMachine"></param>
	/// <param name="internalPort"></param>
	/// <returns></returns>
	private static string GetPublicPort(Stream cloudServiceXml, string virtualMachine, int internalPort)
	{
		using (var response = cloudServiceXml)
		{
			var document = XDocument.Load(response);

			// Get the role.
			var role = document.Root.GetElement("RoleList").GetElements("Role")
				.Where(r => r.GetElement("RoleName") != null && r.GetElement("RoleName").Value == virtualMachine && r.IsOfType("PersistentVMRole"))
				.SingleOrDefault();
			if (role == null)
				throw new InvalidOperationException("Unable to find Virtual Machine: " + virtualMachine);

			Console.WriteLine("   > Found Virtual Machine: {0}", virtualMachine);

			// Get the network configuration.
			var networkConfigurationSet = role.GetElement("ConfigurationSets").GetElements("ConfigurationSet").Where(c => c.IsOfType("NetworkConfigurationSet"))
				.SingleOrDefault();
			if (networkConfigurationSet == null)
				throw new InvalidOperationException("Could not find NetworkConfigurationSet for Virtual Machine: " + virtualMachine);

			// Get the endpoints.
			var endpoint = networkConfigurationSet.GetElement("InputEndpoints").GetElements("InputEndpoint")
				.Where(e => GetElement(e, "LocalPort") != null && GetElement(e, "LocalPort").Value == internalPort.ToString()).SingleOrDefault();
			if (endpoint == null)
				throw new InvalidOperationException("Could not find the a public endpoint matching the internal port " + internalPort + " for Virtual Machine: " + virtualMachine);

			// Get the remote port.
			var remotePort = GetElement(endpoint, "Port").Value;
			return remotePort;
		}
	}

	/// <summary>
	/// Install the certificate.
	/// </summary>
	/// <param name="url"></param>
	private static void DownloadAndInstallCertificate(string url)
	{
		ServicePointManager.ServerCertificateValidationCallback += OnServerCertificateValidationCallback;

		// Build the request and initialize the response to get the certificate.
		var request = HttpWebRequest.Create(url) as HttpWebRequest;
		HttpWebResponse response = null;

		try
		{
			// This will return a 404, whichi is normal.
			response = request.GetResponse() as HttpWebResponse;
		}
		catch
		{

		}

		string file = Path.GetTempFileName();

		// Download the certificate.
		var certificate = request.ServicePoint.Certificate.Export(X509ContentType.Cert);
		File.WriteAllBytes(file, certificate);

		Console.WriteLine("   > Downloaded certificate: {0}", request.ServicePoint.Certificate.Subject);

		// Install the certificate.
		InstallCertificateInTrustedRoot(file);

		// Clean up the file.
		File.Delete(file);

		// Reset the certificate validation.
		ServicePointManager.ServerCertificateValidationCallback -= OnServerCertificateValidationCallback;
	}

	/// <summary>
	/// Install the certificate in the trusted root store.
	/// </summary>
	/// <param name="filePath"></param>
	private static void InstallCertificateInTrustedRoot(string filePath)
	{
		// Install it.
		var rootStore = new X509Store(StoreName.Root, StoreLocation.CurrentUser);
		rootStore.Open(OpenFlags.ReadWrite);
		rootStore.Add(new X509Certificate2(X509Certificate2.CreateFromCertFile(filePath)));
		rootStore.Close();

		Console.WriteLine("   > Certificate has been imported, You can now connect from this machine!");
	}

	/// <summary>
	/// The certificate is self signed, so skiup the validation.
	/// </summary>
	/// <param name="sender"></param>
	/// <param name="certificate"></param>
	/// <param name="chain"></param>
	/// <param name="policyErrors"></param>
	/// <returns></returns>
	private static bool OnServerCertificateValidationCallback(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors policyErrors)
	{
		return true;
	}

	/// <summary>
	/// Helper method to get an element.
	/// </summary>
	/// <param name="element"></param>
	/// <param name="name"></param>
	/// <returns></returns>
	private static XElement GetElement(this XElement element, string name)
	{
		return element.Element(XmlnsWindowsAzure + name);
	}

	/// <summary>
	/// Helper method to get a list of elements.
	/// </summary>
	/// <param name="element"></param>
	/// <param name="name"></param>
	/// <returns></returns>
	private static IEnumerable<XElement> GetElements(this XElement element, string name)
	{
		return element.Elements(XmlnsWindowsAzure + name);
	}

	/// <summary>
	/// Check the type of a specific element.
	/// </summary>
	/// <param name="element"></param>
	/// <param name="type"></param>
	/// <returns></returns>
	private static bool IsOfType(this XElement element, string type)
	{
		return element.HasAttributes && element.Attributes().Any(a => a.Name == XmlnsInstance + "type" && a.Value == type);
	}
}
"@ 

if ($VirtualMachineRemotePowerShellTypeAdded -ne 1)
{
	Add-Type -ReferencedAssemblies $assemblies -TypeDefinition $source -Language CSharp  
	New-Variable -Name VirtualMachineRemotePowerShellTypeAdded -Value 1 -Scope "Global"
}

[VirtualMachineRemotePowerShell]::Enable($publishProfilePath, $subscriptionId, $cloudServiceName, $vmName)
