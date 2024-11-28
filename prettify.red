Red [
	title:   "PRETTIFY mezzanine"
	purpose: "Automatically fill some (possibly flat) code/data with new-line markers for readability"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		Example (flatten prettify's own code then restore it):
		
		>> probe prettify load mold/flat :prettify
		func [
			"Reformat BLOCK with new-lines to look readable"
			block [block! paren!] "Modified in place, deeply"
			/data "Treat block as data (default: as code)"
			/spec "Treat block as function spec"
			/parse "Treat block as Parse rule"
			/local w body orig limit inner code-hints! p part
		] [
			new-line/all orig: block no
			if empty? orig [
				return orig
			]
			limit: 80
			case [
				data [
					while [
						block: find/tail block block!
					] [
						prettify/data inner: block/-1
					]
					if any [
						inner
						limit <= length? mold/part orig limit
					] [
						new-line/skip orig yes 2
					]
				]
		... and so on
	}
	notes: {
		VID considerations:
		- for most words, we can't know if it's a style name, facet value or something else
		- for some facets (like data, extra) we don't know the arity of expressions
		  thus it makes more sense to be conservative and add new-lines only before:
		  - standard style names
		  - recognized style declarations
		  (and even this will be unreliable, but better than nothing)
		- blocks may mean:
		  - data (only when prefixed with some keywords)
		  - draw code (only after draw keyword)
		  - sub-layout VID (for panels only)
		  - default actor or do/react code (other cases)
		- set-words are a good hint for new face or style start
		- line start before `at` is better than before its style
	}
]


prettify: none
context [
	draw-commands: make hash! [
		line curve box triangle polygon circle ellipse text arc spline image
		matrix reset-matrix invert-matrix push clip rotate scale translate skew transform
		pen fill-pen font line-width line-join line-cap anti-alias
	]
	shape-commands: make hash! [
		move hline vline line curv curve qcurv qcurve arc
	]
	
	VID-styles: make hash! any [attempt [keys-of :system/view/VID/styles] 0]
	VID-panels: make hash! [panel group-box tab-panel]
	
	stack: make hash! 16
	head': func [s] [either map? s [s][head s]]

	set 'prettify function [
		"Reformat BLOCK with new-lines to look readable"
		block [block! paren! map!] "Modified in place, deeply"
		/data  "Treat block as data (default: as code)"
		/draw  "Treat block as Draw dialect"
		/spec  "Treat block as function spec"
		/parse "Treat block as Parse rule"
		/vid   "Treat block as VID layout"
		/from  "Keep block flat if it molds in less chars than limit"
			limit "Default = 80, to always expand use 0" 
		/local body word
	][
		if empty? orig: block [return orig]
		either find/only/same stack head' orig					;-- cycle protection
			[return orig]
			[append/only stack head' orig]
		unless map? block [new-line/all block no]				;-- start flat
		default limit: 80										;-- expansion margin
		
		; print [case [data ["DATA"] spec ["SPEC"] parse ["PARSE"] 'else ["CODE"]] mold block lf]
		loop 1 [case [
			map? block [
				block: values-of block
				while [block: find/tail block block!] [
					prettify/data/from block limit
				]
			]
			data [												;-- format data as key/value pairs, not expressions
				while [block: find/tail block block!] [
					prettify/data/from inner: block/-1 limit	;-- descend recursively
				]
				if any [
					inner										;-- has inner blocks?
					limit <= length? mold/part orig limit		;-- longer than limit?
				][
					new-line/skip orig yes 2					;-- expand as key/value pairs
				]
			]
			spec [
				if limit > length? mold/part orig limit [break]
				new-line orig yes
				forall block [
					if all-word? :block/1 [new-line block yes]	;-- new-lines before argument/refinement names
					if /local == :block/1 [break]
				]
			]
			parse [
				if limit > length? mold/part orig limit [break]
				new-line orig yes
				forall block [
					case [
						'| == :block/1 [new-line block yes]		;-- new-lines before alt-rule
						block? :block/1 [prettify/parse/from block/1 limit]
						paren? :block/1 [prettify/from       block/1 limit]
					]
				]
			]
			vid [
				styles: copy VID-styles
				split:  [(new-line split?: p yes)]
				system/words/parse block layout: [any [p:
					set word word! if (find styles word) split (style: word)
				|	'at pair! opt set-word! set style word! split	;-- preferable split point
				|	set-word! set style word! split					;-- ditto
				|	'style set word set-word! set style word! split
					(append styles to word! word) 				;-- new styles are collected FWIW
				|	'draw
					change only set block block! (prettify/draw/from block limit)
				|	['data | 'extra] 
					change only set block block! (prettify/data/from block limit)
				|	change only set block block! (
						vid: to logic! find VID-panels style
						prettify/:vid/from block limit
					) 
				|	skip
				]]
				if split? [new-line orig not split? =? orig]	;-- don't expand single-face VID
			]
			draw [
				if limit > length? mold/part orig limit [break]
				split: [p: (new-line back p yes)]
				system/words/parse orig rule: [any [
					ahead block! p: (new-line/all p/1 off) into rule
				|	set word word! [
						'shape any [
							set word word! if (find shape-commands word) split
						|	skip
						]
					|	if (find draw-commands word) split
					]
				|	skip
				]]
			]
			'code [
				code-hints!: make typeset! [any-word! any-path!]
				until [
					new-line block yes							;-- add newline before each independent expression
					tail? block: preprocessor/fetch-next block
				]
				system/words/parse orig [any [p:
					ahead word! ['function | 'func | 'has]		;-- do not mistake words for lit-/get-words
					set spec block! (prettify/spec/from spec limit)
					set body block! (prettify/from      body limit)
				|	ahead word! 'draw pair! set block block! (prettify/draw/from block limit)
				|	set block block! (
						unless empty? block [
							part: min 50 length? block			;@@ workaround for #5003
							case [
								not find/part block code-hints! part [	;-- heuristic: data if no words nearby
									prettify/data/from block limit
								]
								find/case/part block '| part [	;-- heuristic: parse rule if has alternatives
									prettify/parse/from block limit
								]
								'else [prettify/from block limit]
							]
							if new-line? block [new-line p no]	;-- no newline before expanded block
						]                                       
					)
				|	set block paren! (prettify/from block limit)
				|	skip
				]]
			]
		]]
		take/last stack
		orig
	]
]

; probe prettify load mold/flat :prettify
