Red [
	title:   "MORPH DSL"
	purpose: "Dialect for persistent local series mapping"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		See https://gitlab.com/hiiamboris/red-mezz-warehouse/-/blob/master/morph.md
	}
]


#include %include-once.red
#include %debug.red
#include %with.red
#include %assert.red
; #include %error-macro.red
; #include %reshape.red
; #include %catchers.red
; #include %selective-catch.red
; #include %reactor92.red
; #include %map-each.red
#debug off

morph-ctx: context [

	;;============ temporary debugging crap ============
	
	;; `probe` variant
	^: probe: function [x [any-type!]] [
		if any [block? :x object? :x] [x: replace-vectors-with-paths copy/deep x]
		system/words/probe :x
	]
	
	;; `??` variant
	?!: function ['x [any-type!]] [
		if any-word? x [set/any 'x get/any name: x]
		if any [block? :x object? :x] [x: replace-vectors-with-paths copy/deep x]
		if name [prin name prin ": "]
		system/words/probe :x
	]
	
	;; used for debug output to make it readable
	replace-vectors-with-paths: function [b [block! object!]] [
		either object? b [
			foreach w words-of b [
				v: select b w
				attempt [replace-vectors-with-paths v] 
				if vector? :v [put b w to path! to [] v]
			]
		][
			forall b [
				attempt [replace-vectors-with-paths b/1]
				if vector? :b/1 [
					nl: new-line? b
					b/1: to path! to [] b/1				;-- this destroys newline markers
					new-line b nl						;-- workaround
				]
			]
		]
		b
	]
	
	
	
	;;============ common stuff used by scanner & emitter ============
	
	FAIL: -1x0                   
	match?: func [p [pair!]][p/1 >= 0]
	
	change-last: function [s [series!] x [any-type!]] [
		change/only back tail s :x
	]
	
	
	
	;;============ scanner definition ============
	
	scanner: context [
		
		; ;@@ copy/deep does not copy inner maps unfortunately, so have to use this
		; copy-deep-map: function [m [map!]] [
			; m: copy/deep m
			; foreach [k v] m [if map? :v [m/:k: copy-deep-map v]]
			; m
		; ]
		
		;@@ hate the number of arguments here, needs reduction
		keep-item: function [input args output data name [word!] inner iofs aofs] [
			unless locs: select output name [repend output [name locs: copy []]]
			pi2: copy pi: copy data/paths/input
			change-last pi base: -1 + index? input
			change-last pi2 iofs + base
			pr2: copy pr: copy data/paths/scan-rules
			change-last pr base: -2 + index? args		;-- -2 accounts for the token itself also
			change-last pr2 aofs + base
			mark: tail locs
			repend locs [pi pi2 pr pr2 inner none none none none]
			new-line mark yes
			new-line inner yes
		]
			
		;;============ scanner actions per token type ============
		
		type-rules: construct compose [
		
			word!: (function [input token args output data /local value] [
				#assert [not find [| ...] token]		;-- handled outside, because there's also backtracking logic involved
				; name: args/-1
				; if find/case [| ...] name [return as-pair 0 length? args]
				set/any 'value get/any name: token
				; type: type?/word :value
				handler: any [
					unless any-word? :value [			;-- words referring to lit/set/normal-words get literal treatment
						select type-rules type: type?/word :value
					]
					select type-rules 'any-type!
				]
				either find [block! paren!] type [
					result: handler/with input :value args output data name
				][	result: handler      input :value args output data
				]
				result
			])
		
			;@@ get-word may make it possible to turn word! into rewrite-macro later
			;@@ that would put `:get-word` or `set-word: block` in place of the word
			get-word!: (function [input token args output data] [	;-- :rule - always literally treats the referred value
				end: find/match/tail input get/any token 
				1x0 * either end [offset? input end][-1]
			])
			
			lit-word!: (function [input token args output data] [	;-- 'rule
				either empty? input [								;-- 'x fails only if input is empty
					-1x0
				][
					name: to word! token
					set/any name :input/1  							;@@ should we have this? for `? x <> y` kind of rules
					keep-item input args output data name copy [] 1 1
					1x0
				]
			])
				                 
			block!: (function [input token args output data /with name] [
				either any-list? :input/1 [					;-- block is able to dive into blocks in the input
					append data/paths/input 0
					type-rules/paren!/with input/1 token args output data name
					take/last data/paths/input
				][
					type-rules/paren!/with input   token args output data name
				]
			])
				
			paren!: (function [input token args output data /with name] [		;-- (rule)/[rule]
				either none? name [									;-- unnamed block/paren - uses same data
					input': eval-ruleset input token output data
				][													;-- set-word or word referring to a block/paren
					; token: get name
					append data/paths/tree name
					inner: copy []
					if input': eval-ruleset input token inner data [
						keep-item input args output data name inner offset? input input' 1
					]
					take/last data/paths/tree
				]
				1x0 * either input' [offset? input input'][-1]		;-- (x)/[x] fail as a whole
			])
			
			;@@ incomplete! has to anonymize the word and set it to the result of next expression
			set-word!: (function [input token args output data] [	;-- x: rule
				name: to word! token
				append data/paths/tree name
				inner: copy []
				offset: eval-next-rule input args inner data		;-- has to be recursive to support multiple set-words
				if match? offset [
					keep-item input args output data name inner offset/1 offset/2
				]
				take/last data/paths/tree
				offset
			])
			
			;@@ TODO: natives & actions could use a simpler interface:
			;@@ take input (and maybe args/1, depending on their arity), return modified input
			; native!:   (function [input token args output data] [type-rules/routine! input :token args output data])
			; action!:   (function [input token args output data] [type-rules/routine! input :token args output data])
			function!: (function [input token args output data] [type-rules/routine! input :token args output data])
			routine!:  (function [input token args output data /local offset] [
				(set/any 'offset token input args output data)	;-- call :token func; paren ensures no arity spillage
				#assert [pair? :offset "scan rules should return pair! value"]	;@@ TODO: macros
				offset
				; paren? :new [						;-- macro returned result of it's expansion
					; #assert [
						; not empty? new
						; any [block? :new/1  paren? :new/1  integer? :new/1] "scan macros should return block or integer as rule"
					; ]
					; rule': either integer? new/1 [skip rule' new/1][new/1]
					; expanded: next new
					; rule': append copy expanded rule'	;-- concat expanded result with the unprocessed rest of the rule
					; [input rule'] 
				; ]
			])
			
			bitset!: (function [input token] [
				either all [    
					any-string? input
					not tail? input
					find token input/1
				] [1x0][-1x0]										;-- matches only in strings
			])
			
			any-type!: (function [input token] [				;-- catch-all special case
				end: find/match/tail input :token 
				1x0 * either end [offset? input end][-1]
			])
		]
				
				
		;;============ scanner core ============
	
		eval-next-rule: function [
			input [series!]
			rule [block! paren!]
			output [block!]
			data [object!]
			;; returns (ate x used) pair
		][
			#assert [not unset? :rule/1]
			#debug [print ["at" mold/only/flat rule]]
			token: :rule/1
			handler: any [
				select type-rules type?/word :token		;@@ how to avoid hash lookup?
				select type-rules 'any-type!
			]
			args: next rule
			mark: tail output
			(offset: handler input :token args output data)		;-- parens prevent arity spillage, just in case
			#assert [pair? offset]
			if offset/1 <= 0 [clear mark]				;-- do not save results from look-ahead rules
			offset + 0x1								;-- count token too
		]
		
		eval-ruleset: function [
			input [series!]
			ruleset [block! paren!]						;-- "set" because `|` allows to have multiple alternatives
			output [block!]
			data [object!]
			;; returns new input offset or none
		][
			append data/paths/scan-rules 0				;-- deepen rule path
			
			loop?: '... == last ruleset
			rule-start: ruleset
			
			result: forever [
				start: input
				ruleset: rule-start
				matched?: yes							;-- empty rule succeeds
				tail-tree output						;-- mark a position for backtracking
				while [not tail? ruleset] [
					#assert [not unset? :ruleset/1]
					token: :ruleset/1
					if find/case [| ...] :token [break]
					new: eval-next-rule input ruleset output data
					#debug [print [match? new "at" mold input]]
					either not match? new [
						input: start					;-- input is reset for next alternative
						; clear mark						;-- backtrack (when some rule succeeds but later one fails)
						clear-tree output				;-- backtrack (when some rule succeeds but later one fails)
						unless ruleset: find/case/tail ruleset '| [
							matched?: no
							break
						]
					][
						; set [input: ruleset:] new			;-- input is only advanced on match
						input:   skip input new/1		;-- commit new offsets
						ruleset: skip ruleset new/2
						change-last data/paths/input      -1 + index? input		;-- update input location
						change-last data/paths/scan-rules -1 + index? ruleset	;-- update rules location
					]
				]
				; #debug [print [matched? ":" mold start "->" mold input]]
				either loop? [							;-- loop never fails, but ends when doesn't advance or when no match
					if any [
						not matched?
						not advanced?: positive? offset? start input
					] [break/return input]
				][
					break/return if matched? [input] 
				]
			]
			
			take/last data/paths/scan-rules				;-- return to the previous rule nesting level
			result
		]
			
		scan: function [								;-- conflicts with lexer's `scan`, so has to be in it's own context
			"Parse the INPUT with a given scan RULE"
			input [series!]
			rule [block! paren!] "Uses scanner's type rules"
			/from "STUB: pick up scanning from given offsets"				;@@
				input-path [vector!] scan-path [vector!]
			/trace "STUB: report each scan result to the trace function"	;@@
				tfunc [function! routine!]
		][
			data: object [
				;@@ TODO: deeply copy rules, anonymize (fix) all words in there
				;@@ so rules are preserved from accidental modification for morph/live
				;@@ perhaps we'll need to do that for macros as well
				input:      none
			 	scan-rules: rule
			 	tree:       copy []
				emit-rules: none						;-- filled by emitter
				output:     none
				paths: object [
					input:      make vector! [0]
					scan-rules: make vector! []
					tree:       copy []
					emit-rules: none					;-- filled by emitter
					output:     none
				]
			]
			data/input: input							;-- required for emitter to take slices of
			input: eval-ruleset input rule data/tree data
			reset-tree data/tree						;-- reset all tree branches to heads (were used for backtracking)
			#debug [?! data]
			data
		]
		
	];; end of scanner
	
	;@@ TODO: macro design
	; macro: func [spec body] [
		; function spec compose/only [as paren! catch-return (body)]
	; ]
	
		
		
	;;============ emitter definition ============
	
	emitter: context [
		
		;;============ emitter actions per token type ============
		
		type-rules: construct compose [
		
			;; polymorphic: calls rule functions or dives into named rule blocks
			word!: (function [input token args output data /local value] [
				#assert [not find [| ...] token]	;-- handled outside, because there's also backtracking logic involved
				; name: args/-1
				; if find/case [| ...] name [return as-pair 0 length? args]
				set/any 'value get/any name: token
				handler: any [
					unless any-word? :value [		;-- words referring to lit/set/normal-words get literal treatment
						select type-rules type: type?/word :value
					]
					select type-rules 'any-type!
				]
				either find [block! paren!] type [
					result: handler/with input :value args output data name
				][	result: handler      input :value args output data
				]
				result
			])
		
			get-word!: (function [input token args output] [	;-- :x - emits word's value
				append/only output get/any token
				1x0										;-- always succeeds, even if unset
			])
			
			lit-word!: (function [input token args output data] [	;-- 'rule - emits a named value
				name: to word! token
				unless all [
					pos: find/tail input name			;-- named branch exists
					not tail? locs: first pos			;-- it's not exhausted
				][return FAIL]
				#assert [block? locs]
				set [ipath1: ipath2:] locs
				pos/1: skip locs 9
				in1: deep-select data/input ipath1
				in2: deep-select data/input ipath2
				; ?? data/input ?? ipath
				#assert [in1]
				#assert [in2]
				pos: tail output
				append output copy/part in1 in2	;-- no /only in case we're copying parts of block into other block
				
				locs/7: locs/6: copy data/paths/output
				change-last locs/7 (last locs/6) + length? pos
				locs/9: locs/8: copy data/paths/emit-rules
				change-last locs/9 1
				1x0
			])
				
			block!: (function [input token args output data /with name] [	;-- block is able to push blocks into the output
				either any-list? output [
					inner: copy []
					append data/paths/output 0
					result: type-rules/paren!/with input token args inner data name
					if match? result [append/only output inner]
					take/last data/paths/output
				][
					result: type-rules/paren!/with input token args output data name
				]
				result
			])
			
			;@@ this should become a macro?
			paren!: (function [input token args output data /with name] [	;-- (rule)/[rule]
				either none? name [						;-- unnamed block/paren
					result: eval-ruleset input token output data
				][										;-- set-word or word referring to a block/paren
					; token: get name
					if all [
						pos: find/tail input name
						locs: first pos
						not empty? locs
					][
						input: fifth locs				;-- ignores this item's bounds, uses content only
						#assert [block? input]
						end: tail output
						append data/paths/tree name
						result: eval-ruleset input token output data
						take/last data/paths/tree
						change/only pos skip locs 9		;-- consider this item used ;@@ TODO: when to reset tree indexes?
														;@@ copy is a workaround for #4913 crash
						locs/7: copy locs/6: copy data/paths/output
						change-last locs/7 (last locs/6) + length? end
						locs/9: copy locs/8: copy data/paths/emit-rules
						change-last locs/9 1
					]
				]
				1x0 * either result [1][-1]
			])
			
			;@@ not implemented yet
			; set-word!: (function [input token args output data] [		;-- x: rule
				; name: to word! token
				; #assert [any-list? :args/1]				;@@ only x: [group] is supported for now; need more?
				; append data/paths/tree name
				; inner: select input ;@@@ WHOOPS!
				; offset: eval-next-rule input args output data	;-- has to be recursive to support multiple set-words
				; unless input [clear end]
				; take/last data/paths/tree
				; offset
			; ])
			
			;@@ TODO: natives & actions could use a simpler interface:
			;@@ take output (and maybe args/1, depending on their arity), return modified output
			; native!:   (function [input token args output data] [type-rules/routine! input :token args output data])
			; action!:   (function [input token args output data] [type-rules/routine! input :token args output data])
			function!: (function [input token args output data] [type-rules/routine! input :token args output data])
			routine!:  (function [input token args output data /local offset] [
				(set/any 'offset token input args output data)	;-- call :token func; paren ensures no arity spillage
				#assert [pair? :offset "emit rules should return pair! value"]	;@@ TODO: macros
				offset
			])
			
			any-type!: (func [input token args output] [		;-- catch-all special case
				append/only output :token
				1x0
			])
		]
		
		
		;;============ emitter core ============
		
		eval-next-rule: function [
			input [block!]
			rule [block! paren!]
			output [series!]
			data [object!]
			;; returns (ate x used) pair
		][
			#assert [not unset? :rule/1]
			#debug [print ["at" mold/only/flat rule]]
			token: :rule/1
			handler: any [
				select type-rules type?/word :token
				select type-rules 'any-type!
			]
			args: next rule
			saved: copy input
			mark: tail output
			(offset: handler input :token args output data)		;-- parens prevent arity spillage, just in case
			#assert [pair? offset]
			if offset/1 <= 0 [
				change clear input saved				;-- do not advance input on look-ahead rules
				clear mark								;-- do not keep output items from look-ahead rules
			]
			; ?? offset ?! saved ?! input
			offset + 0x1								;-- count token too
		]
		
		;; returns none if fails, not none otherwise
		eval-ruleset: function [input ruleset output data] [
			append data/paths/emit-rules 0				;-- deepen rule path
			
			loop?: '... == last ruleset
			rule-start: ruleset
			
			result: forever [		;@@ preprocess the loops for faster iteration? (split into alt-blocks..)
				end: tail output
				ruleset: rule-start
				saved: copy input
				matched?: yes							;-- empty rule succeeds
				while [not tail? ruleset] [
					#assert [not unset? :ruleset/1]
					token: :ruleset/1
					if find/case [| ...] :token [break]
					new: eval-next-rule input ruleset output data
					either not match? new [
						clear end						;-- backtrack output from any failed rules
						change clear input saved		;-- backtrack input indexes too
						unless ruleset: find/case/tail ruleset '| [
							matched?: no
							break
						]
					][
						; input: skip input new/1
						ruleset: skip ruleset new/2
						; change-last data/paths/input -1 + index? input		;-- update input location
						change-last data/paths/output length? output		;-- update output location
						change-last data/paths/emit-rules -1 + index? ruleset	;-- update rules location
					]
				]
				#debug [print [matched? ":" mold output]]
				either loop? [							;-- loop never fails, but ends when doesn't advance or when no match
					if any [
						not matched?
						not grown?: positive? length? end
					] [break/return input]
				][
					break/return if matched? [input] 
				]
			]
			;@@ TODO: eval logic is general enough to be taken out and unified for both scan & emit
			take/last data/paths/emit-rules 			;-- return to the previous rule nesting level
			result
		]
		
		emit: function [
			"Run emit RULE against scanned DATA and return produced result" 
			data [object!] "Result of previous SCAN call"
			rule [block! paren!] "Uses emitter's type rules"
			/into output [series!] "Specify a target to append to (default: new block)"
			/from "STUB: pick up emission from given offsets"				;@@
				output-path [vector!] emit-path [vector!]
			/trace "STUB: report each emit result to the trace function"	;@@
				tfunc [function! routine!]
		][
			output: any [output copy []]
			; data/emit-rules: copy/deep rule
			data/emit-rules:       rule
			data/output:           output
			data/paths/emit-rules: make vector! [] 
			data/paths/output:     make vector! [0]
	        eval-ruleset data/tree rule output data 
			reset-tree data/tree
			#debug [?! data]
			output
		]
		
	];; end of emitter
		
		
		
	;;============ tree manipulation helpers ============
		
	deep-select: function [data path] [
		repeat i length? next path [
			unless data: pick data path/:i + 1 [break]
		]
		if data [skip data last path]
	]
	
	reset-tree: function [tree /local x] [
		parse tree rule: [any [ahead change only set x block! (head x) into rule | skip]]
	]
		
	clear-tree: function [tree /local x] [
		parse tree [any [
			word! set x block! (clear x)
		]]
	]
		
	tail-tree: function [tree /local x] [
		parse tree [any [
			word! change only set x block! (tail x)
		]]
	]
	
	deep-offset?: function [series chunk /with path] [
		path: any [path copy []]
		if (head series) =? head chunk [return append path offset? series chunk]
		#assert [any-list? series]
		
		;; this is dumb and slow but I don't see any other way to locate the inner change
		;@@ address this issue in REP92
		pos: series
		append path 0
		while [pos: find/tail pos series!] [
			change-last path offset? series back pos
			if deep-offset?/with pos/-1 chunk path [return path] 
		]
		take/last path
		none
	]
	
	; path-inside?: function [single-path double-path] [
		; repeat i length? double-path [
			; x: single-path/:i
			; #assert [integer? x]
			; if all [
				; pair? p: double-path/:i
				; p/1 <= x  x <= (p/1 + p/2)
			; ] [return yes]
			; if p <> x [return no]
		; ]
	; ]
	
	;; returns input & rule paths to the closest value started before 'path' in input
	get-value-before: function [tree [block!] path [vector!]] [
		; ?! path ?! tree 
		foreach [name locs] tree [
			for-each [p: sinp einp sscn escn  _  _ _ _ _] locs [
				if sinp >= path [continue]				;-- value should be strictly < path in case it relies on look-ahead rules
				dist: (copy path) - sinp
				if any [none? mindist dist < mindist] [
					mindist: dist
					closest: p
				]
				if einp >= path [break]
			]
			; if all [einp einp >= path] [break]
		]
		if closest [
			any [
				get-value-before closest/5 path
				closest
			]
		]
	]
	
	;; used to remove values started (not ended) within or at any of from/into margins
	;; margins are ambiguous: will they extend to new margin or be broken? so I remove inclusively to play it safe
	;; memo: no need to remove values that will be replaced during rescan
	;; memo: should be called before get-value-before
	cut-tree: function [tree [block!] from [vector!] into [vector!]] [
		foreach [name locs] tree [
			for-each [p: sinp einp _ _  _  _ _ _ _] [	;@@ TODO: output tree
				if all [from <= sinp sinp <= into] [
					remove/part p 9
					p: skip p -9
					continue
				]
			]
		]
	]
	
	;; shifts all start/end points after `from` by `into - from` 
	;; memo: should be called after cut-tree
	shift-tree: function [tree [block!] from [vector!] into [vector!]] [
		#assert [into <> from]
		#assert [(length? into) = length? from]
		removal?: into < from
		diff: into - from
		foreach [name locs] tree [
			for-each [p: sinp einp _ _  _  _ _ _ _] [	;@@ TODO: output tree
				if sinp >= from [p/1: sinp + diff]
				if einp >= from [p/2: einp + diff]
			]
		]
	]


	;;============ primary interface ============
	
	scan: :scanner/scan
	emit: :emitter/emit
	
	;@@ limitation: only one mapping per source is possible right now;
	;@@ TODO: need to write a dispatching mechanism for anything better
	;@@ TODO: how to destroy existing mapping
	set 'morph function [
		"Transform source into target given a set of rules"
		source [series!] "Will become owned by a new anonymous object"
		scan-rule [block! paren!] "Rule to interpret the source"
		emit-rule [block! paren!] "Rule to produce the target"
		/into target [series!]
		/auto "Automatically bind scan-rule and emit-rule to basic rule blocks"
		;@@ eventually /auto should be able to bind the expanded rule, so it will be bound deeply
		/live "Establish a persistent mapping (TBD)"
		;; returns target, so even if it's not provided, /live is not in vain
	][
		target: any [target copy []]
		if auto [
			;-- this is an overhead, so by default rules should already be bound properly
			;-- however it also helps to shorten one-liners when performance doesn't matter
			bind scan-rule scan-rules
			bind emit-rule emit-rules
		]
		either not live [
			emit/into (scan source scan-rule) emit-rule target
		][
			do make error! "Not implemented!"
			reactor: make deep-reactor-92! [
				source: none
				target: none
				data:   none
				temp:   none
				
				on-deep-change-92*: func [
					word        [word!]    "name of the field value of which is being changed"
					pos         [series!]  "series at removal or insertion point"
					part        [integer!] "length of removal or insertion"
					insert?     [logic!]   "true = just inserted, false = about to remove"
					reordering? [logic!]   "removed items won't leave the series, inserted items came from the same series"
					; done?       [logic!]   "signifies that series is in it's final state (after removal/insertion)"
				][
					if word <> 'source [exit]
					#assert [data]
					#assert [target]
					if all [							;-- special case: complete rewrite of the source
						part = length? pos
						pos =? source
					][
						clear self/target
						if insert? [
							self/data: scan source self/data/scan-rule
							emit/into self/data self/data/emit-rule self/target 
						]
						exit
					]
					
					;-- now we're dealing with a partial update
					;-- first, we need to locate changed sub-series within 'source' (in case it's a deep change)
					change-path: deep-offset? source pos
					#assert [change-path]
					change-end: copy change-path
					done?: any [insert? part = 0]	;-- series is at it's final state after modification?
					if part > 0 [					;-- true before removal and after insertion
						either insert? [
							change-end: head add back tail change-end part	;-- shift to the right
							#assert [done?]
							cut-tree   data/tree change-path change-path	;-- items at insertion point become invalid
							shift-tree data/tree change-path change-end
						][
							change-path: head add back tail change-path part;-- shift to the left
							#assert [not done?]		;-- part should be =0 for done?=yes
							;-- remove the no longer valid values from the tree
							cut-tree   data/tree change-path change-end		;-- whole range of items becomes invalid
							shift-tree data/tree change-path change-end
							;-- scanning should be done when we have the final series
							exit
						]
					]
					;-- now pick up the scan
					#assert [done?]					;-- only scan the actualized data
					set [input-path: _: scan-path:] get-value-before data/tree change-path
					data: scan/from/trace
						data/source data/scan-rule
						input-path scan-path
						function [...] [
							;@@ tracing function will receive results of successful match of named values
							;@@ will put these results into data/tree, keeping it sorted
							;@@ and once it detects a result that is already in the tree, it stops the scan
							;@@ it will also mark the locations of each newly inserted item
						]
					;-- now pick up the emit
					emit/into/from/trace
						data data/emit-rule
						slice: make target part
						output-path emit-path
						function [...] [
							;@@ tracing function should track offsets in emit rules and in the tree
							;@@ once all newly added tree items have been processed and
							;@@ the next emitted named item aligns with the one present in output (with offset correction)
							;@@ we stop the emission and consider the rest of the output valid
						]
					;@@ merge slice with output, deeply
				]
				        
				on-change**: :on-change*
				on-change*: function [word old [any-type!] new [any-type!]] [
					on-change** word :old :new
					if word = 'source [
						word: to word! word
						if series? :old [
							on-deep-change-92* word old length? old no  no 
						]
						if series? :new [
							on-deep-change-92* word new length? new yes no 
						]
					]
				]
			]
			set-quiet in reactor data scan source scan-rule		;-- do initial scan
			set-quiet in reactor 'target target
			reactor/source: source								;-- transfer ownership
		]
		target
	]
]



;;============ scan rules are fully in defined userspace ============

scan-rules: construct/only compose with morph-ctx [		;-- construct preserves function code from being bound to rule names

	?: (function [
		"Evaluate next expression, succeed if it's not none or false"
		input args /local r end
	][
		set/any 'r do/next as [] args 'end			;@@ as [] required per #4980
		as-pair  either :r [0][-1]  offset? args end
	])
	
	??: (func [
		"Display value of next token"
		input args
	][
		?? (:args/1)
		0x1
	])
	
	show: (func [
		"Display current input location"
		input
	][
		?? input
		0x0
	])
	
	opt: (func [
		"Try to match next rule, but succeed anyway, similar to (rule |)"
		input args output data
	][
		max 0x0 scanner/eval-next-rule input args output data
	])

	ahead: (function [
		"Look ahead if next rule succeeds" 
		input args output data
	][
		new: scanner/eval-next-rule input args output data
		as-pair (either match? new [0][-1]) new/2
	])

	not: (function [
		"Look ahead if next rule fails" 
		input args output data
	][
		new: scanner/eval-next-rule input args output data
		as-pair (either match? new [-1][0]) new/2
	])

	some: (function [
		"Match next rule one or more times"
		input args output data
	][
		offset: new: scanner/eval-next-rule input args output data
		either match? offset [
			until [
				input: skip input new/1
				offset/1: offset/1: new/1
				not match? new: eval-next-rule input args output data
			]
		][
			offset/1: -1								;-- fails if never succeeded
		]
		offset
	])

	any: (function [
		"Match next rule zero or more times (always succeeds)"
		input args output data
	][
		offset: 0x0
		while [match? new: scanner/eval-next-rule input args output data] [
			input: skip input new/1
			offset/1: offset/1 + new/1
		]
		offset											;-- never fails
	])

	quote: (func [
		"Match next token literally vs the input"
		input args
	][
		either :input/1 = :args/1 [1x1][-1x1] 
	])

	lit: (function [
		"Match contents of next block/paren (or word referring to it) vs input"
		input args
	][
		either end: find/match/tail
			input
			either word? :args/1 [get/any args/1][:args/1]
		[as-pair (offset? input end) 1][-1x1]
	])
	
	skip: (func [
		"Match any single value"
		input
	][
		either tail? input [FAIL][1x0]
	])
	
	head: (func [
		"Match head of input only"
		input
	][
		either head? input [0x0][FAIL]
	])

	tail: (func [
		"Match tail of input only"
		input
	][
		either tail? input [0x0][FAIL]
	])
]



;;============ emit rules are fully in defined userspace ============

emit-rules: construct/only compose with morph-ctx [
	;@@ these don't work because input is not a linear structure: it has named items
	;@@ (not 'name) or (ahead 'name) should be used instead as targeted rules
	; *head: func [input args output data] [
		; either head? input [0x0][FAIL]
	; ]

	; *tail: func [input args output data] [
		; either tail? input [0x0][FAIL]
	; ]
	
	opt: (func [
		"Try to match next rule, but succeed anyway, similar to (rule |)"
		input args output data
	][
		max 0x0 emitter/eval-next-rule input args output data
	])

	ahead: (function [
		"Look ahead if next rule succeeds" 
		input args output data
	][
		new: emitter/eval-next-rule input args output data
		as-pair (either match? new [0][-1]) new/2
	])

	not: (function [
		"Look ahead if next rule fails" 
		input args output data
	][
		new: emitter/eval-next-rule input args output data
		as-pair (either match? new [-1][0]) new/2
	])
	
	to: (function [
		"[to datatype! rule...] Convert result of rule match into a given type"
		input args output data
	][
		#assert [word? args/1]
		#assert [datatype? get/any args/1]
		#assert [any-list? output  "'to' rule is only valid for lists"]
		type: get args/1
		args: next args
		pos: tail output
		offset: emitter/eval-next-rule input args output data
		offset/2: offset/2 + 1
		if match? offset [
			#assert [single? pos]
			change pos to type pos/1 
		]
		offset
	])
	
	load: (function [
		"[load rule...] Load result of next rule match"
		input args output data
	][
		#assert [any-block? output  "'load' rule is only valid for blocks"]
		pos: tail output
		offset: emitter/eval-next-rule input args output data
		if match? offset [
			#assert [single? pos]
			change pos transcode :pos/1					;-- expands if multiple values
		]
		offset
	])
]
		

;;============ test code ============

csv-src: context with scan-rules [
	; source: system/words/quote (word (#" " |) ...)
	; word:   system/words/quote ('x ? x <> #" " ...)
	; probe scan source "ab cde fg"

	; value: system/words/quote ('x ? x <> #"," ? x <> lf ...)
	; value: system/words/quote (not (lf | #",") 'x ...)
	; value: [x: value-char ...]
	; value: [ahead value-char 'x ...]
	; value: [not (lf | #",") 'x ...]
	; value: ['x ? find value-char x ...]
	; value: [ahead 'x ahead 'x value-char ...]
	; value: [ahead 'x ahead x: value-char value-char ...]
	value-char: negate charset "^/,"
	value: [value-char ...]
	line:  [value (#"," value ...)]
	return [line (lf line ...)]
]
	
csv-blk: context with emit-rules [
	; line: [to tag! :value ...]
	line: [load 'value ...]
	return [line ...]
]
		
csv-txt: context with emit-rules [
	line: ['value (#"," 'value ...)]
	return [line :lf ...]
]
	

do with morph-ctx [
	text: {a,b,c^/10,20,30} 
	; set 'data scan text my-scan-rules/csv
	; ?! data
	; new-csv-text: emit/into data my-emit-string-rules/csv ""
	; ?! new-csv-text
	; new-csv-tree: emit data my-emit-block-rules/csv
	; ?! new-csv-tree

	^ morph [1 2 3 4] ['x 'y ...] ['y 'x ...]
	^ morph/auto [1 2 3 4] ['x ? even? x | skip ...] ['x ...]
	
	;; parse/emit a csv
	^ morph/into text csv-src csv-txt ""
	^ morph      text csv-src csv-blk
	
	;; delimit values
	^ morph "1 2 3 4" context with scan-rules [
		token: [not #" " skip ...]
		return [token (#" " token ...)]
	] ['token ...]
	;; join values
	^ morph/auto/into [1 2 3 4] ['x ...] ['x (not 'x | " ") ...] ""
]



;@@ this model is planned but not implemented yet:
; do with morph-ctx [
	; text: {a,b,c^/10,20,30} 
	
	; csv-src: with scan-rules [
		; line: [
			; value: [
				; value-char: negate charset "^/," ...
			; ] (#"," value ...)
		; ] line (lf line ...)
	; ]
	
	; csv-tree: with emit-rules [line: [load :value ...] ...]
	; csv-text: with emit-rules [line: [:value (#"," :value ...)] :lf ...]

	; ^ morph/into text csv-src csv-text ""
	; ^ morph      text csv-src csv-tree
; ]

