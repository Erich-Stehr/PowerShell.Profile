function ScriptRoot { Split-Path $MyInvocation.ScriptName }
$RestScriptRoot = (ScriptRoot)

if ($NetCred -eq $null) {
$account = "$env:USERDOMAIN\$env:USERNAME"
$PSCred = $host.UI.PromptForCredential('NetCred credentials',  '', $account, $ListsURL) # includes prompt strings unlike Get-Credential
$global:NetCred = $PSCred.GetNetworkCredential()
if (($NetCred.Domain -eq $env:USERDOMAIN) -and ($NetCred.UserName -eq $env:USERNAME)) { $global:localCred = $NetCred } else { $global:localcred = (get-credential "$env:USERDOMAIN\$env:USERNAME").GetNetworkCredential() }
} 

function global:SamlAuthenticatedWebClient([string] $url, [System.Net.WebProxy] $proxy=(new-object System.Net.WebProxy), [System.Net.NetworkCredential] $netCred=$(throw "Must have a network credential for SPO!"))
{
	# methodology from http://allthatjs.com/2012/03/28/remote-authentication-in-sharepoint-online/
	$wc = & "${RestScriptRoot}\New-WebClientWithCookies.ps1"
	$wc.Proxy = $proxy # newly constructed proxy goes local
	if ($null -eq $netCred) { $wc.UseDefaultCredentials = $true } else { $wc.Credentials = $netCred }
	$wc.BaseAddress = $baseUrl
	$wc.Headers.Add("User-Agent", "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)")

	# Request token from STS
	$tokenRequestXml = @"
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"
      xmlns:a="http://www.w3.org/2005/08/addressing"
      xmlns:u="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
  <s:Header>
    <a:Action s:mustUnderstand="1">http://schemas.xmlsoap.org/ws/2005/02/trust/RST/Issue</a:Action>
    <a:ReplyTo>
      <a:Address>http://www.w3.org/2005/08/addressing/anonymous</a:Address>
    </a:ReplyTo>
    <a:To s:mustUnderstand="1">https://login.microsoftonline.com/extSTS.srf</a:To>
    <o:Security s:mustUnderstand="1"
       xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <o:UsernameToken>
        <o:Username>$($netCred.UserName)</o:Username>
        <o:Password>$($netCred.Password)</o:Password>
      </o:UsernameToken>
    </o:Security>
  </s:Header>
  <s:Body>
    <t:RequestSecurityToken xmlns:t="http://schemas.xmlsoap.org/ws/2005/02/trust">
      <wsp:AppliesTo xmlns:wsp="http://schemas.xmlsoap.org/ws/2004/09/policy">
        <a:EndpointReference>
          <a:Address>$url</a:Address>
        </a:EndpointReference>
      </wsp:AppliesTo>
      <t:KeyType>http://schemas.xmlsoap.org/ws/2005/05/identity/NoProofKey</t:KeyType>
      <t:RequestType>http://schemas.xmlsoap.org/ws/2005/02/trust/Issue</t:RequestType>
      <t:TokenType>urn:oasis:names:tc:SAML:1.0:assertion</t:TokenType>
    </t:RequestSecurityToken>
  </s:Body>
</s:Envelope>
"@
	$saml = $wc.UploadString("https://login.microsoftonline.com/extSTS.srf", [System.Text.Encoding]::UTF8.GetBytes($tokenRequestXml))
$saml
	throw "Not yet Implemented"
	return $wc
}

function global:CredAuthenticatedWebClient([string] $baseUrl, [System.Net.WebProxy] $proxy=(new-object System.Net.WebProxy), [System.Net.NetworkCredential] $netCred=$null)
{
	$wc = new-object System.Net.WebClient
	$wc.Proxy = $proxy # newly constructed proxy goes local
	if ($null -eq $netCred) { $wc.UseDefaultCredentials = $true } else { $wc.Credentials = $netCred }
	$wc.BaseAddress = $baseUrl
	return $wc
}

function global:Invoke-RestApi([Net.WebClient]$wc, [string] $relurl)
{
	$wc.DownloadString($relurl)
}

# From http://blogs.technet.com/b/speschka/archive/2013/07/08/how-to-quickly-and-easily-get-a-list-of-fields-in-a-sharepoint-2013-list.aspx
function global:GetListSchema([Net.WebClient]$wc, [string] $listTitle, $netCred = $null)
{
	return Invoke-RestApi($wc, "_api/web/lists/GetByTitle('${listTitle}')/Fields")
}