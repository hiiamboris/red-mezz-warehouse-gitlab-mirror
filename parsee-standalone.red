Red [
	title:   "PARSE-DUMP dumper an PARSEE tool wrapper"
	purpose: "Visualize parsing progress using PARSEE command-line tool"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		;@@@@@@@
	}
	notes: {
		;@@@@@@@
	}
]




; #include %assert.red


once: func [
	"Set value of WORD to VAL only if it's unset"
	'word [set-word!]
	val   [default!] "New value"
][
	if unset? get/any word [set word :val]
	:val
]

default: func [
	"If SUBJ's value is none, set it to VAL"
	'subj [set-word! set-path!]
	val   [default!] "New value"
][
	; if set-path? subj [subj: as path! subj]				;-- get does not work on set-paths
	if none =? get/any subj [set subj :val]				;-- `=?` is like 5% faster than `=`, and 2x faster than `none?`
	:val
]

maybe: func [
	"If SUBJ's value is not strictly equal to VAL, set it to VAL (for use in reactivity)"
	'subj [set-word! set-path!]
	val   [default!] "New value"
	/same "Use =? as comparator"
][
	if either same [:val =? get/any subj][:val == get/any subj] [return :val]
	set subj :val
]

import: function [
	"Import words from context CTX into the global namespace"
	ctx [object!]
	/only words [block!] "Not all, just chosen words"
][
	either only [
		foreach word words [set/any 'system/words/:word :ctx/:word]
	][
		set/any  bind words-of ctx system/words  values-of ctx
	]
]

export: function [
	"Export a set of bound words into the global namespace"
	words [block!]
][
	foreach w words [set/any 'system/words/:w get/any :w]
]

anonymize: function [
	"Return WORD bound in an anonymous context and set to VALUE"
	word [any-word!] value [any-type!]
][
	o: construct change [] to set-word! word
	set/any/only o :value
	bind word o
]


;-- there's a lot of ways this function can be written carelessly...



;; macro allows to avoid a lot of runtime overhead, thus allows using `quietly` with paths in critical code
;@@ unfortunate limitation: only applicable to objects, set-quiet cannot work with /x /y of a pair or components of time/date
#macro [p: 'quietly :p word! [set-path! | set-word!]] func [s e /local path] [
	either set-word? s/2 [
		compose [set-quiet quote (s/2)]					;-- set-quiet returns the value after #5146
	][
		path: to block! s/2								;-- required for R2 that can't copy/part paths!
		token: switch type?/word token: last path [
			word! [to lit-word! token]
			get-word! paren! [token]
		]
		compose [set-quiet in (to path! copy/part path back tail path) (:token)]	
	]	
]
									;-- `anonymize`




#macro [#debug 'on       ] func [s e] [*debug?*: on  []]
#macro [#debug 'off      ] func [s e] [*debug?*: off []]
#macro [#debug 'set word!] func [s e] [
	either block? get/any '*debug?* [
		append *debug?* s/3
	][
		*debug?*: reduce [s/3]
	]
	[]
]
; #macro [#debug not ['on | 'off | 'set] opt word! block!] func [[manual] s e /local code] [	;-- not R2-compatible!
#macro [#debug [['on | 'off | 'set] (c: [end skip]) | (c: [])] c opt word! block!] func [[manual] s e /local code] [
	; if either block? s/2 [:*debug?* <> off][attempt [find *debug?* s/2]] [	;-- not R2-compatible
	if either block? s/2 [all [value? '*debug?*  off <> get/any '*debug?*]][attempt [find *debug?* s/2]] [
		code: e/-1
	]
	remove/part s e
	if code [insert s code]
	s
]

; #debug on		;@@ this prevents setting it to a word value because of double-inclusion #4422
#do [unless value? '*debug?* [*debug?*: on]]			;-- only enable it for the first time










#macro [#assert 'on]  func [s e] [assertions: on  []]
#macro [#assert 'off] func [s e] [assertions: off []]
#do [unless value? 'assertions [assertions: on]]		;-- only reset it on first include

#macro [#assert block!] func [[manual] s e] [			;-- allow macros within assert block!
	nl: new-line? s										;-- preserve newline marker state before #assert
	either assertions [change s 'assert][remove/part s e]
	new-line s nl
]

context [
	next-newline?: function [b [block!]] [
		forall b [if new-line? b [return b]]
		tail b
	]

	set 'assert function [
		[no-trace]
		"Evaluate a set of test expressions, showing a backtrace if any of them fail"
		tests [block!] "Delimited by new-line, optionally followed by an error message"
		/local result
	][
		while [not tail? tests] [
			set/any 'result do/next bgn: tests 'tests
			all [
				:result
				any [
					new-line? tests
					tail? tests
					all [string? :tests/1 new-line? next tests]
				]
				continue								;-- total success, skip to the next test
			]

			end: next-newline? tests
			if 0 <> left: offset? tests end [			;-- check assertion alignment
				if any [
					left > 1							;-- more than one free token before the newline
					not string? :tests/1				;-- not a message between code and newline
				][
					do make error! form reduce [
						"Assertion is not new-line-aligned at:"
						mold/part bgn 100				;-- mold the original code
					]
				]
				tests: end								;-- skip the message
			]

			unless :result [							;-- test fails, need to repeat it step by step
				msg:     either left = 1 [first end: back end][""]
				print ["ASSERTION FAILED!" msg]
				expr:    copy/part bgn end
				full:    any [attempt [to integer! system/console/size/x] 80]
				half:    to integer! full - 22 / 2		;-- 22 is 1 + length? "  Check  failed with "
				result': mold/flat/part :result half
				expr':   mold/flat/part :expr   half
				print ["  Check" expr' "failed with" result' "^/  Reduction log:"]
				trace/all expr
				;; no error thrown, to run other assertions
			]
		]
		exit											;-- no return value
	]
]

; #include %localize-macro.red
; #localize [#assert [
	; a: 123
	; not none? find/only [1 [1] 1] [1]
	; 1 = 1
	; 100
	; 1 = 2
	; ;3 = 2 4
	; 2 = (2 + 1) "Message"
	; 3 + 0 = 3

	; 2													;-- valid multiline assertion
	; -
	; 1
	; =
	; 1
	
	; #assert [1 + 1 > 3]									;-- reentry should be supported, as some assertions use funcs with assertions
; ]]






#macro [#localize block!] func [[manual] s e] [			;-- allow macros within local block!
	remove/part insert s compose/deep/only [do reduce [function [] (s/2)]] 2
	s													;-- reprocess
]





with: func [
	"Bind CODE to a given context CTX"
	ctx [any-object! function! any-word! block!]
		"Block [x: ...] is converted into a context, [x 'x ...] is used as a list of contexts"
	code [block!]
][
	case [
		not block? :ctx  [bind code :ctx]
		set-word? :ctx/1 [bind code context ctx]
		'otherwise       [foreach ctx ctx [bind code do :ctx]  code]		;-- `do` decays lit-words and evals words, but doesn't allow expressions
		; 'otherwise       [while [not tail? ctx] [bind code do/next ctx 'ctx]  code]		;-- allows expressions
		; 'otherwise       [foreach ctx reduce ctx [bind code :ctx]  code]	;-- `reduce` is an extra allocation
	]
]

#localize []
			;-- used by composite func to bind exprs





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
		/keep  "Capture and save the call stack in the error object"
		/catch "If provided, called upon exceptiontion and handler's value is returned"
			handler [block! function!] "func [error][] or block that uses THROWN"
			;@@ maybe also none! to mark a default handler that just prints the error?
		/local result
	] bind [
		with-thrown [
			plan: [set/any 'result do code  'ok]
			set 'thrown try/:all/:keep plan				;-- returns 'ok or error object
			case [
				thrown == 'ok   [:result]
				block? :handler [do handler]
				'else           [handler thrown]		;-- if no handler is provided - this returns the error
			]
		]
	] :with-thrown
	
	;@@ of course this traps `return` because of #4416
	set 'following function [
		"Guarantee evaluation of CLEANUP after leaving CODE"
		code    [block!] "Code that can use break, continue, throw"
		cleanup [block!] "Finalization code"
	][
		do/trace code :cleaning-tracer
	]
	cleaning-tracer: func [[no-trace]] bind [[end] do cleanup] :following	;-- [end] filter minimizes interpreted slowdown
]


#localize []

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
		;-- used by composite func to trap errors


context [
	non-paren: charset [not #"("]

	trap-error: function [on-err [function! string!] :code [paren!]] [
		trap/catch
			as [] code
			pick [ [on-err thrown] [on-err] ] function? :on-err
	]

	set 'composite function [
		"Return STR with parenthesized expressions evaluated and formed"
		ctx [block!] "Bind expressions to CTX - in any format accepted by WITH function"
		str [any-string!] "String to interpolate"
		/trap "Trap evaluation errors and insert text instead"	;-- not load errors!
			on-err [function! string!] "string or function [error [error!]]"
	][
		s: as string! str
		b: with ctx parse s [collect [
			keep ("")									;-- ensures the output of rejoin is string, not block
			any [
				keep copy some non-paren				;-- text part
			|	keep [#"(" ahead #"\"] skip				;-- escaped opening paren
			|	s: (set [v: e:] transcode/next s) :e	;-- paren expression
				keep (:v)
			]
		]]

		if trap [										;-- each result has to be evaluated separately
			forall b [
				if paren? b/1 [b: insert b [trap-error :on-err]]
			]
			;@@ use map-each when it becomes native
			; b: map-each/eval [p [paren!]] b [['trap-error quote :on-err p]]
		]
		as str rejoin b
		; as str rejoin expand-directives b		-- expansion disabled by design for performance reasons
	]
]


;; has to be both Red & R2-compatible
;; any-string! for composing files, urls, tags
;; load errors are reported at expand time by design
#macro [#composite any-string! | '` any-string! '`] func [[manual] ss ee /local r e s type load-expr wrap keep] [
	set/any 'error try [								;-- display errors rather than cryptic "error in macro!"
		s: ss/2
		r: copy []
		type: type? s
		s: to string! s									;-- use "string": load %file/url:// does something else entirely, <tags> get appended with <>

		;; loads "(expression)..and leaves the rest untouched"
		load-expr: has [rest val] [						;-- s should be at "("
			rest: s
			either rebol
				[ set [val rest] load/next rest ]
				[ val: load/next rest 'rest ]
			e: rest										;-- update the end-position
			val
		]

		;; removes unnecesary parens in obvious cases (to win some runtime performance)
		;; 2 or more tokens should remain parenthesized, so that only the last value is rejoin-ed
		;; forbidden _loadable_ types should also remain parenthesized:
		;;   - word/path (can be a function)
		;;   - set-word/set-path (would eat strings otherwise)
		;@@ TODO: to be extended once we're able to load functions/natives/actions/ops/unsets
		wrap: func [blk] [					
			all [								
				1 = length? blk
				not find [word! path! set-word! set-path!] type?/word first blk
				return first blk
			]
			to paren! blk
		]

		;; filter out empty strings for less runtime load (except for the 1st string - it determines result type)
		keep: func [x][
			if any [
				empty? r
				not any-string? x
				not empty? x
			][
				if empty? r [x: to type x]				;-- make rejoin's result of the same type as the template
				append/only r x
			]
		]

		marker: to char! 40								;@@ = #"(": workaround for #4534
		do compose [
			(pick [parse/all parse] object? rebol) s [
				any [
					s: to marker e: (keep copy/part s e)
					[
						"(\" (append last r marker)
					|	s: (keep wrap load-expr) :e
					]
				]
				s: to end (keep copy s)
			]
		]
		;; change/part is different between red & R2, so: remove+insert
		remove/part ss ee
		insert ss reduce ['rejoin r]
		return next ss									;-- expand block further but not rejoin
	]
	print ["***** ERROR in #COMPOSITE *****^/" :error]
	ee													;-- don't expand failed macro anymore - or will deadlock
]







;-- -- -- -- -- -- -- -- -- -- -- -- -- -- TESTS -- -- -- -- -- -- -- -- -- -- -- -- -- --








; #assert [			;-- this is unloadable because of tag limitations
; 	[#composite <tag flag="(form 1 + 2)">] == [
; 		rejoin [
; 			<tag flag=">	;-- result is a <tag>
; 			(form 3)
; 			{"}				;-- other strings should be normal strings, or we'll have <<">> result
; 		]
; 	]
; ]





									;-- doesn't make sense to include this file without #composite also

;; I'm intentionally not naming it `#error` or the macro may be silently ignored if it's not expanded
;; (due to many issues with the preprocessor)
#macro [
	p: 'ERROR
	(either "ERROR" == mold p/1 [p: []][p: [end skip]]) p		;@@ this idiocy is to make R2 accept only uppercase ERROR
	skip
] func [[manual] ss ee] [
	unless string? ss/2 [
		print form make error! form reduce [
			"ERROR macro expects a string! argument, not" mold copy/part ss/2 50
		]
	]
	remove ss
	insert ss [do make error! #composite]
	ss		;-- reprocess it again so it expands #composite
]

; #debug off


if native? :function [
	context [
		make-check: function [check [paren!] word [get-word!]] [
			compose/deep [
				unless (check) [
					do make error! form reduce [
						"Failed" (mold check) "for" type? (word) "value:" mold/flat/part (word) 40
					]
				]
			]
		]
	
		make-switch: function [word [get-word!] options [block!] values [block! none!]] [
			compose/only pick [[						;-- options may be empty; new-lines matter here
				switch/default type? (word) (options) (values)
			][
				switch type? (word) (options)
			]] block? values
		]
		
		extract-value-checks: function [field [any-word!] types [block!] values [block! none!] /local check words] [
			field: to get-word! field
			typeset: clear []
			options: clear []
			parse types [any [
				copy words some word! (append typeset words)
				opt [
					set check paren! #debug [(
						mask: reduce to block! make typeset! words		;-- break typesets into types
						append/only append options mask make-check check field
					)]
				]
			]]
			reduce [copy typeset  copy options]
		]
	
		spec-word!: make typeset! [word! lit-word! get-word!]
		defaults!: make typeset! [
			scalar! series! map!								;-- most types with lexical forms (save for hash & vector)
			word! lit-word! get-word! refinement! issue!		;-- words excluding set-word
		]
		
		insert-check: function [
			body            [block!]
			word            [get-word!]
			ref?			[logic!] "True if words comes after a refinement"
			default         [defaults! none!]
			types           [block! none!]
			options         [block! none!]
			general-check   [block! none!]
		][
			if types [typeset: make typeset! types]
			if default [
				default: reduce [to set-word! word default]
				logic?: either types [to logic! find typeset logic!][yes]
			]
			need-none-check?: all [ref? either types [not find typeset none!][no]]
			check: case [
				any [not empty? options  all [default logic?]] [	;-- general case - switch
					unless options [options: make block! 2]
					if default [insert options reduce [none! default] ]
					new-line/skip options on 2
					make-switch word options general-check
				]
				all [default general-check] [					;-- optimizations...
					compose/only [								;-- new-line matters here
						either (word) (general-check) (default)
					]
				]
				default [
					compose/only [								;-- new-line matters here
						unless (word) (default)
					]
				]
				all [general-check need-none-check?] [			;-- 'none' = no parameter, and should not be checked
					compose/only [								;-- new-line matters here
						if (word) (general-check)
					]
				]
				general-check [general-check]					;-- 'none' is valid and should be checked as any other value
				'else [ [] ]
			]
			new-line insert body check on
		]
		
		native-function: :function
		set 'function native-function [
			"Defines a function, making all set-words in the body local, and with default args and value checks support"
			spec [block!] body [block!]
			/local word
		][
			ref?: no
			parse spec: copy spec [any [				;-- copy so multiple functions can be created
				[	set word spec-word!
				|	not quote return: change set word set-word! (to word! word)
					[	remove set default defaults!
					|	pos: (ERROR "Invalid default value for '(word) at (mold/flat/part :pos 20)")
					]
				]
				pos: set types opt block!
				opt string!
				remove set values opt paren!
				(
					#debug [general-check: if values [make-check values to get-word! word]]
					if types [
						set [types: options:] extract-value-checks word types general-check
						change/only pos types
					]
					if any [types values default] [
						insert-check body to get-word! word ref? default types options general-check
					]
					set [default: values: options: general-check:] none
				)
			|	refinement! (ref?: yes)					;-- refinements args can be none even if it's not in the typeset
			|	skip
			]]
			native-function spec body
		]
	]
]

; #include %assert.red



; do [
comment [
	probe do probe [f: function [x: 1 [integer! float! (x >= 0)] (x < 0)] [probe x]]
	probe do probe [f: function [x: 1] [probe x]]
	probe do probe [f: function [x: 1 (x < 0)] [probe x]]
	probe do probe [f: function [x: 1 [integer! float!] (x < 0)] [probe x]]
	probe do probe [f: function [x [integer! float!] (x < 0)] [probe x]]
	probe do probe [f: function [x: 1 [integer! (x >= 0)]] [probe x]]
	probe do probe [f: function [/ref x: 1  [integer! (x >= 0) string!]  (find x "0")] [probe x]]
]
							;-- `function` (defaults)
									;-- interpolation in print/call
									;-- `following`





#macro [#stepwise set code block!] func [[manual] s e] [
	while [not empty? code] [
		code: preprocessor/fetch-next insert code [.:]
	]
	remove/part s e
	insert s head code
]



; #include %assert.red


;-- returns none for: zero (undefined exponent), +/-inf (overflow), NaN (undefined)
exponent-of: function [									;@@ also exported by format-readable
	"Returns the exponent E of X = m * (10 ** e), 1 <= m < 10"
	x [number!]
][
	attempt [to 1 round/floor log-10 absolute to float! x]
]

format-number: function [
	"Format a number"
	num      [number!]
	integral [integer!] "Minimal size of integral part (>0 to pad with zero, <0 to pad with space)"
	frac     [integer!] "Exact size of fractional part (0 to remove it, >0 to enforce it, <0 to only use it for non-integer numbers)"
][
	
	frac: either integer? num [max 0 frac][absolute frac]	;-- support for int/float automatic distinction
	expo: any [exponent-of num  0]
	if percent? num [expo: expo + 2]
	;; form works between 1e-4 <= x < 1e16 for floats, < 1e13 for percent so 12 is the target
	digits: form absolute num * (10.0 ** (12 - expo))	;-- 10.0 (float) to avoid integer overflow here!
	remove find/last digits #"."
	if percent? num [take/last digits]					;-- temporarily remove the suffix
	if expo < -1 [insert/dup digits #"0" -1 - expo]		;-- zeroes after dot
	insert dot: skip digits 1 + expo #"."
	if 0 < n: (absolute integral) + 1 - index? dot [	;-- pad the integral part
		char: pick "0 " integral >= 0
		insert/dup digits char n
		dot: skip dot n
	]
	clear either frac > 0 [								;-- pad the fractional part
		dot: change dot #"."
		append/dup digits #"0" frac - length? dot
		skip dot frac
	][
		dot
	]
	if percent? num [append digits #"%"]
	if num < 0 [insert digits #"-"]
	digits
]



;@@ should it have a /utc refinement? if so, how will it work with /from?
timestamp: function [
	"Get date & time in a sort-friendly YYYYMMDD-hhmmss-mmm format"
	/from dt [date!] "Use provided date+time instead of the current"
][
	dt: any [dt now/precise]
	r: make string! 32									;-- 19 used chars + up to 13 trailing junk from dt/second
	foreach field [year month day hour minute second] [
		append r format-number dt/:field 2 -3
	]
	#stepwise [
		skip r 8  insert . "-"
		skip . 6  change . "-"
		skip . 3  clear .
	]
	r
]
									;-- for dump file name


context [
	reduce-deep-change-92: function [owner word target action new index part] [
		f: :owner/on-deep-change-92*
		switch/default action [
			insert     []								;-- no removal phase
			inserted   [f word target part yes no]
			
			;; append's bug is: `append "abc" 123` will have part=1,
			;; and in `append/part` part is related to the appended value
			;; so have to use `length?` to obtain the size of change
			append     []								;-- no removal phase
			appended   [f word (p: skip head target index) length? p yes no]
			
			;; change is buggy: 'change' event never happens
			change     [f word (skip head target index) part no  no]	;-- so this won't fire at all
			changed    [f word (skip head target index) part yes no]	;-- target for some reason is at change's tail
			
			clear      [if part > 0 [f word target part no  no]]	;-- user code should remember 'part' given (if needed)
			cleared    [f word target part no  no]					;-- here part argument is invalid (zero)
			
			;; move is buggy: into another series it does not report anything at all
			;; so we have to assume it's the same series
			;; tried `same? head new head target` but 'moved' reports new=none so won't work
			move       [f word new    part no  yes]		;-- new is used here as source for some reason
			moved      [f word target part yes yes]
			
			;; poke has a bug: `poke "abc" 1 123` will report removal of "b" but will throw an error before insertion
			;; so it's not 100% reliable and I don't have a workaround
			poke       [f word (skip head target index) part no  no]
			poked      [f word (skip head target index) part yes no]
			
			put [
				unless tail? next target [  			;-- put reports found item as target, not the one being changed
					f word next target part no  no		;-- but removed item is not present at tail, so we don't have to report it
				]
			]
			put-ed [f word next target part yes no]
			
			random     [f word target part no  yes]
			randomized [f word target part yes yes]
			
			remove     [if part > 0 [f word target part no  no]]	;-- user code should remember 'part' given (if needed)
			removed    [f word target part no  no]					;-- here part argument is invalid (zero)
			
			reverse    [f word target part no  yes]
			reversed   [f word target part yes yes]
			
			;; sort is buggy in that it reports part=0 regardless of the /part argument
			;; so we have to assume the worst case
			sort       [f word target (length? target) no  yes]
			sorted     [f word target (length? target) yes yes]
			
			swap       [f word target part no  no]	;-- swap may be used on the same buffer, but we have no way of telling
			swaped     [f word target part yes no]
			
			take       [f word target part no  no]	;-- user code should remember 'part' given (if needed)
			taken      [f word target part no  no]	;-- part argument is invalid (zero)
	
			;; trim does not provide enough info to precisely pinpoint changes
			;; so we should consider it as global change from current index
			trim       [f word target (length? target) no  no]	;-- about to remove everything
			trimmed    [f word target (length? target) yes no]	;-- already filled with new stuff
		][
			do make error! "Unsupported action in on-deep-change*!"
		] 
	] 
	
	set 'deep-reactor-92! make deep-reactor! [
		on-deep-change-92*: func [
			word        [word!]    "name of the field value of which is being changed"
			target      [series!]  "series at removal or insertion point"
			part        [integer!] "length of removal or insertion"
			insert?     [logic!]   "true = just inserted, false = about to remove"
			reordering? [logic!]   "removed/inserted items belong to the same series"
			; done?       [logic!]   "signifies that series is in it's final state (after removal/insertion)"
		][
			;; placeholder to override
		]
		
		on-deep-change**: :on-deep-change*
		on-deep-change*: function [owner word target action new index part] [
			reduce-deep-change-92 owner to word! word target action :new index part
			on-deep-change**      owner word target action :new index part
		]
		
		; shouldn't be tampered with
		; on-change**: :on-change*
		; on-change*: function [word [any-word!] old [any-type!] new [any-type!]] [
		; ]
	]
]

comment {
	; test code
	r: make deep-reactor-92! [
		x: "abcd"
		
		on-deep-change-92*: func [
			word        [word!]    "name of the field value of which is being changed"
			target      [series!]  "series at removal or insertion point"
			part        [integer!] "length of removal or insertion"
			insert?     [logic!]   "true = just inserted, false = about to remove"
			reordering? [logic!]   "removed items won't leave the series, inserted items came from the same series"
			; done?       [logic!]   "signifies that series is in it's final state (after removal/insertion)"
		][
			; ...your code to handle changes... e.g.:
			print [
				word ":"
				either insert? ["inserted"]["removing"]
				"at" mold/flat target
				part "items"
				either reordering? ["(reordering)"][""]
				either part = 0 ["(done)"][""]
				; either done? ["(done)"][""]
			]
		]
	]
	
	?? r/x
	insert/part next r/x [1 0 1] 2
	reverse/part next r/x 2
	remove/part next next next r/x 3
	?? r/x
}
									;-- for changes tracking

context expand-directives [
	skip?: func [s [series!]] [-1 + index? s]
	clone: function [									;@@ export it?
		"Obtain a complete deep copy of the data"
		data [any-object! map! series!]
	] with system/codecs/redbin [
		decode encode data none
	]

	keywords: make hash! [								;@@ duplicate! also in parsee.red
		| skip quote none end
		opt not ahead
		to thru any some while
		if into fail break reject
		set copy keep collect case						;-- collect set/into/after? keep pick?
		remove insert change							;-- insert/change only?
		#[true]
	]

	;@@ workaround for #5406 - unable to save global words and words within functions
	;@@ unfortunately this has to modify parse rules in place right in the function
	;@@ so next `parse` run may not work at all... how to work around this workaround? :/
	unloadable?:  func [w [any-word!]] [any [function? w: context? w  w =? system/words]]
	fallback:     func [x [any-type!] y [any-type!]] [any [:y :x]]
	isolate-rule: function [
		"Split parse rule from local function context for Redbin compatibility"
		block [block!]
		/local w v
	][
		unique-rules: make hash! 32						;-- avoid recursing and repeating same rules processing
		;@@ this same code may also collect rule names (dedup)
		parse block rule: [
			end
		|	p: if (find/only/same unique-rules head p) to end
		|	p: (append/only unique-rules head p)
			any [
				change [set w any-word! if (unloadable? w)] (
					fallback							;-- 'w' will be overridden by recursive parse
						w
						attempt [						;-- defend from get/any errors
							set/any 'v get/any w
							anonymize w either block? :v [also v parse v rule][:v]
						]
				)
			; |	ahead any-block! into rule				;@@ doesn't work
			|	ahead block! into rule
			|	skip
			]
		]
		block
	]

	make-dump-name: function [] [
		if exists? filename: rejoin [%"" timestamp %.pdump] [
			append filename enbase/base to #{} random 7FFFFFFFh 16	;-- ensure uniqueness
		]
		filename
	]
	
	set 'parsee function [
		"Process a series using dialected grammar rules, visualizing progress afterwards"
		; input [binary! any-block! any-string!] 
		input [any-string!]								;@@ other types TBD
		rules [block!] 
		/case "Uses case-sensitive comparison" 
		/part "Limit to a length or position" 
			length [number! series!]
		/timeout "Force failure after certain parsing time is exceeded"
			maxtime [time! integer! float!] "Time or number of seconds (defaults to 1 second)"
		/keep "Do not remove the temporary dump file"
		/auto "Only visualize failed parse runs"
		; return: [logic! block!]
	][
		path: to-red-file to-file any [get-env 'TEMP get-env 'TMP %.]
		file: make-dump-name
		parse-result: apply 'parse-dump [
			input rules
			/case    case
			/part    part    length
			/timeout timeout maxtime
			/into    on      path/:file 
		]
		unless all [auto parse-result] [inspect-dump path/:file]
		unless keep [delete path/:file]
		parse-result
	]
	
	config: none
	default-config: #(tool: "parsee")
	
	set 'inspect-dump function [
		"Inspect a parse dump file with PARSEE tool"
		filename [file!] 
	][
		filename: to-local-file filename
		self/config: any [
			config
			attempt [make map! load/all %parsee.cfg]
			default-config
		]
		call-result: call/shell/wait/output command: `{(config/tool) "(filename)"}` output: make {} 64
		; #debug [print `"Tool call output:^/(output)"`]
		if call-result <> 0 [
			print `"Call to '(command)' failed with code (call-result)."`
			if object? :system/view [
				if tool: request-file/title "Locate PARSEE tool..." [
					config/tool: `{"(to-local-file tool)"}`
					call-result: call/shell/wait command: `{(config/tool) "(filename)"}`
					either call-result = 0 [
						save %parsee.cfg mold/only to [] config
					][
						print `"Call to '(command)' failed with code (call-result)."`
					]
				]
			]
			if call-result <> 0 [
				print `"Ensure 'parsee' command is available on PATH, or manually open the saved dump with it."`
				print `"Parsing dump was saved as '(filename)'.^/"`
			]
		]
		exit
	]
	
	set 'parse-dump function [
		"Process a series using dialected grammar rules, dumping the progress into a file"
		input [binary! any-block! any-string!] 
		rules [block!] 
		/case "Uses case-sensitive comparison" 
		/part "Limit to a length or position" 
			length [number! series!]
		;@@ maybe timeout PER char, per 1k chars? or measure and compare end proximity?
		;@@ also 1 second dump generates whole hell of data, with 5-10 secs processing it
		/timeout "Specify deadlock detection timeout"
			maxtime: 0:0:1 [time! integer! float!] "Time or number of seconds (defaults to 1 second)"
		/into filename: (make-dump-name) [file!] "Override automatic filename generation"
		; return: [logic! block!]
	][
		;@@ cloning will pose quite a problem in block parsing! #5406
		cloned:  clone input
		changes: make [] 64
		events:  make [] 512
		limit:   now/utc/precise + to time! maxtime
		age:     0										;-- required to sync changes to events
		reactor: make deep-reactor-92! [
			tracked: input
			on-deep-change-92*: :logger
		]
		following [parse/:case/:part/trace input rules length :tracer] [
			data: reduce [
				cloned
				new-line/all/skip events on 5
				changes
			]
			save/as filename isolate-rule data 'redbin
		]
	]
	
	tracer: function [event [word!] match? [logic!] rule [block!] input [series!] stack [block!] /extern age] with :parse-dump [
		reduce/into [age: age + 1 input event match? rule] tail events
		not all [age % 20 = 0  now/utc/precise > limit]			;-- % to reduce load from querying time
	]
	
	;@@ into rule may swap the series - won't be logged, how to deal? save all visited series? redbin will, but not cloned before modification
	logger: function [
		word        [word!]    "name of the field value of which is being changed"
		target      [series!]  "series at removal or insertion point"
		part        [integer!] "length of removal or insertion"
		insert?     [logic!]   "true = just inserted, false = about to remove"
		reordering? [logic!]   "removed items won't leave the series, inserted items came from the same series"
	] with :parse-dump [
		if zero? part [exit]
						;-- only able to track the input series, nothing deeper
		
		action: pick [insert remove] insert?
		repend changes [
			age
			pick [insert remove] insert?
			skip? target
			copy/part target part
		]
	]
]

