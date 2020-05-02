Red [
	title:   "Extremi-related mezzanines"
	purpose: "Find minimum and maximum points over a series"
	author:  @hiiamboris
	license: 'BSD-3
]

minmax-of: function [
	"Compute [min max] pair along XS"
	xs [block! hash! vector! image! binary! any-string!]
][
	x-: x+: first xs
	foreach x next xs [x-: min x- x  x+: max x+ x]
	reduce [x- x+]
]

minimum-of: func [
	"Find minimum value among XS"
	xs [block! hash! vector! image! binary! any-string!]
][
	first minmax-of xs
]

maximum-of: func [
	"Find minimum value among XS"
	xs [block! hash! vector! image! binary! any-string!]
][
	second minmax-of xs
]
