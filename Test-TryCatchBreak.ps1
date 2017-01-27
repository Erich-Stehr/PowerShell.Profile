"Error count = $($Error.Count)"
try { throw "foo" } catch {"Caught!"} finally {"Done!"} ; "Carry on"
"Error count = $($Error.Count)"
try { Write-Error "test Write-Error" } catch {"Caught! Write-Error"} finally {"Done! Write-Error"} ; "Carry on Write-Error"
#"Error count = $($Error.Count)"
#try { Write-Error "test Write-Error" -ea Stop} catch {"Caught! Write-Error -ea Stop"} finally {"Done! Write-Error -ea Stop"} ; "Carry on Write-Error -ea Stop" # doesn't even write, let alone stop, but does catch
"Error count = $($Error.Count)"
try { throw "foo continue" } catch {"Caught! continue"; continue} finally {"Done! continue"} ; "Carry on continue" # both break and continue stop script!
"Error count = $($Error.Count)"
try { throw "foo break" } catch {"Caught! break"; break} finally {"Done! break"} ; "Carry on break"
"Error count = $($Error.Count)"
