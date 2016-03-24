"Error count = $($Error.Count)"
try { throw "foo" } catch {"Caught!"} finally {"Done!"} ; "Carry on"
"Error count = $($Error.Count)"
try { throw "foo continue" } catch {"Caught! continue"; continue} finally {"Done! continue"} ; "Carry on continue" # both break and continue stop script!
"Error count = $($Error.Count)"
try { throw "foo break" } catch {"Caught! break"; break} finally {"Done! break"} ; "Carry on break"
"Error count = $($Error.Count)"
