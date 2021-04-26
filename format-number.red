Red [
	title:   "FORMAT-NUMBER mezzanine"
	purpose: "Simple number formatter with the ability to control integer & fractional parts size"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		Use case: timestamps and other sort-friendly output
			For more advanced output see FORMAT-READABLE or Gregg's formatting repository
			
		Limitation:
			Does not round the incoming number, just truncates it
			(that would produce adverse effects in TIMESTAMP, e.g. 60 seconds when it's 59.9995)
	}
]

;@@ TODO: tests

format-number: function [
	"Format a number"
	num      [number!]
	integral [integer!] "Minimal size of integral part (>0 to pad with zero, <0 to pad with space)"
	frac     [integer!] "Exact size of fractional part (0 to remove it, >0 to enforce it, <0 to only use it for non-integer numbers)"
][
	frac: either integer? num [max 0 frac][absolute frac]	;-- support for int/float automatic distinction
	r: form num
	if percent? num [take/last r]						;-- temporarily remove the suffix
	dot: any [find r #"."  tail r]
	if 0 < n: (absolute integral) + 1 - index? dot [	;-- pad the integral part
		char: pick "0 " integral >= 0
		insert/dup r char n
		dot: skip dot n
	]
	clear either frac > 0 [								;-- pad the fractional part
		dot: change dot #"."
		append/dup r #"0" frac - length? dot
		skip dot frac
	][
		dot
	]
	if percent? num [append r #"%"]
	r
]
