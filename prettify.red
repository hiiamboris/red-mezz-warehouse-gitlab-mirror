Red [
	title:   "PRETTIFY mezzanine"
	purpose: "Automatically fill some (possibly flat) code with new-line markers for readability"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		NOTE: just a quick experiment! Function spec detection is basic, no Parse or VID DSL detection

		Example (flatten prettify's own code then restore it):
			>> probe prettify load mold/flat :prettify
			[
			    func [
			        "Reformat CODE with new-lines to look readable" 
			        code [block! paren!] "Modified in place, deeply" 
			        /local from p
			    ] [
			        new-line/all from: code no 
			        until [
			            new-line code yes 
			            tail? code: preprocessor/fetch-next code
			        ] 
			        attempt [
			            parse from [
			                any [
			                    p: [
			                        'function 
			... and so on
	}
]


prettify: function [
	"Reformat BLOCK with new-lines to look readable"
	block [block! paren!] "Modified in place, deeply"
	/data "Treat block as data (default: as code)"
][
	new-line/all orig: block no							;-- start flat
	
	if data [											;-- format data as key/value pairs, not expressions
		limit: 80										;-- expansion margin
		while [block: find/tail block block!] [
			prettify/data inner: block/-1				;-- descend recursively
		]
		if any [
			inner										;-- has inner blocks?
			limit <= length? mold/part orig limit		;-- longer than limit?
		][
			new-line/skip orig yes 2					;-- expand the block
		]
		return orig
	]
	
	until [
		new-line block yes								;-- add newline before each independent expression
		tail? block: preprocessor/fetch-next block
	]
	attempt [											;-- in case it recurses into itself ;)
		parse orig [any [p:
			set w ['function | 'func] if (word? w)		;-- do not mistake words for lit-/get-words
			ahead block! (								;-- special case for function spec (not very reliable detection :/ )
				new-line/all p/2 no						;-- flatten the spec
				unless empty? p/2 [new-line p/2 yes]	;-- expand the spec block
			) into [any [p:
				all-word! (new-line p yes)				;-- new-lines before argument/refinement names
				opt [if (/local == p/1) to end]			;-- stop after /local
			|	skip
			]]
		|	[block! | paren!] (
				new-line p no							;-- disable new-line before block start
				data?: not find/part p/1 word! limit	;-- heuristic: data if no words nearby, code otherwise
				either data? [prettify/data p/1][prettify p/1]	;-- prettify the inner block/paren
			)
		|	skip
		]]
	]
	orig
]
