Red [
	title:   "REPLACE function rewrite"
	purpose: "Simplify and empower it, move parse functionality into mapparse"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		REPLACE is long due for a rewrite.
		
		Reasons are not only numerous bugs and inconsistencies with FIND,
		but also because APPLY is available now (at least as a mezz),
		we don't have to use PARSE to get /deep to work anymore.
		I think lack of APPLY is the sole reason PARSE was used in the first place.
		Design discussion is here: https://github.com/red/red/issues/4174

		This implementation removes PARSE functionality from REPLACE, leaving it to MAPPARSE instead.
		It also implements REP #83:
			/all is the default case, while /once can be used to make a single replacement.
			/only is supported along with other refinements that make sense
		
		Gregg has the idea of unifying REPLACE & MAPPARSE into one, but I couldn't do that so far.
		I tried at first but hated what come out.
		Reasons:
		- zero shared code
		- docstrings become very hard to write, ambiguous (main reason)
		- pattern & value both change in meaning with /parse refinement
		- how to tell /parse mode when block value should be code and when it should be a value?
		- in /parse mode: /same makes no sense, /only does not apply to pattern anymore
		- I don't wanna see monstrosities like `replace/parse/all/deep/case` in code
		  (one of the key reasons why this implementation removes /all, second: /all being the most useful case)
		- mapparse is consistent with forparse, and if we integrate it into replace, what do we do with forparse?
		- forparse and mapparse are loops, so they support break & continue in their code blocks,
		  so their operation logic does not align very much with that replace
	}
]


#include %assert.red
; #include %new-apply.red


;; 'replace' is 'find'-based to have as little surprises as possible and be as general as 'find' (e.g. there's no /same in Parse)
replace: function [
	"Replaces every pattern in series with a given value, in place"
    series  [any-block! any-string! binary! vector!] "The series to be modified"	;-- series! barring image!
    pattern [any-type!] "Specific value to look for"
    value   [any-type!] "New value to replace with"
    /once  "Replace only the first occurrence, return position after replacement"	;-- makes no sense with /deep, returns series unchanged if no match
    /deep  "Replace pattern in all sublists and paths as well"
    /case  "Search for pattern case-sensitively"
    /same  "Search for pattern using `same?` comparator"
    ;@@ /only applies to both pattern & value, but how else? or we would have /only-pattern & /only-value
    /only  "Treat type/typeset/series pattern, as well as series value, as single item"
    /part  "Limit the lookup region"
    	limit [integer! series!]
][
	if all [deep once] [cause-error 'script 'bad-refines []]	;-- incompatible
	unless any-block? series [deep: off]
	
	start: series										;-- starting offset may be adjusted if part is negative
	either limit [
		if integer? limit [limit: skip start limit]		;-- convert limit to series, or will have to update it all the time
		if back?: negative? offset? start limit [		;-- ensure negative limit symmetry
			start: limit
			limit: series
		]
	][
		limit: tail series
	]
	
	;; pattern size will be found out after first match:
	size: [size: offset? match find/:case/:same/:only/match/tail match :pattern]
	
	next-match: [match: find/:case/:same/:only/:part pos :pattern offset? pos limit]	;@@ offset = workaround for #5319
	shallow-replace: [
		unless pos =? match [append/part result pos match]			;@@ unless = workaround for #5320
		append/:only result :value
		pos: skip match do size
	]
	replace-in-sublists: [
		;; using any-list! makes paths real hard to create dynamically, so any-block! here
		while [list: find/part pos any-block! offset? pos match] [	;@@ offset = workaround for #5319
		; while [list: find/part pos any-block! match] [
			replace/deep/:case/:same/:only sublist: list/1 :pattern :value
			unless pos =? list [append/part result pos list]		;@@ unless = workaround for #5320
			append/only result sublist
			pos: next list
		]
	]
	
	;; two reasons to use a separate buffer: O(1) performance and ease of tracking of /part which would move otherwise
	result: clear copy/part start limit
	pos: start
	system/words/case [
		once     [either do next-match shallow-replace [return limit]]
		not deep [while next-match shallow-replace]
		deep [
			while next-match [
				do replace-in-sublists
				do shallow-replace
			]
			match: limit
			do replace-in-sublists
		]
	]

	;; global replace returns original offset: if part < 0 it's end (<> series), otherwise start
	;; /once returns offset after match (or tail if no match, indicating full processing of input)
	end: change/part start result pos
	either any [back? once] [end][start]
]

;@@ move it into new-replace-tests
#assert [
	[[1] 2 [1] 1 [1]]      = head replace/once      [[1] 1 [1] 1 [1]] 1 2
	      [[1] 1 [1]]           = replace/once      [[1] 1 [1] 1 [1]] 1 2
	[[1] 1 [1] 1 [1]]      = head replace/once      [[1] 1 [1] 1 [1]] 3 2
	tail?                         replace/once      [[1] 1 [1] 1 [1]] 3 2	;-- no match - returns tail (processed everything)
	
	[[2] 2 [2] 2 [2]]           = replace/deep      [[1] 1 [1] 1 [1]] 1 2
	[[2] 2 [2] 2 [2] 3]         = replace/deep      [[1] 1 [1] 1 [1] 3] 1 2
	[[2] 2 [2] 2 [2]]           = replace/deep      [[1] 1 [1] 1 [1]] [1] 2
	[2 1 2 1 2]                 = replace/deep/only [[1] 1 [1] 1 [1]] [1] 2
	[2 1 2 1 2]                 = replace/only      [[1] 1 [1] 1 [1]] [1] 2
	[2 1 2 1 2]                 = replace           [[1] 1 [1] 1 [1]] block! 2
	[2 1 2 1 2]                 = replace/deep      [[1] 1 [1] 1 [1]] block! 2
	[2 1 2 1 2]                 = replace/deep      [[1] 1 [[]] 1 [1]] block! 2
	[[1] 2 1 [1] 2 1 [1]]       = replace           [[1] 1 [1] 1 [1]] 1 [2 1]
	[[1] 2 1 [1] 2 1 [1]]       = replace           [[1] 1 [1] 1 [1]] [1] [2 1]
	[[2 1] 2 1 [2 1] 2 1 [2 1]] = replace/deep      [[1] 1 [1] 1 [1]] 1 [2 1]
	[[2 1] 2 1 [2 1] 2 1 [2 1]] = replace/deep      [[1] 1 [1] 1 [1]] [1] [2 1]
	[[[2 1]] [2 1] [[2 1]] [2 1] [[2 1]]] = replace/deep/only [[1] 1 [1] 1 [1]] 1 [2 1]
	[[2 1] 1 [2 1] 1 [2 1]]     = replace/deep/only [[1] 1 [1] 1 [1]] [1] [2 1]		;-- should not try to match the insertion
	[2 1 2 1 1]                 = replace           [1 1 1 1 1] [1 1] [2 1]
	[1 2 2 1 1]            = head replace/part skip [1 1 1 1 1] 3 1 2 -2		;-- negative /part
	[1 1]                       = replace/part skip [1 1 1 1 1] 3 1 2 -2
	[2 2 2 1 1]            = head replace/part skip [1 1 1 1 1] 3 1 2 -4
	[1 1]                       = replace/part skip [1 1 1 1 1] 3 1 2 -4
	[2 3 2 3 2 3 1 1]      = head replace/part skip [1 1 1 1 1] 3 1 [2 3] -4
	[1 1]                       = replace/part skip [1 1 1 1 1] 3 1 [2 3] -4		;-- should be smart enough to return after the change here
	; "<b> <b> <b>"                         = replace           "a a a" "a" <b>	;@@ #5321 - tags are broken, too hard to work around
	; (as tag! "<b> <b> <b>")               = replace           <a a a> "a" <b>
	; <a a a>                               = replace           <a a a> <a> <b>
]