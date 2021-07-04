Red [
	title:   "SIFT & LOCATE mezzanines"
	purpose: "High-level series items locator & filter"
	author:  @hiiamboris
	license: BSD-3
	notes: {
		See sift-locate.md for details
	}
]

#include %assert.red

#include %setters.red									;-- we need `anonymize`
#include %new-each.red									;-- based on extended foreach/map-each capabilities
#include %new-apply.red									;-- need `apply` to dispatch refinements

context [
	;-- this one is tricky but much faster than `attempt` and try/attempt are probably the only type-agnostic tests
	;-- get succeeds = path exists = we get `not none` = true
	;-- get fails = no path = we get `not error` = false
	;-- should not return false if path exists but has a falsey value!
	path-exists?: func [path [path!]] [
		not try [get/any path  none]
	]
	#assert [(b: [a 1]             path-exists? 'b/a) 'path-exists?]
	;@@ this technically fails, but I don't care since my aim is to avoid path errors rather than a precise check:
	; #assert [(b: [a 1]         not path-exists? 'b/b) 'path-exists?]
	#assert [(o: object [a: 1]     path-exists? 'o/a) 'path-exists?]
	#assert [(o: object [a: 1] not path-exists? 'o/b) 'path-exists?]

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
					path-exists? (to lit-path! path)
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
				if ii/matched? code
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
			either (tests) [buf][continue]
		]
		self: drop: yes									;-- preserve input type, omit rows not passing the tests
		unless scalar? series [series: copy series]		;-- don't modify the original
		apply map-each 'local
	]

	;-- see REP#85 for why `all []` should be left and it's expected to be true
	; #assert [
	; 	[ [subject] [any [all [] all []]] ]
	; 	= r: expand-pattern [.. |]  'r
	; ]
	; #assert [
	; 	[ [subject] [all []] ]
	; 	= r: expand-pattern []  'r
	; ]
	;@@ but that doesn't work yet and a special case is made:
	#assert [
		[ [subject] [any [true true]] ]
		= r: expand-pattern [.. |]  'r
	]
	#assert [
		[ [subject] [true] ]
		= r: expand-pattern []  'r
	]
	
]

;-- basic tests
#assert [[a b c      ] = b: sift [a 1 b 2 c] [.. word!]                            'b]
#assert [[1 2        ] = b: sift [a 1 b 2 c] [.. integer!]                         'b]
#assert [[1 2 3      ] = b: sift [1 2 3 4 5] [x .. x <= 3]                         'b]
#assert [[3 4 5      ] = b: sift [1 2 3 4 5] [x .. x >= 3]                         'b]
#assert [[3 4        ] = b: sift [1 2 3 4 5] [x .. x >= 3 x <= 4]                  'b]
#assert [[1 4 5      ] = b: sift [1 2 3 4 5] [x .. x >= 4 | x <= 1]                'b]
#assert [[2 3 5      ] = b: sift [1 2 3 4 5] [x .. x >= 2 [x = 5 | x <= 3]]        'b]
#assert [[2 3 5      ] = b: sift [1 2 3 4 5] [x .. (x >= 2) [(x = 5) | (x <= 3)]]  'b]
#assert [[1 3 5      ] = b: sift [1 2 3 4 5] [x .. find [1 | 3 | 5] x]             'b]	;-- block should be untouched

#assert [[1 3 5      ] = b: sift [1 2 3 4 5] [x -]                                 'b]	;-- has to remove 2nd column
#assert [[1 3 5      ] = b: sift [1 2 3 4 5] [x - ..]                              'b]
#assert [[2 4 #[none]] = b: sift [1 2 3 4 5] [- x]                                 'b]	;-- has to remove 1st column
#assert [[2 4        ] = b: sift [1 2 3 4 5] [- x |]                               'b]
#assert [[2 3 4 5    ] = b: sift [1 2 3 4 5] [- | x]                               'b]
#assert [[3 5        ] = b: sift [1 2 3 4 5] [- | x .. odd? x]                     'b]

#assert [[1 2 3 4 5  ] = b: sift [1 2 3 4 5] []                                    'b]	;-- empty tests are truthy
#assert [[1 2 3 4 5  ] = b: sift [1 2 3 4 5] [..]                                  'b]
#assert [[1 2 3 4 5  ] = b: sift [1 2 3 4 5] [.. | ]                               'b]
#assert [[1 2 3 4 5  ] = b: sift [1 2 3 4 5] [.. none | ]                          'b]
#assert [[           ] = b: sift [1 2 3 4 5] [.. none]                             'b]
#assert [[           ] = b: sift [1 2 3 4 5] [.. (none)]                           'b]

;-- tests inspired from the HOF selection
o1: object [p: object [q: 1]]
o2: object [p: object [r: 2]]
o3: object [p: object [r: 3]]
#assert [(reduce [o1]) = b: sift reduce [o1 o2 o3] [x .. x/p/q        ]  'b]	;-- should not error out on non-existing paths
#assert [(reduce [o1]) = b: sift reduce [o1 o2 o3] [x .. :x/p/q       ]  'b]	;-- get-paths too!
#assert [(reduce [o1]) = b: sift reduce [o1 o2 o3] [x .. x/p/q > 0    ]  'b]
#assert [(reduce [o2]) = b: sift reduce [o1 o2 o3] [x .. /p x = o2    ]  'b]
#assert [(reduce [o3]) = b: sift reduce [o1 o2 o3] [x .. y: /p y/r > 2]  'b]
#assert [(reduce [o3]) = b: sift reduce [o1 o2 o3] [x .. x: /p x/r > 2]  'b]	;-- x: override should not affect the result
#assert [error?     b: try [sift reduce [o1 o2 o3] [x .. (x/p/q)     ]]  'b]	;-- should error out since path is escaped
#assert [(reduce [o3]) = b: sift reduce ['a 'b o3] [.. object!        ]  'b]
#assert [(reduce [o3]) = b: sift reduce ['a o2 o3] [.. object!  [r: 3] = to [] /p]  'b]
unset [o1 o2 o3]

#assert ["^/^/^/" = s: sift "ab^/cd^/ef^/gh" [x .. x = lf]  's]					;-- should preserve input type
#assert [#(1 2)   = m: sift #(a 1 b 2)       [- x]          'm]
#assert [(s: sift s0: "ab^/cd^/ef^/gh" [x .. x = lf]  not s =? s0)  's0]		;-- should not modify original series
#assert [(m: sift m0: #(a 1 b 2) [- x] m <> m0)            'm0]

#assert [[1x1 2x2 3x3] = b: sift [1x1 a 2x2 b 3x3 c] [.. pair!           ]  'b]	;-- type filter
#assert [[1x1 2x2 3x3] = b: sift [1x1 a 2x2 b 3x3 c] [x .. pair? x       ]  'b]	;-- normal Red code as filter
#assert [[1x1 2x2 3x3] = b: sift [1x1 a 2x2 b 3x3 c] [p: .. odd? index? p]  'b]	;-- uses position
#assert [[1x1 2x2 3x3] = b: sift [1x1 a 2x2 b 3x3 c] [.. /x              ]  'b]	;-- path existence test as filter
#assert [[1x1 2x2 3x3] = b: sift [1x1 a 2x2 b 3x3 c] [p .. p/x           ]  'b]	;-- same, more explicit

#assert [(reduce [face!]) = b: sift reduce [face! reactor! deep-reactor! scroller!] [.. /type = 'face]  'b]

#assert [[5 7 9] = (i: 1 b: sift [1 3 5 7 9] [x .. (i: i + 1) x > i     ])  'b]	;-- usage of side effects
#assert [[5 7 9] = (i: 2 b: sift [1 3 5 7 9] [x .. x > i | (i: i + 1) no])  'b]


;-- LOCATE basic tests
#assert [[a 1 b 2 c  ] = b: locate      [a 1 b 2 c] [.. word!   ]  'b]
#assert [[  1 b 2 c  ] = b: locate      [a 1 b 2 c] [.. integer!]  'b]
#assert [[c          ] = b: locate/back [a 1 b 2 c] [.. word!   ]  'b]
#assert [[2 c        ] = b: locate/back [a 1 b 2 c] [.. integer!]  'b]
#assert [none?           b: locate/back [a 1 b 2 c] [.. none!   ]  'b]
#assert [none?           b: locate/back [         ] [.. integer!]  'b]
#assert [[1 2 3 4 5  ] = b: locate      [1 2 3 4 5] [x .. x <= 3]                         'b]
#assert [[    3 4 5  ] = b: locate      [1 2 3 4 5] [x .. x >= 3]                         'b]
#assert [[  2 3 4 5  ] = b: locate      [1 2 3 4 5] [x .. x >= 2 [x = 5 | x <= 3]]        'b]
#assert [[  2 3 4 5  ] = b: locate      [1 2 3 4 5] [x .. (x >= 2) [(x = 5) | (x <= 3)]]  'b]
#assert [[        5  ] = b: locate/back [1 2 3 4 5] [x .. (x >= 2) [(x = 5) | (x <= 3)]]  'b]
#assert [[    3 4 5  ] = b: locate      [1 2 3 4 5] [x .. find [3 | 5] x]                 'b]	;-- block should be untouched

#assert [[1 2 3 4 5  ] = b: locate [1 2 3 4 5] [x -]              'b]
#assert [[1 2 3 4 5  ] = b: locate [1 2 3 4 5] [- x]              'b]
#assert [[    3 4 5  ] = b: locate [1 2 3 4 5] [- x .. x >= 3]    'b]
#assert [[        5  ] = b: locate [1 2 3 4 5] [x - .. x >= 5]    'b]
#assert [none?           b: locate [1 2 3 4 5] [x - | .. x >= 5]  'b]	;-- last value is filtered out by `|`

#assert [[1 2 3 4 5  ] = b: locate [1 2 3 4 5] []            'b]	;-- empty tests are truthy
#assert [[1 2 3 4 5  ] = b: locate [1 2 3 4 5] [..]          'b]
#assert [[1 2 3 4 5  ] = b: locate [1 2 3 4 5] [.. | ]       'b]
#assert [[1 2 3 4 5  ] = b: locate [1 2 3 4 5] [.. none | ]  'b]
#assert [none?           b: locate [1 2 3 4 5] [.. none]     'b]
#assert [none?           b: locate [1 2 3 4 5] [.. (none)]   'b]

;-- tests inspired from the HOF selection
#assert [(
	mon: "sep"
	months: ["december" "november" "september"]
	["september"] = b: locate months [m .. find/match m mon]
) 'b]
#assert [(
	pts: [0x0 10x0 0x10 10x10 3x3 8x8]
	[3x3 8x8] = b: locate pts [p .. within? p - 5x5 -2x-2 3x3]
) 'b]
faces: reduce [
	a: make face! [size: 2x0]
	b: make face! [size: 0x0]
	c: make face! [size: 0x2]
]
#assert [single? b: locate/back faces [f .. [f/size/x * f/size/y = 0]]  'b]
#assert [single? b: locate/back faces [.. s: /size [s/x * s/y = 0]   ]  'b]
#assert [single? b: locate/back faces [.. s: /size [s/x * s/y = 0]   ]  'b]
#assert [single? b: locate      faces [.. /size = 0x2                ]  'b]

; #include %prettify.red
; print "------ WORK HERE ------"
