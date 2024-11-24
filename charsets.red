Red [
	title:   "Common charsets"
	author:  @hiiamboris
	license: 'BSD-3
]

charsets: context [
	space:				charset " "
	non-space:			negate space
	space+tab:			charset " ^-"
	non-space+tab:		negate space+tab
	white:				charset " ^-^/^M"
	non-white:			negate white
	digit:				charset [#"0" - #"9"]
	nonzero-digit:		charset [#"1" - #"9"]
	non-digit:			negate digit
	hex-digit:			charset [#"0" - #"9" #"a" - #"f" #"A" - #"F"]
	hex-digit-lower:	charset [#"0" - #"9" #"a" - #"f"]
	hex-digit-upper:	charset [#"0" - #"9" #"A" - #"F"]
	alpha:				charset [#"a" - #"z" #"A" - #"Z"]
	alpha-lower:		charset [#"a" - #"z"]
	alpha-upper:		charset [#"A" - #"Z"]
	alpha+digit:		union alpha digit
	; uni-alpha: ...
	printable: 			charset [not 0 - 31 127]				;-- reference: https://en.wikipedia.org/wiki/Graphic_character
]