try {
	$wc = New-Object WebClientEx
	return $wc
} catch {
	$code = @"
	using System;
	using System.Net;
	
	// From http://stackoverflow.com/questions/1777221/using-cookiecontainer-with-webclient-class
	// Modified to expose Cookies with usable name, allowing test and removing warning
public class WebClientEx : WebClient
{
    public CookieContainer Cookies;

    public WebClientEx(CookieContainer cookies)
    {
        this.Cookies = cookies;
    }
	
	public WebClientEx()
	{
		this.Cookies = new CookieContainer();
	}

    protected override WebRequest GetWebRequest(Uri address)
    {
        WebRequest r = base.GetWebRequest(address);
        var request = r as HttpWebRequest;
        if (request != null)
        {
            request.CookieContainer = Cookies;
        }
        return r;
    }

    protected override WebResponse GetWebResponse(WebRequest request, IAsyncResult result)
    {
        WebResponse response = base.GetWebResponse(request, result);
        ReadCookies(response);
        return response;
    }

    protected override WebResponse GetWebResponse(WebRequest request)
    {
        WebResponse response = base.GetWebResponse(request);
        ReadCookies(response);
        return response;
    }

    private void ReadCookies(WebResponse r)
    {
        var response = r as HttpWebResponse;
        if (response != null)
        {
            CookieCollection cookies = response.Cookies;
            this.Cookies.Add(cookies);
        }
    }
}
"@ 
	Add-Type -TypeDefinition $code -Language CSharpVersion3 -referencedAssemblies "System.Net"
	$wc = New-Object WebClientEx
	return $wc
}


<#
.SYNOPSIS
	Compiles new subclass of System.Net.WebClient using CookieContainer
.DESCRIPTION
	http://stackoverflow.com/questions/1777221/using-cookiecontainer-with-webclient-class
.INPUTS
	Does not accept pipelined inputs
.OUTPUTS
	[WebClientEx] object
.EXAMPLE
#>
