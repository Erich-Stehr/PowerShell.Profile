# Seq.psm1

function Open-Seq ([string] $url, [string] $apiKey, $properties = @{})
{
  return @{ Url = $url; ApiKey = $apiKey; Properties = $properties.Clone() }
}
  
function Send-SeqEvent (
    $seq,
    [string] $text,
    [string] $level,
    $properties = @{},
    [switch] $template,
    [System.Exception] $exception = $null)
{
  if (-not $level) {
    $level = 'Information'
  }
   
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

  $ex = "null";
  if ($exception) {
    $ex = ($exception.ToString() | ConvertTo-Json)
  }
  
  $body = "{""Events"": [ {
    ""Timestamp"": ""$([System.DateTimeOffset]::Now.ToString('o'))"",
    ""Level"": ""$level"",
    ""Exception"": $ex,
    ""MessageTemplate"": $($messageTemplate | ConvertTo-Json),
    ""Properties"": $($allProperties | ConvertTo-Json) }]}"
  
  $target = "$($seq["Url"])/api/events/raw?apiKey=$($seq["ApiKey"])"
  
  Invoke-RestMethod -Uri $target -Body $body -ContentType "application/json" -Method POST
}