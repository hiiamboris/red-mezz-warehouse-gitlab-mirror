Red [
	title:   "APPLY mezzanine"
	purpose: "Specify function arguments as key-value pairs"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		Implements approach (5) of https://github.com/greggirwin/red-hof/blob/master/apply.md
		Accepts an object, or a block that is just fed to `object` constructor internally.
		Does not evaluate the values! This is handy when passing an object to it:
			apply my-func object [
				arg1: make a value
				arg2: make a value..
			]
		`object` already evaluated everything.
		`construct/only` may be used instead to prevent evaluation.

		Examples:
			pwd                     => apply pwd []
			print probe what-dir    => apply print [value: apply probe [value: apply what-dir []]]
			find/match "abcd" "ab"  => apply find [series: "abcd" value: "ab" match: yes]
			? ?                     => apply ? construct [word: ?]
			quote (quote)           => apply quote construct [value: (quote)]
			quote none              => apply quote construct/only [value: none]

		Worth adding approach (1) into it, as /fixed or /positional (too long a name!).
		In this case, we should probably also not evaluate the given block.
		Also worth adding some type checking and other call validity checking code.

		Should we rename /only to /construct or something?
		I used it to construct a call and then relay this call to another process (by molding it and reading back).
		Otherwise, there probably little need for it?

		Also, should function name be a lit-arg?
		I expect the main use cases will have a literally written function name,
		and where that is not enough, a paren could be used. E.g.:
			apply (pick [func1 func2] condition) [...]
		Lit-arg will also allow us to pass a function value to it without parens
		(though currently that's impossible since we can't use function value to construct a path)
			apply :myfunc [...]
	}
]


;@@ TODO: implement issue #1 of red-hof repo?

context [
	;; we must ignore set-words, e.g. `return:`
	arg-typeset: make typeset! [word! get-word! lit-word! refinement!]

	set 'mezz-apply function [							;@@ name to be used during transition; to be excluded eventually
		"Call a function named NAME with a set of arguments ARGS"
		'name [word! path!]		"Use parens to pass expression results"
		args [block! object!]	"Block is implicitly converted to an object"
		/only "Do not evaluate, only return the call"
	][
		if block? args [args: object args]
		fun: get/any name
		#assert [any-function? :fun]

		path: copy to path! name
		call: reduce [path]
		keep?: yes											;-- flag to add or not the refinement arguments; true initially for mandatory args
		parse spec-of :fun [any [							;@@ this will benefit from `forparse`, but I don't want an extra dependency for now
			thru set w arg-typeset (
				loop 1 [										;-- trick to make `continue` work
					type: type? w
					set/any 'v select args w: to word! w			;-- fetch the provided value (defaults to none)
					case [
						type = refinement! [						;-- refinement goes to path and turns on/off the subsequent arguments
							if set/any 'keep? :v [append path w]	;-- any truthy value is accepted for turning refinement on
							continue								;-- don't add it as argument too
						]
						not keep? [continue]						;-- skip arguments if we skipped refinement
						type = word! [append call 'quote]			;-- prevent double evaluation of normal args
						all [										;-- lit-args sometimes require `(quote :v)` format
							type = lit-word!
							not lit-word? :v						;-- words and lit-words can be passed as is
							not word? :v
						][ v: as paren! reduce ['quote :v] ]
					]
					append/only call :v								;-- add the argument value
				]
			)
		]]
		if single? :call/1 [change call :call/1]			;-- turn singular path back into a word

		either only [call][do call]
	]
]
