param($path, $NewtonsoftDllPath="c:\bin\Newtonsoft.Json.dll")

$jsonasm = [Reflection.Assembly]::LoadFrom($NewtonsoftDllPath)
$deserializer = new-object Newtonsoft.Json.JsonSerializer
$textreader = [IO.File]::OpenText($path)
$jsonreader = new-object Newtonsoft.Json.JsonTextReader @($textreader)
#$jsonreader.SupportMultipleContent = $true

while ($jsonreader.Read()) {
	#$jsonreader
	if (($jsonreader.TokenType -eq [Newtonsoft.Json.JsonToken]::StartObject) -or
		(($jsonreader.TokenType -eq [Newtonsoft.Json.JsonToken]::StartArray) -and ($jsonreader.Depth -ne 0))) {
		,$deserializer.Deserialize($jsonreader, [Newtonsoft.Json.Linq.JObject])
		#[Newtonsoft.Json.Linq.JObject]::ReadFrom($jsonreader)
		#$jsonreader
	}
}
$jsonreader.Close() # closes $textreader as well
##$jsonReader