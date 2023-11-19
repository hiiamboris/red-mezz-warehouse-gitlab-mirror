Red [
	title:   "RESHAPE mezzanine"
	purpose: "Build a block of code using expressions and conditions"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {See in the reshape.md, and in the tests below}
]

#include %hide-macro.red
#include %assert.red
; #include %parsee-standalone.red

;@@ TODO: implement it in R/S to be more useful
reshape: none
context [
	keep?: func [x [any-type!]] [
		switch/default type?/word :x [none! unset! [[]]] [:x]
	]
	
	swap: function [a b] [								;@@ export me somehow
		x: get a
		set a get b
		set b :x
	]
	
	;; new and limited reshape syntax:
	;; @[] inserts as value
	;; @() splices
	;; /if after non-empty line - enables/disables the line
	;; /if after empty line - enables/disables section (until next such /if)
	;; optional /prefix refinement to replace the default @ token (instead of /skip)
	set 'reshape function [
		"Deeply rewrite the block using provided grammar"
		block [any-list!]
		/with "If provided, becomes the 1st argument"
			grammar [any-list!] "A block of 1-2 values: [substitution-marker if-marker], default: [@ /if]"
	] bind [
		either with [swap 'grammar 'block][grammar: [@ /if]]
		=sub=:	any [grammar/1 =fail=]
		=if=:	any [grammar/2 =fail=]
		parse/case result: copy/deep block =block=: [
			at-line: opt =if-section= 
			any [p:
				end
			|	if (new-line? p) at-line: =if-section=
			|	=sub= [
					block! change only p (do p/2)
				|	paren! change p (keep? do p/2)
				]
			|	at-if: =if= =do-cond= [if (succ?) =rem-if= | =rem-line=]
			|	ahead any-list!
				(append/only lines at-line)
				into =block=
				(at-line: take/last lines)				;-- restore the start-of-line
			|	skip
			]
		]
		result
	] rules: context [									;-- rules are out for faster operation
		lines:			make [] 4
		=fail=:			[end skip]
		=do-cond=:		[p: (succ?: do/next p 'p) :p]
		=rem-if=:		[p: remove at-if]
		=rem-line=:		[p: remove at-line]
		=rem-section=:	[[to [p: =if= if (new-line? p)] | to end] remove at-if]
		=if-section=:	[at-if: =if= =do-cond= [if (:succ?) =rem-if= | =rem-section=]]
	]
	bind body-of rules :reshape
]

comment {	;-- two-pass version about 2x slower, but does not evaluate skipped substitutions
		result: copy/deep block
		;; first pass - process ifs
		if grammar/2 [
			parse/case result =block=: [
				at-line: opt =if-section= 
				any [p:
					end
				|	if (new-line? p) at-line: =if-section=
				|	at-if: =if= =do-cond= [if (succ?) =rem-if= | =rem-line=]
				|	ahead any-list!
					(append/only lines at-line)
					into =block=
					(at-line: take/last lines)				;-- restore the start-of-line
				|	skip
				]
			]
		]
		;; second pass - process substitutions
		types: make typeset! reduce [any-list! type? =sub=]
		parse/case result =block=: [
			any [to types [p:
				=sub= [
					block! change only p (do p/2)
				|	paren! change p (keep? do p/2)
				]
			|	ahead any-list! into =block=
			|	skip
			]]
		]
}

#hide [#assert [
	[             ] = reshape []
	( quote ()    ) = reshape quote ()
	[ 1           ] = reshape [@[1]]
	[ []          ] = reshape [@[[]]]
	( reduce [()] ) = reshape [@[()]]
	[ #[none]     ] = reshape [@[none]]
	[             ] = reshape [@([])]
	[             ] = reshape [@(())]
	[             ] = reshape [@(none)]
	[ #[false]    ] = reshape [@(false)]

	;; conditional inclusion
	;; conditional inclusion
	[             ] = reshape [1 2 /if no]
	[ 1 2         ] = reshape [1 2 /if yes]
	[ x y         ] = reshape [@['x] @('y) /if yes]
	[             ] = reshape [@['x] @('y) /if no ]
	[(1)          ] = reshape [(1 /if yes)]
	[( )          ] = reshape [(1 /if no )]
	[             ] = reshape [(1 /if yes) /if no]
	[( )          ] = reshape [(1 /if no)  /if yes]
	[(1)          ] = reshape [(1 /if yes) /if yes]
	[ 2           ] = reshape [
				/if no
		1
				/if yes
		2
				/if no
		3
	]
	[             ] = reshape [1 2 /if no]

	;; global flags should not affect line flags; multiple /elses act like one
	[ 2 4         ] = reshape [
				/if no
		1			/if yes
				/if yes
		2			/if yes
		3			/if no
				/if yes
		4
	]


	;; conditional /do
	;; disabled: /do removed as it brings little value and I want to keep grammar minimal
	; [ 1           ] = reshape [@[x] /do x: 1]
	; [ []          ] = reshape [@[x] /do x: []]
	; [             ] = reshape [@(x) /do x: []]
	; [ ()          ] = reshape [@[x] /do x: quote ()]
	; [             ] = reshape [@(x) /do x: quote ()]
	; [             ] = reshape [@(:x) /do set/any 'x ()]
	; [ 1 2         ] = reshape [!(x) !(y) /if yes /do y: 1 + x: 1]
	; [             ] = reshape [!(x) !(y) /if no  /do y: 1 + x: 1]
	; [ 3           ] = reshape [
				; /do y: 3
		; !(x) 	/if no /do y: 1 + x: 1
		; !(y)
	; ]
	; [ 1 2         ] = reshape [
				; /do y: 3
		; !(x) 	/if yes /do y: 1 + x: 1
		; !(y)
	; ]
	; ;; test that multi-line expressions are only evaluated once
	; (
		; i: 0
		; reshape [
			; /do i:
			; i
			; +
			; 1
			; /do i: i + 1 /do i: i +
			; 1
		; ]
		; i = 3
	; )

	;; should not skip everything before the first pattern
	[ x [3] x 7 ] = reshape [
		x
		[@[1 + 2]]
		x
		@[3 + 4]
	]

	;; one-liners should work
	[(1)     ] = reshape [ (1 /if yes)]
	[( )     ] = reshape [ (1 /if no )]
	
	;; disabled: for the sake of performance substitutions are not reshaped
	; [ 1      ] = reshape [@(1 /if yes)]
	; [        ] = reshape [@(1 /if no )]
	; [ 1      ] = reshape [@[1 /if yes]]
	; unset? first reshape [@[1 /if no ]]
	; [ 1 2        ] = reshape [
		; @([	/if true
			; 1
			; 2
		; ])
	; ]

	;; escape mechanism: needed when reshape block contains other calls to reshape
	;; disabled: /with should be the way now
	; [[! (1 + 2)]] = reshape [  /skip [!(1 + 2)] ]
	; [ ! (1 + 2) ] = reshape [@(/skip [!(1 + 2)])]

	;; deep processing
	[ x [3] x (7) ] = reshape [x [@[1 + 2]] x (@[3 + 4])]

	;; resilience to keep/collect type issues and word overrides
	[1 (2 (3) (4)) (5 6)] = reshape [1 (2 (3) (4 /if yes)) (5 6 /if yes)]

	;; no processing of disabled items - disabled
	;; for the sake of 2x performance they are processed
	; [             ] = reshape [@(do make error! "oops") /if no]

	;; compiler may insert unwanted newlines - should not break reshape
	[ 3           ] = reshape [
		@
		(1 + 2)
	]
	
	;; should restore start-of-line when leaves the inner scope
	[0] = reshape [
		0
		[
			1
			2	/if true
		] /if false
	]
	
	;; this behavior is not checked atm, but is invalid
	[0 4 5] = reshape [
		0
		[
			1
			2	/if true 3
		] /if false 4 /if true 5
	]
	
	;; grammar test
	[1 2 3        ] = reshape/with [@uh @oh] [1 @uh(1 + 1) 3 @oh yes]
	[1 2 3 @oh yes] = reshape/with [@uh    ] [1 @uh(1 + 1) 3 @oh yes]
]]

comment [	;-- speed tests - reshape is ~10x slower than compose, which is great result for a mezz
	recycle/off
	; clock/times [compose []] 1e6
	; clock/times [reshape-light []] 1e6
	; clock/times [reshape []] 1e6
	
	clock/times [compose/deep [(1 + 2) 3 4 (5 * 6)]] 1e6
	; clock/times [reshape-light [@(1 + 2) 3 4 @(5 * 6)]] 1e6
	clock/times [reshape [@(1 + 2) 3 4 @(5 * 6)]] 1e6

	pname: "program"
	ver: "1.0"
	desc: none
	author: none
	clock/times [
		form compose/deep [  ;-- uses ability of FORM to skip unset values
			(pname) (ver)
			(any [desc ()])
			(either author [rejoin ["by "author]][()])
			#"^/"
		]
	] 1e5
	clock/times [
		form reshape [
			@(pname) @(ver)	@(desc)
			"by"	/if author
			@(author) #"^/"
		]
	] 1e5
	clock/times [
		form reshape/with [@] [
			@(pname) @(ver)	@(desc)
			"by"	/if author
			@(author) #"^/"
		]
	] 1e5
]
