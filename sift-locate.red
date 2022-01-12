Red [
	title:   "SIFT & LOCATE mezzanines"
	purpose: "High-level series items locator & filter"
	author:  @hiiamboris
	license: BSD-3
	notes: {
		See sift-locate.md for details
		
		BUGS:
		need to get rid of the preprocessor here! not an option!
		setting `x: does []` is enough to fail the tests, because it errors on fetch-next `x/p/q`
		it might have almost worked if conditions were bound to for-each spec before preprocessing
		but still: what if `x/p/q` is a non-nullary func where `x` is not yet defined? 
	}
]

#include %localize-macro.red
#include %assert.red

#include %setters.red									;-- we need `anonymize`
#include %new-each.red									;-- based on extended foreach/map-each capabilities
#include %new-apply.red									;-- need `apply` to dispatch refinements

context [
	;-- this one is tricky but much faster than `attempt` and try/attempt are probably the only type-agnostic tests
	;-- get succeeds = path exists = we get `not none` = true
	;-- get fails = no path = we get `not error` = false
	;-- should not return false if path exists but has a falsey value!
	path-exists?: function [:path [path! get-path!]] [
		; not try [get/any path  none]					;@@ no longer working :( no longer fast :(
		; not try compose/into [(path)  none] clear []
		not try [
			either path? path [
				x: get/any path							;-- x: is a workaround for #4988
			][
				get/any path
			]
			none
		]
		;@@ maybe to hell with this func, let it fail and rethrow the errors unless they're path-related?
	]
	#assert [
		(b: [a 1]             path-exists? b/a)
		;@@ this technically fails, but I don't care since my aim is to avoid path errors rather than a precise check:
		; (b: [a 1]         not path-exists? b/b)
		(o: object [a: 1]     path-exists? o/a)
		(o: object [a: 1] not path-exists? o/b)
	]

	anonymous-hyphen: anonymize '- none					;-- a safe-to-assign hyphen for use in spec
	spec-end-marker: ['..]								;-- readable delimiter between spec and tests

	;-- tests (not spec) rewriter used in expand-pattern
	expand-tests: function [
		tests [block!] "modified in place!"
		subject [word! none!]
		tested-paths [block!]
		/local ref w b
	][
		alternatives: reduce [chain: copy []]
		nexpr: 0										;-- count expressions so we open `all` clause when needed
		nalts: 1										;-- count alternatives so we open `any` clause when needed

		finish-chain: [
			pos: back tail alternatives
			either nexpr = 1 [
				change/part pos pos/1 1					;-- unwrap the block
			][
				; insert pos 'all							;-- open `all` clause, even for empty blocks (nexpr = 0)
				either nexpr > 0 [
					insert pos 'all						;-- open `all` clause
				][
					change pos 'true					;@@ special case until REP#85 is implemented in Red
				]
			]
			clear tested-paths
		]
		finish-alts: [
			if nalts > 1 [
				alternatives: compose/only [any (alternatives)]	;-- open `any` clause
			]
		]
		test-path: [									;-- tests path for existence so no path error handling should be required on user's end
			unless any [
				single? path							;-- ignore paths of length=1 (e.g. resulting from function calls)
				find/only head tested-paths path		;-- don't repeat tests for already tested paths
			][
				append chain compose/deep [
					path-exists? (path)
				]
				nexpr: nexpr + 1
				append/only tested-paths path
			]
		]

		=refs-paths?=: [
			(path: none)
			p: (n: offset? p e)							;-- don't peek into the next expression
			if (n > 0)
			ahead [0 n [p:
				change only set ref refinement! (
					unless subject [					;-- can be extended in the future
						ERROR "Cannot use refinements without column selected at (mold/only/part p 40)"
					]
					path: as path! compose [(subject) (to word! ref)]
					do test-path
					as get-path! path					;-- refinement changes into path
				)
			|	set path [path! | get-path!] (			;-- should be tested for existence, excluding function refinements
					set/any [sub-path: value:] preprocessor/value-path? as path! path
					if any-function? :value [path: sub-path]	;-- remove refinements from function call path
					do test-path
				)
			|	skip
			]]
			if (path)									;-- fail if no refinement was found
		]

		=single?=: [if (e =? next s)]

		=types?=: [										;-- type checks
			ahead [
				change set w word! (
					unless subject [					;-- can be extended in the future
						ERROR "Cannot use type checks without column selected at (mold/part p 40)"
					]
					get-sub: to get-word! subject
					case [
						datatype? get/any w [compose [ (w)   =? type? (get-sub) ]]	;-- `=?` is a bit faster than `=`
						typeset?  get/any w [compose [ find (w) type? (get-sub) ]]
						'else [w]						;-- normally - no change
					]
				) e:									;-- update expression end offset after change
			]
		]

		=group?=: [										;-- expression group (opens `all` clause)
			ahead [
				change set b block! (expand-tests b subject tail tested-paths)
				e:										;-- update expression end offset after change
			]
		]

		=alternative?=: [
			'| s: (										;-- update start so this token is skipped
				do finish-chain
				append/only alternatives chain: copy []
				nalts: nalts + 1
				nexpr: 0
			)
		]

		=add-expr=: [(
			unless s =? e [
				insert/part pos: tail chain s e
				new-line pos yes						;-- for more readability when inspecting expanded tests
				nexpr: nexpr + 1
			]
		)]

		parse tests =tests=: [
			e: any [s:
				=alternative?=
			|	(e: preprocessor/fetch-next s)
				opt [=refs-paths?= | =single?= [=types?= | =group?=]]
				=add-expr= :e
			]
		]
		do finish-chain
		do finish-alts

		alternatives
	]

	;@@ left global temporarily for manual testing!
	set 'expand-pattern function [
		"Rewrite sift/locate PATTERN into plain Red code"
		pattern [block!]
		; return: [block!] "[spec tests]: spec in *each format, tests - just code"
		/local w
	][
	; expand-pattern: function [pattern [block!] /local w] [
		pattern: copy/deep pattern						;-- will be modified in place
		=spec=: [										;-- processes the spec to get default subject and possibly insert it
			(	subject: clear []
				step: 0									;-- count step so we know when to insert default subject
			)
			opt [set-word! | refinement!] insertion-point:
			any [
				not spec-end-marker [
					'| | block!							;-- these do not affect step
				|	[	change '- (anonymous-hyphen)	;-- `-` should not be `set` by *each as it's a native
					|	paren!
					|	set w word! (append subject w)	;-- look for candidates into default subject
					] (step: step + 1)
				]
			]
			spec-end:
			[ spec-end-marker | end | p: (ERROR "Unexpected pattern format at (mold/only/part p 40)") ]
			p: (
				if step = 0 [							;-- no words defined? special case
					append subject w: anonymize 'subject none	;-- add default subject if no words are found
					insert insertion-point w
					p: next p							;-- correct parsing offset for previous insertion
					spec-end: next spec-end
				]
				subject: if single? subject [subject/1]	;-- default subject can only be set if it's unambiguous
				spec: copy/part pattern spec-end
			) :p
		]

		parse pattern [=spec= p:]
		tested-paths: clear []							;-- used to remove path existence test dupes (some anyway)
		tests: expand-tests p subject tested-paths

		reduce [spec tests]
	]
	
	set 'locate function [
		"Locate a row within SERIES that matches PATTERN"
		series  [series!] "Will be returned at found row index"
		pattern [block!]  "[row spec .. chain of tests]"
		/back "Locate last occurrence (starts from the tail)"
		/case "Values are matched using strict comparison"
		/same "Values are matched using sameness comparison"
		/local pos
	][
		set [spec: tests:] expand-pattern pattern

		;@@ this doesn't work (temporarily) because for-each anonymizes spec words
		;@@ R/S implementation will let `function` to the binding and this will work
		; unless set-word? spec/1 [						;-- we need position to track & return
		; 	insert spec to set-word! 'pos
		; ]
		; code: compose [if (tests) [result: get spec/1 break]]
		; reverse: back
		; apply for-each 'local

		;@@ so we have to access lower level functions from anonymous ctx
		each-ctx: context? first find body-of :for-each 'fill-info
		code: compose [if (tests) [result: skip ii/series ii/offset break]]	;@@ return won't work from here (caught by for-each-core)
		if ii: each-ctx/fill-info spec series code back case same [
			each-ctx/for-each-core ii [
				if ii/matched? ii/code					;-- ii/code is bound, original `code` isn't!
			] []
		]

		result
	]

	;-- cannot be based on remove-each because it also selects columns not marked by '-'
	set 'sift function [
		"Select only rows of SERIES that match PATTERN, and only named columns"
		series  [series! map! integer! pair!]					;-- all types supported by map-each
		pattern [block!]  "[row spec .. chain of tests]"
		/case "Values are matched using strict comparison"
		/same "Values are matched using sameness comparison"
	][
		set [spec: tests:] expand-pattern pattern
		spec-words: parse spec [collect any [
			'- | '| | set w word! keep (to get-word! w)
		|	skip
		]]
		buf: copy []
		code: compose/deep [							;@@ has to be composed, otherwise tests & spec don't get bound by map-each
			reduce/into [(spec-words)] clear buf		;-- tests may change word values, so we have to reduce them before that
			; either (tests) [buf][continue]				;@@ no longer works when tests evaluate to unset!
			any [all [(tests) buf] continue]
		]
		self: drop: yes									;-- preserve input type, omit rows not passing the tests
		unless scalar? series [series: copy series]		;-- don't modify the original
		apply map-each 'local
	]

	;-- see REP#85 for why `all []` should be left and it's expected to be true
	; #assert [
	; 	[ [subject] [any [all [] all []]] ]
	; 	= expand-pattern [.. |]
	; 	[ [subject] [all []] ]
	; 	= expand-pattern []
	; ]
	;@@ but that doesn't work yet and a special case is made:
	#assert [
		[ [subject] [any [true true]] ]
		= expand-pattern [.. |]
		[ [subject] [true] ]
		= expand-pattern []
	]
	
]

#localize [#assert [
	;-- basic tests
	[a b c      ] = sift [a 1 b 2 c] [.. word!]                           
	[1 2        ] = sift [a 1 b 2 c] [.. integer!]                        
	[1 2 3      ] = sift [1 2 3 4 5] [x .. x <= 3]                        
	[3 4 5      ] = sift [1 2 3 4 5] [x .. x >= 3]                        
	[3 4        ] = sift [1 2 3 4 5] [x .. x >= 3 x <= 4]                 
	[1 4 5      ] = sift [1 2 3 4 5] [x .. x >= 4 | x <= 1]               
	[2 3 5      ] = sift [1 2 3 4 5] [x .. x >= 2 [x = 5 | x <= 3]]       
	[2 3 5      ] = sift [1 2 3 4 5] [x .. (x >= 2) [(x = 5) | (x <= 3)]] 
	[1 3 5      ] = sift [1 2 3 4 5] [x .. find [1 | 3 | 5] x]            	;-- block should be untouched

	[1 3 5      ] = sift [1 2 3 4 5] [x -]                                	;-- has to remove 2nd column
	[1 3 5      ] = sift [1 2 3 4 5] [x - ..]                             
	[2 4 #[none]] = sift [1 2 3 4 5] [- x]                                	;-- has to remove 1st column
	[2 4        ] = sift [1 2 3 4 5] [- x |]                              
	[2 3 4 5    ] = sift [1 2 3 4 5] [- | x]                              
	[3 5        ] = sift [1 2 3 4 5] [- | x .. odd? x]                    

	[1 2 3 4 5  ] = sift [1 2 3 4 5] []                                   	;-- empty tests are truthy
	[1 2 3 4 5  ] = sift [1 2 3 4 5] [..]                                 
	[1 2 3 4 5  ] = sift [1 2 3 4 5] [.. | ]                              
	[1 2 3 4 5  ] = sift [1 2 3 4 5] [.. none | ]                         
	[           ] = sift [1 2 3 4 5] [.. none]                            
	[           ] = sift [1 2 3 4 5] [.. (none)]                          

	;-- tests inspired from the HOF selection
	o1: object [p: object [q: 1]]
	o2: object [p: object [r: 2]]
	o3: object [p: object [r: 3]]
	(reduce [o1]) = sift reduce [o1 o2 o3] [x .. x/p/q        ] 	;-- should not error out on non-existing paths
	(reduce [o1 o2 o3]) = sift reduce [o1 o2 o3] [x .. :x/p/q ] 	;-- get-paths too!
	; (reduce [o1]) = sift reduce [o1 o2 o3] [x .. :x/p/q       ] 	no longer a valid test in new Red
	(reduce [o1]) = sift reduce [o1 o2 o3] [x .. x/p/q > 0    ] 
	(reduce [o2]) = sift reduce [o1 o2 o3] [x .. /p x = o2    ] 
	(reduce [o3]) = sift reduce [o1 o2 o3] [x .. y: /p y/r > 2] 
	(reduce [o3]) = sift reduce [o1 o2 o3] [x .. x: /p x/r > 2] 	;-- x: override should not affect the result
	error?     try [sift reduce [o1 o2 o3] [x .. (x/p/q)     ]] 	;-- should error out since path is escaped
	(reduce [o3]) = sift reduce ['a 'b o3] [.. object!        ] 
	(reduce [o3]) = sift reduce ['a o2 o3] [.. object!  [r: 3] = to [] /p] 
	unset [o1 o2 o3]

	"^/^/^/" = sift "ab^/cd^/ef^/gh" [x .. x = lf]					;-- should preserve input type
	#(1 2)   = sift #(a 1 b 2)       [- x]        
	(s: sift s0: "ab^/cd^/ef^/gh" [x .. x = lf]  not s =? s0)		;-- should not modify original series
	(m: sift m0: #(a 1 b 2) [- x] m <> m0)

	[1x1 2x2 3x3] = sift [1x1 a 2x2 b 3x3 c] [.. pair!           ] 	;-- type filter
	[1x1 2x2 3x3] = sift [1x1 a 2x2 b 3x3 c] [x .. pair? x       ] 	;-- normal Red code as filter
	[1x1 2x2 3x3] = sift [1x1 a 2x2 b 3x3 c] [p: .. odd? index? p] 	;-- uses position
	[1x1 2x2 3x3] = sift [1x1 a 2x2 b 3x3 c] [.. /x              ] 	;-- path existence test as filter
	[1x1 2x2 3x3] = sift [1x1 a 2x2 b 3x3 c] [p .. p/x           ] 	;-- same, more explicit

	(reduce [face!]) = sift reduce [face! reactor! deep-reactor! scroller!] [.. /type = 'face] 

	[5 7 9] = (i: 1 sift [1 3 5 7 9] [x .. (i: i + 1) x > i     ]) 	;-- usage of side effects
	[5 7 9] = (i: 2 sift [1 3 5 7 9] [x .. x > i | (i: i + 1) no]) 


	;-- LOCATE basic tests
	[a 1 b 2 c  ] = locate      [a 1 b 2 c] [.. word!   ] 
	[  1 b 2 c  ] = locate      [a 1 b 2 c] [.. integer!] 
	[c          ] = locate/back [a 1 b 2 c] [.. word!   ] 
	[2 c        ] = locate/back [a 1 b 2 c] [.. integer!] 
	none?           locate/back [a 1 b 2 c] [.. none!   ] 
	none?           locate/back [         ] [.. integer!] 
	[1 2 3 4 5  ] = locate      [1 2 3 4 5] [x .. x <= 3]                        
	[    3 4 5  ] = locate      [1 2 3 4 5] [x .. x >= 3]                        
	[  2 3 4 5  ] = locate      [1 2 3 4 5] [x .. x >= 2 [x = 5 | x <= 3]]       
	[  2 3 4 5  ] = locate      [1 2 3 4 5] [x .. (x >= 2) [(x = 5) | (x <= 3)]] 
	[        5  ] = locate/back [1 2 3 4 5] [x .. (x >= 2) [(x = 5) | (x <= 3)]] 
	[    3 4 5  ] = locate      [1 2 3 4 5] [x .. find [3 | 5] x]                	;-- block should be untouched

	[1 2 3 4 5  ] = locate [1 2 3 4 5] [x -]             
	[1 2 3 4 5  ] = locate [1 2 3 4 5] [- x]             
	[    3 4 5  ] = locate [1 2 3 4 5] [- x .. x >= 3]   
	[        5  ] = locate [1 2 3 4 5] [x - .. x >= 5]   
	none?           locate [1 2 3 4 5] [x - | .. x >= 5] 	;-- last value is filtered out by `|`

	[1 2 3 4 5  ] = locate [1 2 3 4 5] []           	;-- empty tests are truthy
	[1 2 3 4 5  ] = locate [1 2 3 4 5] [..]         
	[1 2 3 4 5  ] = locate [1 2 3 4 5] [.. | ]      
	[1 2 3 4 5  ] = locate [1 2 3 4 5] [.. none | ] 
	none?           locate [1 2 3 4 5] [.. none]    
	none?           locate [1 2 3 4 5] [.. (none)]  

	;-- tests inspired from the HOF selection
	(
		mon: "sep"
		months: ["december" "november" "september"]
		["september"] = locate months [m .. find/match m mon]
	)
	(
		pts: [0x0 10x0 0x10 10x10 3x3 8x8]
		[3x3 8x8] = locate pts [p .. within? p - 5x5 -2x-2 3x3]
	)
	faces: reduce [
		make face! [size: 2x0]
		make face! [size: 0x0]
		make face! [size: 0x2]
	]
	single? locate/back faces [f .. [f/size/x * f/size/y = 0]] 
	single? locate/back faces [.. s: /size [s/x * s/y = 0]   ] 
	single? locate/back faces [.. s: /size [s/x * s/y = 0]   ] 
	single? locate      faces [.. /size = 0x2                ] 
	
	3 = index? locate [1 [a] 2 [b] 3 [c]] [- b .. b = [b]]
 
]]
; #include %prettify.red
; print "------ WORK HERE ------"
