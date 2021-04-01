Red [
	title:   "FCATCH & PCATCH mezzanines"
	purpose: "Reimagined CATCH design variants"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		PCATCH - Pattern-matched CATCH

			Evaluates CASES block after catching a throw (similar to native CASE).
			Rethrows values for which there is no matching pattern in CASES.
			Returns:
			- on throw: `CASE CASES` result if any pattern matched
			- normally: result of CODE evaluation

			Automatic rethrow works as if `true [throw thrown]` line was appended to CASES.
			However you can do always the same manually, e.g.:
				pcatch [
					thrown = my-value [
						print "found it!"
						if 1 = random 2 [throw thrown]		;) coin toss :D
					]
				][
					do code
				]

			`pcatch [true [thrown]] [...]` is equivalent to `catch [...]`

		FCATCH - Filtered CATCH

			Catches only values for which FILTER returns a truthy value (and also calls HANDLER if provided).
			Rethrows values for which FILTER returns a falsey value.
			Returns:
			- on throw: HANDLER's result (if provided) or thrown value otherwise
			- normally: result of CODE evaluation

				fcatch/handler [thrown = my-value] [
					do code
				][
					print "found it!"
				]

			`fcatch [] [...]` is equivalent to `catch [...]` (because result of [] is unset - a truthy value)

		THROWN

			Returns the thrown value inside:
			- CASES block of PCATCH
			- FILTER and HANDLER of FCATCH
			Inside CODE it will be = none.
			Undefined outside the scopes of FCATCH & PCATCH.

		Notes

			Both trap RETURN & EXIT due to Red limitations.
			Due to #4416 issue, `throw/name` loses it's `name` during rethrow. Nothing can be done about it.

			See https://gitlab.com/-/snippets/1995436
			and https://github.com/red/red/issues/3755
			for full background on these designs and flaws of native catch
	}
]

#include %assert.red

context [
	with-thrown: func [code [block!] /local thrown] [		;-- needed to be able to get thrown from both *catch funcs
		do code
	]

	;-- this design allows to avoid runtime binding of filters
	;@@ should it be just :thrown or attempt [:thrown] (to avoid context not available error, but slower)?
	set 'thrown func ["Value of the last THROW from FCATCH or PCATCH"] bind [:thrown] :with-thrown

	set 'pcatch function [
		"Eval CODE and forward thrown value into CASES as 'THROWN'"
		cases [block!] "CASE block to evaluate after throw (normally not evaluated)"
		code  [block!] "Code to evaluate"
	] compose/deep [
		with-thrown [
			set/any
				(bind quote 'thrown :with-thrown)
				catch [return do code]
			;-- the rest mimicks `case append cases [true [throw thrown]]` behavior but without allocations
			forall cases [if do/next cases 'cases [break]]	;-- will reset cases to head if no conditions succeed
			if head? cases [throw thrown]					;-- outside of `catch` for `throw thrown` to work
			do cases/1										;-- evaluates the block after true condition
		]
	]

	set 'fcatch function [
		"Eval CODE and catch a throw from it when FILTER returns a truthy value"
		filter [block!] "Filter block with word THROWN set to the thrown value"
		code   [block!] "Code to evaluate"
		/handler        "Specify a handler to be called on successful catch"
			on-throw [block!] "Has word THROWN set to the thrown value"
	] compose/deep [
		with-thrown [
			set/any
				(bind quote 'thrown :with-thrown)
				catch [return do code]
			unless do filter [throw thrown]
			either handler [do on-throw][thrown]
		]
	]

]


#assert [1 = r: catch [fcatch         [            ] [1      ]  ] 'r]		;-- normal result
#assert [unset? catch [fcatch         [            ] [       ]  ] 'fcatch]
#assert [unset? catch [fcatch         [true        ] [       ]  ] 'fcatch]
#assert [2 = r: catch [fcatch         [            ] [throw 1] 2] 'r]		;-- unset is truthy, always catches
#assert [1 = r: catch [fcatch         [no          ] [throw 1] 2] 'r]
#assert [1 = r: catch [fcatch         [no          ] [throw/name 1 'abc] 2] 'r]
#assert [2 = r: catch [fcatch         [yes         ] [throw 1] 2] 'r]
#assert [1 = r: catch [fcatch         [even? thrown] [throw 1] 2] 'r]
#assert [2 = r: catch [fcatch         [even? thrown] [throw 4] 2] 'r]
#assert [3 = r: catch [fcatch/handler [even? thrown] [throw 3] [thrown * 2]] 'r]
#assert [8 = r: catch [fcatch/handler [even? thrown] [throw 4] [thrown * 2]] 'r]
#assert [9 = r: catch [loop 3 [fcatch/handler [] [throw 4] [break/return 9]]] 'r]			;-- break test
#assert [8 = r: catch [loop 3 [fcatch/handler [continue] [throw 4] [break/return 9]] 8] 'r]	;-- continue test

#assert [1 = r: catch [pcatch [              ] [throw 1] 2] 'r]				;-- no patterns matched, should rethrow
#assert [3 = r: catch [pcatch [true [3]      ] [throw 1]  ] 'r]				;-- catch-all
#assert [3 = r: catch [pcatch [true [throw 3]] [throw 1] 2] 'r]				;-- catch-all with custom throw
#assert [1 = r: catch [pcatch [even? thrown [thrown * 2]] [throw 1]] 'r]
#assert [4 = r: catch [pcatch [even? thrown [thrown * 2]] [throw 2]] 'r]
#assert [4 = r: catch [pcatch [even? thrown [thrown * 2] thrown < 5 [0]] [throw 2]] 'r]
#assert [0 = r: catch [pcatch [even? thrown [thrown * 2] thrown < 5 [0]] [throw 3]] 'r]
#assert [5 = r: catch [pcatch [even? thrown [thrown * 2] thrown < 5 [0]] [throw 5]] 'r]
#assert [9 = r: catch [repeat i 4 [pcatch [thrown < 3 [] 'else [break/return 9]] [throw i]]] 'r]	;-- break test
#assert [9 = r: catch [repeat i 4 [pcatch [thrown < 3 [continue] 'else [break/return 9]] [throw i]]] 'r]


{
	;-- this version is simpler but requires explicit `true [throw thrown]` to rethrow values that fail all case tests
	;-- and that I consider a bad thing

	set 'pcatch function [
		"Eval CODE and forward thrown value into CASES as 'THROWN'"
		cases [block!] "CASE block to evaluate after throw (normally not evaluated)"
		code  [block!] "Code to evaluate"
	] compose/deep [
		with-thrown [
			set/any
				(bind quote 'thrown :with-thrown)
				catch [return do code]
			case cases									;-- case is outside of catch for `throw thrown` to work
		]
	]
}

