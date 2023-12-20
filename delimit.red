Red [
	title:   "DELIMIT function"
	purpose: "Insert a delimiter between all items in a list"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %reshape.red

delimit: none
context [
	;@@ use map-each when it's native instead of this mess
	
	in-list:  make [] group: 128
	out-list: make [] group * 2
	loop group [
		repend out-list [quote :delim to get-word! rejoin ["i" index? tail in-list]]
		append in-list to word! rejoin ["i" index? tail in-list]
	]
	
	set 'delimit function [
		"Insert delimiter between all items in the list"
		list  [any-list!]
		delim [any-type!]
		/into result [any-list!]
		; /into result: (make block! 2 * length? list) [any-list!]
	] reshape [
		unless result [result: make block! 2 * length? list]
		if tail? list [return result]
		append/only result :list/1
		n: (length? list) - 1
		if 0 < trail: n % group [
			set (skip @[in-list] rest: group - trail) next list
			reduce/into (skip @[out-list] rest * 2) tail result
		]
		foreach @[in-list] skip list 1 + trail [
			reduce/into @[out-list] tail result
		]
		result
	]
]

#assert [[         ] = delimit [     ] '-]
#assert [[1        ] = delimit [1    ] '-]
#assert [[1 - 2    ] = delimit [1 2  ] '-]
#assert [[1 - 2 - 3] = delimit [1 2 3] '-]

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
