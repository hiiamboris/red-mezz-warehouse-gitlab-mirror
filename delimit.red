Red [
	title:   "DELIMIT & INTERLEAVE functions"
	purpose: "Insert a delimiter between all items in a list or interleave two lists"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %reshape.red

interleave: delimit: none
context [
	;@@ use map-each when it's native instead of this mess
	
	in-list:  make [] group: 128
	out-list: make [] group * 2
	i: repeat i group [
		repend out-list [quote :delim to get-word! rejoin ["i" i]]
		append in-list to word! rejoin ["i" i]
	]
	
	set 'delimit function [
		"Insert delimiter between all items in the list"
		list  [any-list!]										;@@ `reduce` and `set` don't work on strings... hence the type limitation
		delim [any-type!]
		/evenly "Also add a trailing delimiter"
		/into result [any-list!]
		; /into result: (make block! 2 * length? list) [any-list!]
	] reshape [
		unless result [result: make block! 2 * length? list]	;-- by design makes a block, not type-of list, for better performance
		if tail? list [return result]
		append/only result :list/1
		n: (length? list) - 1
		if 0 < trail: n % @(group) [
			set (skip @[in-list] rest: @(group) - trail) next list
			reduce/into (skip @[out-list] rest * 2) tail result
		]
		foreach @[in-list] skip list 1 + trail [
			reduce/into @[out-list] tail result					;@@ lists are inlined so the func is easy to copy, but it hurts readability
		]
		if evenly [append/only result :delim]
		result
	]
]

#assert [
	[           ] =  delimit [     ] '-
	[1          ] =  delimit [1    ] '-
	[1 - 2      ] =  delimit [1 2  ] '-
	[1 - 2 - 3  ] =  delimit [1 2 3] '-
	[1 - 2 - 3  ] == delimit to hash! [1 2 3] '-
	[           ] =  delimit/evenly [     ] '-
	[1 -        ] =  delimit/evenly [1    ] '-
	[1 - 2 -    ] =  delimit/evenly [1 2  ] '-
	[1 - 2 - 3 -] =  delimit/evenly [1 2 3] '-
]

context [												;-- this is a similar design, just uses list items instead of the delimiter
	in1-list: make [] group: 128
	in2-list: make [] group
	out-list: make [] group * 2
	i: repeat i group [
		repend out-list [
			to get-word! rejoin ["x" i]
			to get-word! rejoin ["y" i]
		]
		append in1-list to word! rejoin ["x" i]
		append in2-list to word! rejoin ["y" i]
	]
	
	set 'interleave function [									;-- much better name than 'zip' 
		"Interleave the items of two series"
		series1 [any-list!]										;@@ `reduce` and `set` don't work on strings... hence the type limitation
		series2 [any-list!]; (equal? length? series1 length? series2)
		/into result [any-list!]
		; /into result: (make block! 2 * length? series1) [series!]
	] reshape [
		n: length? series1
		unless result [result: make block! 2 * n]
		if zero? n [return result] 
		#assert [equal? length? series1 length? series2]		;@@ accept unequal? fill with 'none'?
		if 0 < trail: n % @(group) [
			rest: @(group) - trail
			set (skip @[in1-list] rest) series1					;@@ lists are inlined so the func is easy to copy, but it hurts readability
			set (skip @[in2-list] rest) series2
			reduce/into (skip @[out-list] rest * 2) tail result
		]
		series1: skip series1 trail
		series2: skip series2 trail
		foreach @[in1-list] series1 [
			set @[in2-list] series2
			series2: skip series2 @(group)
			reduce/into @[out-list] tail result
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
