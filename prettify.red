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
	"Reformat CODE with new-lines to look readable"
	code [block! paren!] "Modified in place, deeply"
][
	new-line/all from: code no							;-- start flat
	until [
		new-line code yes								;-- add newline before each independent expression
		tail? code: preprocessor/fetch-next code
	]
	attempt [											;-- in case it recurses into itself ;)
		parse from [any [p:
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
				prettify p/1							;-- prettify the inner block/paren
			)
		|	skip
		]]
	]
	from
]
