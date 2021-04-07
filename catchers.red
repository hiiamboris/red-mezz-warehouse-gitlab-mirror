Red [
	title:   "TRAP, FCATCH & PCATCH mezzanines"
	purpose: "Reimagined TRY & CATCH design variants, fixed ATTEMPT"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		TRAP - Enhances native TRY with /CATCH refinement

			Backward-compatible with native TRY, ideally should replace it.
			But we cannot override it (yet) because it traps RETURN & EXIT.

			In addition to native TRY, supports:
				/catch handler [function! block!]
			HANDLER is called whenever TRAP successfully catches an error.
				If it's a block, it should use THROWN to get the error.
				If it's a function, it should accept the error as it's argument.

			Returns:
			- on error: return of HANDLER if provided, error itself otherwise
			- normally: result of CODE evaluation

			Common code pattern:
				error: try/all [set/any 'result do code  'ok]
				unless error == 'ok [print error  result: 'default]
				:result
			Becomes much cleaner:
				trap/all/catch code [print error  'default]


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
			- HANDLER of TRY
			Inside CODE it will be = none.
			Undefined outside the scopes of TRY, FCATCH & PCATCH.


		ATTEMPT
			Fixed of #3755 issue.


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
	with-thrown: func [code [block!] /thrown] [			;-- needed to be able to get thrown from both *catch funcs
		do code
	]

	;-- this design allows to avoid runtime binding of filters
	;@@ should it be just :thrown or attempt [:thrown] (to avoid context not available error, but slower)?
	set 'thrown func ["Value of the last THROW from FCATCH or PCATCH"] bind [:thrown] :with-thrown

	set 'pcatch function [
		"Eval CODE and forward thrown value into CASES as 'THROWN'"
		cases [block!] "CASE block to evaluate after throw (normally not evaluated)"
		code  [block!] "Code to evaluate"
	] bind [
		with-thrown [
			set/any 'thrown catch [return do code]
			;-- the rest mimicks `case append cases [true [throw thrown]]` behavior but without allocations
			forall cases [if do/next cases 'cases [break]]	;-- will reset cases to head if no conditions succeed
			if head? cases [throw :thrown]					;-- outside of `catch` for `throw thrown` to work
			do cases/1										;-- evaluates the block after true condition
		]
	] :with-thrown
	;-- bind above binds `thrown` and `code` but latter is rebound on func construction
	;-- as a bonus, `thrown` points to a value, not to a function, so a bit faster

	set 'fcatch function [
		"Eval CODE and catch a throw from it when FILTER returns a truthy value"
		filter [block!] "Filter block with word THROWN set to the thrown value"
		code   [block!] "Code to evaluate"
		/handler        "Specify a handler to be called on successful catch"
			on-throw [block!] "Has word THROWN set to the thrown value"
	] bind [
		with-thrown [
			set/any 'thrown catch [return do code]
			unless do filter [throw :thrown]
			either handler [do on-throw][:thrown]
		]
	] :with-thrown

	set 'trap function [					;-- backward-compatible with native try, but traps return & exit, so can't override
		"Try to DO a block and return its value or an error"
		code [block!]
		/all   "Catch also BREAK, CONTINUE, RETURN, EXIT and THROW exceptions"
		/catch "If provided, called upon exceptiontion and handler's value is returned"
			handler [block! function!] "func [error][] or block that uses THROWN"
			;@@ maybe also none! to mark a default handler that just prints the error?
		/local result
	] bind [
		with-thrown [
			plan: [set/any 'result do code  'ok]
			set 'thrown either all [					;-- returns 'ok or error object ;@@ use `apply`
				try/all plan
			][	try     plan
			]
			case [
				thrown == 'ok   [:result]
				block? :handler [do handler]
				'else           [handler thrown]		;-- if no handler is provided - this returns the error
			]
		]
	] :with-thrown

]


attempt: func [
	"Tries to evaluate a block and returns result or NONE on error"
	code [block!]
	/safer "Capture all possible errors and exceptions"
][
	either safer [
		trap/all/catch code [none]
	][
		try [return do code] none						;-- faster than trap
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

#assert [unset?       trap []]							;-- native try compatibility tests
#assert [1       = r: trap [1] 'r]
#assert [3       = r: trap [1 + 2] 'r]
#assert [error?    r: trap [1 + none] 'r]
#assert [error?    r: trap/all [throw 3 1] 'r]
#assert [error?    r: trap/all [continue 1] 'r]
#assert [10      = r: trap/catch [1 + none] [10] 'r]	;-- /catch tests
#assert ['script = r: trap/catch [1 + none] [select thrown 'type] 'r]
#assert [6       = r: trap/all/catch [throw 3 1] [2 * select thrown 'arg1] 'r]

#assert [unset? attempt []]
#assert [3    = r: attempt [1 + 2] 'r]
#assert [none = r: attempt [1 + none] 'r]
#assert [error? r: attempt [make error! "oops"] 'r]		;-- this is where it's different from native attempt
#assert [none = r: attempt/safer [throw 123] 'r]
#assert [none = r: attempt/safer [continue] 'r]


{
	;-- this version is simpler but requires explicit `true [throw thrown]` to rethrow values that fail all case tests
	;-- and that I consider a bad thing

	set 'pcatch function [
		"Eval CODE and forward thrown value into CASES as 'THROWN'"
		cases [block!] "CASE block to evaluate after throw (normally not evaluated)"
		code  [block!] "Code to evaluate"
	] bind [
		with-thrown [
			set/any 'thrown catch [return do code]
			case cases									;-- case is outside of catch for `throw thrown` to work
		]
	] :with-thrown
}
