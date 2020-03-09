# Seq.psm1

function Open-Seq ([string] $url, [string] $apiKey, $properties = @{})
{
  return @{ Url = $url; ApiKey = $apiKey; Properties = $properties.Clone() }
}
# $seq = Open-Seq "http://localhost:5341/" -properties @{ Machine = $env:ComputerName }
function Send-SeqEvent (
    $seq,
    [string] $text,
    [string] $level,
    $properties = @{},
    [switch] $template,
    [System.Exception] $exception = $null,
    [switch] $clef)
{
  if (@('Verbose', 'Debug', 'Information', 'Warning', 'Error', 'Fatal') -notcontains $level) {
    $level = 'Information'
  }
  
  $allProperties = $seq["Properties"].Clone()
  $allProperties += $properties
  
  $messageTemplate = "{Text}"
  
  if ($template) {
    $messageTemplate = $text;
  } else {
    $allProperties += @{ Text = $text; }
  }

  if (!$clef) {
    $ex = "null";
    if ($exception) {
      $ex = ($exception.ToString() | ConvertTo-Json)
    }
    $global:body = "{""Events"": [ {
      ""Timestamp"": ""$([System.DateTimeOffset]::Now.ToString('o'))"",
      ""Level"": ""$level"",
      ""Exception"": $ex,
      ""MessageTemplate"": $($messageTemplate | ConvertTo-Json),
      ""Properties"": $($allProperties | ConvertTo-Json) }]}"
  } else {
    $clefObj = [ordered]@{}
    $clefObj["@t"] = [System.DateTimeOffset]::Now.ToString('o')
    $clefObj["@l"] = $level
    if ($exception) {
      $clefObj["@x"] = $ex
    }
    $clefObj["@mt"] = $messageTemplate
    $clefObj += $allProperties
    $global:body = ConvertTo-Json -InputObject $clefObj -Compress 
  }

  Write-Verbose -Verbose $body

  $global:uribuilder = New-Object UriBuilder @($seq["Url"])
  $uribuilder.Path = "api/events/raw"
  $queryComponents = @()
  if ($clef) {
    $queryComponents += "clef"
  }
  if ($seq["ApiKey"]) {
    $queryComponents += "apiKey=$($seq["ApiKey"])"
  }
  $uribuilder.Query = [string]::Join("&", $queryComponents)

  Write-Verbose -Verbose $uribuilder.ToString()
  
  Invoke-RestMethod -Uri $uribuilder.ToString() -Body $body -ContentType "application/json" -Method POST
}
# Send-SeqEvent $seq "Hello from PowerShell"
# Send-SeqEvent $seq "Something is broken!" -level Error -properties @{ User = $env:Username }
# Send-SeqEvent $seq "Leonard is {Age}" -properties @{ Age = 42 } -template
