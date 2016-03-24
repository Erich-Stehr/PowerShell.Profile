$doc = new-object Xml.XmlDocument
$global:SharePointFeatures = dir 'C:\Program Files\Common Files\Microsoft Shared\web server extensions\12\TEMPLATE\FEATURES' | #'AddDashboard\Feature.xml'
	% {  $doc.Load( "$($_.FullName)\Feature.xml"); $doc.Feature.SetAttribute("FeatureName", $_.name); $doc} |
	select @{n='FeatureName';e={$_.Feature.FeatureName}},@{n='FeatureId';e={$_.Feature.Id}},@{n='FeatureScope';e={$_.Feature.Scope}} |
	sort FeatureID
$SharePointFeatures