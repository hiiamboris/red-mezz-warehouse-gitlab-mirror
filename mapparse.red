Red [
	title:   "MAPPARSE loop"
	purpose: "Leverage parse power to replace stuff in series"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		See also: forparse.red

		What is this:
			`mapparse spec series code`
			is somewhat analogous to
			`parse series [any [thru [change spec (do code)]]]`
			or
			`parse series [any [change spec (do code) | skip]]`
		So, self-modification is implied in this implementation.
		Not sure if we want to copy/deep first by default?

		Why not just use PARSE?
			Compare readability:
				parse spec-of :fun [any [thru [
					change [set w arg-typeset] (
						loop 1 [						;-- trick to make `continue` work
							...code...
							if cond [continue]
							...code...
						]
					)
				]]]
			Versus:
				mapparse [set w arg-typeset] spec-of :fun [
					...code...
					if cond [continue]
					...code...
				]
			See? ;)
			Then mind that PARSE has no BREAK support so it's hardly suitable for loops...

		Limitations:
			- traps exit & return - can't use them inside forparse
			- break/return will return nothing, because - see #4416

		BREAK and CONTINUE are working as expected

		Examples:
			>> mapparse [set x integer!] [0 1.0 "abc" 2] [probe x x * 2]
			0
			4
			== [0 1.0 "abc" 4]

			>> mapparse [set x integer!] [0 1.0 "abc" 2] [break]
			== [0 1.0 "abc" 2]
			(series is unchanged)
	}
]


#include %selective-catch.red

;@@ BUG: this traps exit & return - can't use them inside forparse
;@@ BUG: break/return will return nothing, because - see #4416
;@@ modifies series in place (undecided if it's good or not)
mapparse: func [
	"Change every SPEC found in SRS with the result of BODY evaluation"
	spec	[block!] "Parse expression to search for"
	srs		[any-block! any-string!] "Series to parse"
	body	[block!] "Will be evaluated whenever SPEC rule matches"
][
	catch-a-break [
		parse srs [any thru [
			change spec (catch-continue body)
		]]
	]
	srs
]


; probe mapparse [set x integer!] [0 1.0 "abc" 2] [probe x x * 2]