Red [
	title:   "FCATCH & PCATCH mezzanines"
	purpose: "Reimagined CATCH design variants"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		PCATCH - Pattern-matched CATCH

			Evaluates CASES block after catching a throw.
			Returns:
			- on throw: CASES result
			- normally: result of CODE evaluation

			Inside CASES you can rethrow the caught value with `throw thrown`, e.g.:
				pcatch [
					thrown = my-value [print "found it!"]
					true [throw thrown]			;) not handled here
				][
					do code
				]

		FCATCH - Filtered CATCH

			Catches only values for which FILTER returns a truthy value (and also calls HANDLER if provided).
			Rethrows values for which FILTER returns a falsey value.
			Returns:
			- on throw: HANDLER's result (if provided) or thrown value otherwise
			- normally: result of CODE evaluation

			Since rethrow is automatic here, it may be a bit shorter if you're wrapping unknown code:
				fcatch/handler [thrown = my-value] [
					do code
				][
					print "found it!"
				]

		THROWN

			Returns the thrown value inside:
			- CASES block of PCATCH
			- FILTER and HANDLER of FCATCH
			Inside CODE it will be = none.
			Undefined outside the scopes of FCATCH & PCATCH.

		Notes

			Both trap RETURN & EXIT due to Red limitations.

			See https://gitlab.com/-/snippets/1995436
			and https://github.com/red/red/issues/3755
			for full background on these designs and flaws of native catch
	}
]

context [
	with-thrown: func [code [block!] /local thrown] [	;-- needed to be able to get thrown from both *catch funcs
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
			case cases									;-- case is outside of catch for `throw thrown` to work
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

;@@ TODO: unittests
