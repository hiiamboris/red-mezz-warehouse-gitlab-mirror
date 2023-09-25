Red [
	title:   "QUANTIZE function"
	purpose: "Quantize a float sequence into rounded bits"
	author:  @hiiamboris
	license: 'BSD-3
]


; #include %assert.red

quantize: function [
	"Quantize a float sequence into rounded bits, minimizing the overall bias"
	vector [vector! block!]
	/scale quant [number!] "Round to this value instead of 1"
	/floor "Ensure bias is never positive (i.e. final sum does not exceed the original sum, up to FP rounding error)"
][
	quant:  any [quant 1]								;@@ use 'default'
	repend spec: clear [] [
		type?/word quant
		either integer? quant [32][64]
		n: length? vector
	]
	result: make vector! spec							;-- result is a vector of quant type
	error:  0											;-- accumulated rounding error is added to next value
	repeat i n [
		result/:i: hit: round/to/:floor aim: vector/:i + error quant
		error: aim - hit
	]
	result
]

#assert [
	[]          = to [] quantize []
	[1]         = to [] quantize [1.4]
	[2]         = to [] quantize [1.6]
	[1]         = to [] quantize/floor [1.9]
	[1.6]       = to [] quantize/scale [1.69] 0.2
	[1.8]       = to [] quantize/scale [1.71] 0.2
	[1.6]       = to [] quantize/scale/floor [1.71] 0.2
	[1 2]       = to [] quantize [1.4 1.4]
	[2 1]       = to [] quantize [1.51 1.4]
	[1 1]       = to [] quantize/floor [1.51 1.4]
	[1 2]       = to [] quantize/floor [1.51 1.5]
	[160% 140%] = to [] quantize/scale [1.51 1.5] 20%
]