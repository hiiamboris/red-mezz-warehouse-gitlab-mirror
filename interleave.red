Red [
	title:    "DELIMIT & INTERLEAVE functions"
	purpose:  "Insert a delimiter between all items in a list or interleave two lists"
	author:   @hiiamboris
	license:  BSD-3
	provides: interleave
	depends:  reshape
]

; #include %reshape.red

interleave: context [											;-- this is a similar design, just uses list items instead of the delimiter
	;@@ use map-each when it's native instead of this mess
	in1-list: make [] group: 128
	in2-list: make [] group
	mix-list: make [] group * 2
	dlm-list: make [] group * 2
	i: repeat i group [
		append in1-list to word! rejoin ["x" i]
		append in2-list to word! rejoin ["y" i]
		repend mix-list [
			to get-word! rejoin ["x" i]
			to get-word! rejoin ["y" i]
		]
		repend dlm-list [
			to get-word! rejoin ["x" i]
			quote :series2
		]
	]
	
	;; lists are inlined in this function for two reasons:
	;; - so all the words become local to it (for reentrancy)
	;; - so the func is easy to copy
	;; but it hurts readability badly...
	return function [ 
		"Interleave the items of two series"
		series1 [any-list!]										;@@ `reduce` and `set` don't work on strings... hence the type limitation
		series2 [any-type!] "When not a list, repeated as a single value"
		/between "Treat  series2 as a single value and omit it at the tail"
		/into result [any-list!] "Provide an output buffer"
		; /into result: (make block! 2 * length? series1) [series!]
	] reshape [
		n: length? series1
		unless result [result: make block! 2 * n]
		if zero? n [return result] 
		; #assert [any [between  equal? length? series1 length? series2]]	;@@ accept unequal? fill with 'none'?
		either any [between not any-list? :series2] [			;-- delimit mode
			if 0 < trail: n % @(group) [
				rest: @(group) - trail
				set (skip @[in1-list] rest) series1
				reduce/into (skip @[dlm-list] rest * 2) tail result
			]
			series1: skip series1 trail
			foreach @[in1-list] series1 [
				reduce/into @[dlm-list] tail result
			]
			if between [take/last result]
		][														;-- interleave mode
			if 0 < trail: n % @(group) [
				rest: @(group) - trail
				set (skip @[in1-list] rest) series1
				set (skip @[in2-list] rest) series2
				reduce/into (skip @[mix-list] rest * 2) tail result
			]
			series1: skip series1 trail
			series2: skip series2 trail
			foreach @[in1-list] series1 [
				set @[in2-list] series2
				series2: skip series2 @(group)
				reduce/into @[mix-list] tail result
			]
		]
		result
	]
]

#assert [
	[         ] = interleave [   ] [   ]
	[1 2      ] = interleave [1  ] [2  ]
	[1 2 3 4  ] = interleave [1 3] [2 4]
	[1 2 3 4  ] = interleave to hash!  [1 3] to hash!  [2 4]
	[1 2 3 4  ] = interleave to paren! [1 3] to paren! [2 4]
	(quote (1 2 3 4)) == interleave/into to paren! [1 3] to paren! [2 4] to paren! []
	; probe interleave repeat i 200 [append [] i] repeat i 200 [append [] i + 1000]
	[           ] =  interleave/between [     ] '-
	[1          ] =  interleave/between [1    ] '-
	[1 - 2      ] =  interleave/between [1 2  ] '-
	[1 - 2 - 3  ] =  interleave/between [1 2 3] '-
	[1 - 2 - 3  ] == interleave/between to hash! [1 2 3] '-
	[           ] =  interleave [     ] '-
	[1 -        ] =  interleave [1    ] '-
	[1 - 2 -    ] =  interleave [1 2  ] '-
	[1 - 2 - 3 -] =  interleave [1 2 3] '-
]


comment {
	;; these simple versions become slower after 10 items, and up to 4x slower after 100 items
	;; only append variant does not require an intermediate buffer for string output, but it's a tiny speedup
	
	delimit1: function [
		"Insert delimiter between all items in the list"
		list      [any-list!]
		delimiter [any-type!]
		/into result: (make block! 2 * length? list) [series!]
	][
		parse list [collect after result [keep skip any [end | keep (:delimiter) keep skip]]]
		result
	]
	
	delimit2: function [
		"Insert delimiter between all items in the list"
		list      [any-list!]
		delimiter [any-type!]
		/into result: (make block! 2 * length? list) [series!]
	][
		append/only result :list/1
		foreach item next list [append/only append/only result :delimiter :item]
		result
	]
	
	delimit3: function [
		"Insert delimiter between all items in the list"
		list  [any-list!]
		delim [any-type!]
		/into result: (make block! 2 * length? list) [series!]
	] reshape [
		append/only result :list/1
		foreach item next list [reduce/into [:delimiter :item] tail result]
		result
	]
}
