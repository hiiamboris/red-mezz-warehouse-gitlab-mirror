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

context [
	;; these versions are usually 3-4 times slower
	brute-minimum-of: func [
		"Find minimum value among XS"
		xs [block! hash! vector! image! binary! any-string!]
	][
		first minmax-of xs
	]

	brute-maximum-of: func [
		"Find minimum value among XS"
		xs [block! hash! vector! image! binary! any-string!]
	][
		second minmax-of xs
	]

	containers: object [
		block!:  make system/words/block!  50
		hash!:   make system/words/block!  50
		vector!: make system/words/vector! 50
		string!: make system/words/string! 50
		email!:  make system/words/string! 50
		file!:   make system/words/string! 50
		ref!:    make system/words/string! 50
		url!:    make system/words/string! 50
		binary!: make system/words/binary! 50
		;; not for image! and tag! - those should use the brute version
	]

	set 'minimum-of func [
		"Find minimum value among XS"
		xs [block! hash! vector! image! binary! any-string!]
	][
		either buf: select containers type?/word :xs [
			also first sort append buf xs
				clear buf
		][	brute-minimum-of xs
		]
	]

	set 'maximum-of func [
		"Find minimum value among XS"
		xs [block! hash! vector! image! binary! any-string!]
	][
		either buf: select containers type?/word :xs [
			also last sort append buf xs
				clear buf
		][	brute-maximum-of xs
		]
	]
]
