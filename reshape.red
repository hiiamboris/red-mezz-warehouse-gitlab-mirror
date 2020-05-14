Red [
	title:   "RESHAPE mezzanine"
	purpose: "Build a block of code using expressions and conditions"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {See in the docs, and in the tests below}
]


; #include %assert.red

;@@ TODO: implement it in R/S to be more useful
context [
	empty-types: make typeset! [none! unset!]
	check: func [x [any-type!]] [either find empty-types type? :x [[]][:x]]

	set 'reshape function [
		"Deeply replace construction patterns in the BLOCK"
		block [block! paren!] "Will not be copied if does not contain any patterns"
		/local x
	][
		unless parse/case block [											;-- scan the block first - if no patterns are found, just return itself
			to [
				block! | paren! | '! | @ |
				/if | /else | /do | /use | /mixin
			] p: to end
		] [return block]

		while [not any [new-line? p head? p]] [p: back p]					;-- get back to the start of the line
		r: clear copy block													;-- preallocate the result
		append/part r block p												;-- copy the part that contains nothing special
		block: p															;-- start on the line of first found pattern

		=line-end=:   [p: [end | if (new-line? p) if (not line-start =? p)]]
		=bad-syntax=: [p: (do make error! rejoin ["Invalid syntax at: " mold/part p 40])]
		=update-end=: [p: opt if ((index? p) > index? line-end) line-end:]	;-- used after multiline expressions to ensure they are not repeated

		=expand+include-line=: [
			:line-start
			; (print ["INCLUDING:" mold/flat copy/part line-start line-end])
			while [
				p: if (p =? cond-start) break
			|	               set x [block! | paren!] (append/only r     reshape x)
			|	[['! | /use  ] set x           paren!] (append/only r  do reshape x)
			|	[[ @ | /mixin] set x           paren!] (append r check do reshape x)
			|	set x skip (append/only r :x)
			]
			:line-end
		]
		=global-conditions=: [
			while [
				=line-end= break
			|	/if   p: [if (include?: global-test: do/next p 'p) :p =update-end=]
			|	/else    [if (include?: not :global-test)]
			|	/do   p: [(do/next p 'p) :p =update-end=]
			|	ahead [/if | /else] :line-end break
			|	=bad-syntax=
			]
		]
		=line-conditions=: [
			while [															;-- `any` has a bad habit of stopping halfway, so using `while`
				/if   p: [if (last-test: do/next p 'p) :p]					;-- not using set/any by design: conditions should not return unset
			|	/else p: [if (not :last-test)]
			|	/do   p: [(do/next p 'p) :p]
			|	=line-end= =expand+include-line= break
			|	ahead [/if | /else] break									;-- condition failed, skip to the next line
			|	=bad-syntax=
			]
			:line-end
		]

		include?: last-test: global-test: yes								;-- inclusion flags are true by default
		unless parse/case block [any [										;-- use /case or it will accept words for refinements
																			;-- can't use `collect into r` because `keep` works as `keep/only` always
			;; find the condition start and line end first
			line-start: to [
				=line-end= line-end:
			|	[/if | /else | /do] to [=line-end= line-end:]
			] cond-start:
			; (print ["||" mold/flat/only copy/part line-start cond-start "||" mold/flat/only copy/part cond-start line-end "||"])

			;; now process conditions and decide what to include
			[
				if (cond-start =? line-start) =global-conditions=			;-- empty line => process global conditions
			|	if (include?) [												;-- skip it if inclusion is forbidden by global condition
					if (cond-start =? line-end) =expand+include-line=		;-- no conditions in this line => include it
				|	=line-conditions=										;-- else process conditions and decide
				]
			|	none														;-- just skip it if it's not allowed to be included
			]
			:line-end
		] end] [do make error! rejoin ["Internal Error: " mold line-start]]	;-- should always process the whole block
		r
	]
]

#assert [[             ] = r: reshape [] 'r]
#assert [( quote ()    ) = r: reshape quote () 'r]
#assert [[ 1           ] = r: reshape [!(1)] 'r]
#assert [[ []          ] = r: reshape [!([])] 'r]
#assert [( reduce [()] ) = r: reshape [!(())] 'r]
#assert [[ #[none]     ] = r: reshape [!(none)] 'r]
#assert [[             ] = r: reshape [@([])] 'r]
#assert [[             ] = r: reshape [@(())] 'r]
#assert [[             ] = r: reshape [@(none)] 'r]
#assert [[ #[false]    ] = r: reshape [@(false)] 'r]
#assert [[ 1           ] = r: reshape [!(x) /do x: 1] 'r]
#assert [[ []          ] = r: reshape [!(x) /do x: []] 'r]
#assert [[             ] = r: reshape [@(x) /do x: []] 'r]
#assert [[ ()          ] = r: reshape [!(x) /do x: quote ()] 'r]
#assert [[             ] = r: reshape [@(x) /do x: quote ()] 'r]
#assert [[             ] = r: reshape [@(:x) /do set/any 'x ()] 'r]

;; conditional inclusion
#assert [[             ] = r: reshape [1 2 /if no] 'r]
#assert [[ 1 2         ] = r: reshape [1 2 /if yes] 'r]
#assert [[ 1 2         ] = r: reshape [!(x) !(y) /if yes /do y: 1 + x: 1] 'r]
#assert [[             ] = r: reshape [!(x) !(y) /if no  /do y: 1 + x: 1] 'r]

#assert [[ 2           ] = r: reshape [
			/if no
	1
			/if yes
	2
			/else
	3
] 'r]
#assert [[             ] = r: reshape [1 2 /else] 'r]

;; global flags should not affect line flags; multiple /elses act like one
#assert [[ 2 4         ] = r: reshape [
			/if no
	1			/if yes
			/else
	2			/if yes
	3			/if no
			/else
	4
] 'r]


;; conditional /do
#assert [[ 3           ] = r: reshape [
			/do y: 3
	!(x) 	/if no /do y: 1 + x: 1
	!(y)
] 'r]
#assert [[ 1 2         ] = r: reshape [
			/do y: 3
	!(x) 	/if yes /do y: 1 + x: 1
	!(y)
] 'r]

;; test that multi-line expressions are only evaluated once
#assert [(
	i: 0
	reshape [
		/do i:
		i
		+
		1
		/do i: i + 1 /do i: i +
		1
	]
	i = 3
) 'i]

;; should not skip everything before the first pattern
#assert [[ x [3] x 7 ] = r: reshape [
	x
	[!(1 + 2)]
	x
	!(3 + 4)
] 'r]

;; should inline the inner block, expanded but not nested
#assert [[ 1 2        ] = r: reshape [
	@([	/if true
		1
		2
	])
] 'r]
