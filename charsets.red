Red [
	title:    "Common charsets"
	author:   @hiiamboris
	license:  BSD-3
	provides: charsets
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
	;; excluded from uni-white are: 00A0 - NO-BREAK SPACE, 202F - NARROW NO-BREAK SPACE, because they're supposed to be part of the word
	uni-white:			union white charset "^(1680)^(2000)^(2001)^(2002)^(2003)^(2004)^(2005)^(2006)^(2007)^(2008)^(2009)^(200A)^(2028)^(2029)^(205F)^(3000)"
	printable: 			charset [not 0 - 31 127]				;-- reference: https://en.wikipedia.org/wiki/Graphic_character
]

