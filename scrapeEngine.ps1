switch ($env:COREXTBRANCH) {
	'lab18_dev' {$loc = "${env:INETROOT}\private\Relevancy"; break}
	'main~empty' {$loc = "${env:INETROOT}\private\packages\ARES.Product\src"; break}
	default {$loc = (ScriptRoot)}
}
dir $loc -rec -filter ScraperService.exe.* | ? {$_.FullName -notmatch "test|obj|bin" } | select-string $args[0]
