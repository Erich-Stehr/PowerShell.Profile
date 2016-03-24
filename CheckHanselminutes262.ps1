param([int] $showNumber=$($x = [IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Path);$x.Substring($x.Length-3)))
$wc = new-object System.Net.WebClient
&{
	trap { break; }
	${showNumber}
	#$wc.DownloadFile("http://perseus.franklins.net/hanselminutes_0$showNumber.pdf", 
    $wc.DownloadFile("http://s3.amazonaws.com/hanselminutes/hanselminutes_0${showNumber}.pdf",
		"$((resolve-path ~\Desktop).path)\hanselminutes_0$showNumber.pdf")
	dir "~\Desktop\hanselminutes_0$showNumber.pdf"
}