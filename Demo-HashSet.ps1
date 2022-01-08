$hsa = New-GenericOf -type string
$hsb = New-GenericOf -type string
$hsa.Add("a")
$hsa.Add("b")
$hsa.Add("c")
$hsb.Add("b")
$hsb.Add("c")
$hsb.Add("d")
$hsb.Add("d")
$hsa.Count # 3
$hsb.Count # 3
#$hsac = $hsa.Clone() # Creates Object[] instead of HashSet``1
#$hsac.Count # 3
$hsa.IntersectWith($hsb)
$hsa.Count # 2
#$hsac.Count # 3
$hsa # b c
$hsac # a b c
$hsa = New-Object "System.Collections.Generic.HashSet``1[String]"
$hsa.Add("a")
$hsa.Add("b")
$hsa.Add("c")
$hsac = New-Object "System.Collections.Generic.HashSet``1[String]" @(,$hsa)
$hsa.ExceptWith($hsb)
$hsa.Count # 1
$hsa # a