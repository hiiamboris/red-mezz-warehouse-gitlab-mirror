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


#include %new-apply.red


replace: function [
	"Replaces every pattern in series with a given value, in place"
    series  [any-block! any-string! binary! vector!] "The series to be modified"	;-- series! barring image!
    pattern [any-type!] "Specific value to look for"
    value   [any-type!] "New value to replace with"
    ; /all   "Replace all occurrences, not just the first"
    ; /deep  "Replace pattern in all sub-lists as well (implies /all)"
    /once  "Replace only first occurrence, return position after replacement"	;-- makes no sense with /deep, returns series unchanged if no match
    /deep  "Replace pattern in all sub-lists as well"
    /case  "Search for pattern case-sensitively"
    /same  {Search for pattern using "same?" comparator}
    ;-- /only applies to both pattern & value, but how else? or we would have /only-pattern & /only-value
    /only  "Treat series and typeset pattern and series value argument as single values"
    /part  "Limit the replacement region"
    	length [number! series!]
][
	seek-pattern-from-pos: [							;-- primary `find` use
		series: pos
		value:  :pattern
		case:   case
		same:   same
		only:   only
		part:   part
		length: length
	]
	;-- could have compose-d these, but don't want allocations:
	seek-tail-from-patpos: [							;-- determines size of `find` pattern
		series: pat-pos
		value:  :pattern
		tail:   true
		; match:  true									;@@ bug #4943
		case:   case
		same:   same
		only:   only
		part:   part
		length: length
	]
	seek-list-from-pos: [								;-- looks for lists when /deep
		series: pos
		value:  any-list!
		part:   part
		length: length
	]
	inner-replace-at-lstpos: [							;-- used on inner lists
		series:  lst-pos/1
		pattern: :pattern
		value:   :value
		; all:     all
		once:    once
		deep:    deep
		case:    case
		same:    same
		only:    only
		part:    part
		length:  length
	]
	change-at-patpos: [
		series: pat-pos
		value:  :value
		part:   true
		range:  size
		only:   only
	]


	; if deep [all: true]									;-- /deep doesn't make sense without /all
	; if deep [once: false]								;-- /deep doesn't make sense with /once
	if all [deep once] [do make error! "/deep and /once refinements are mutually exclusive"]
	unless any-block? :series [deep: no]

	;-- delay size estimation and value forming until actual match
	when-found: [
		size: either only [
			1
		][
			offset? pat-pos apply find seek-tail-from-patpos
		]
		; if system/words/all [							;-- to avoid forming value on every change, do it explicitly
		if all [										;-- to avoid forming value on every change, do it explicitly
			any-string? series
			not any-string? :value
		][
			value: to string! :value					;-- like R2, using to-string instead of form
		]
	]

	pos: series
	either not deep [
		if pat-pos: apply find seek-pattern-from-pos [
			do when-found
			pos: apply change change-at-patpos
			unless once [
				while [pat-pos: apply find seek-pattern-from-pos] [
					pos: apply change change-at-patpos
				]
			]
		]
	][
		if pat-pos: apply find seek-pattern-from-pos [do when-found]
		lst-pos:    apply find seek-list-from-pos
		;-- a bit tricky to use 2 `find`s in parallel, but this leverages fast lookups at hashtables:
		forever [
			action: system/words/case [
				all [lst-pos pat-pos] [
					either 0 <= o: offset? pat-pos lst-pos [	;-- o=0 case: pattern takes priority over list; otherwise list comes after pattern
						list-gone?: o < size					;-- found list position will be overwritten
						'replace
					][
						'deep-replace
					]
				]
				pat-pos [list-gone?: no  'replace]
				lst-pos ['deep-replace]
				'else   [break]
			]
			switch action [
				replace [
					pos: apply change change-at-patpos
					system/words/case [
						list-gone? [					;-- list was replaced by the change
							lst-pos: apply find seek-list-from-pos
						]
						lst-pos [						;-- list index moved after the change
							new-size: offset? pat-pos pos
							lst-pos: skip lst-pos new-size - size
						]
					]
					pat-pos: apply find seek-pattern-from-pos
				]
				deep-replace [
					apply replace inner-replace-at-lstpos
					pos: next lst-pos
					lst-pos: apply find seek-list-from-pos
				]
			]
			if once [break]
		]
	]

	series
]


; print "_WORK HERE_"
