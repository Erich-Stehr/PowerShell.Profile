#cx	ĉ	U+0109
#gx	ĝ	U+011d
#hx	ĥ	U+0125
#jx	ĵ	U+0135
#sx	ŝ	U+015d	
#ux	ŭ	U+016d
#Ux	Ŭ	U+016c
#Cx	Ĉ	U+0108
#Gx	Ĝ	U+011c
#Hx	Ĥ	U+0124
#Jx	Ĵ	U+0134
#Sx	Ŝ	U+015c

filter FromEsperantoXMethod()
{
	$_ -creplace 'cx',([char]0x0109) -ireplace 'cx',([char]0x0108) -creplace 'gx',([char]0x011d) -ireplace 'gx',([char]0x011c) -creplace 'hx',([char]0x0125)  -ireplace 'hx',([char]0x0124) -creplace 'jx',([char]0x0135) -ireplace 'jx',([char]0x0134) -creplace 'sx',([char]0x015d) -ireplace 'sx',([char]0x015c) -creplace 'ux',([char]0x016d) -ireplace 'ux',([char]0x016c)

}