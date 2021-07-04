Red [
	title:   "APPLY mezzanine"
	purpose: "Experimental APPLY implementation for inclusion into Red runtime"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		See https://github.com/greggirwin/red-hof/blob/master/apply.md for some background

		Usage patterns:

		I	apply :function 'local						;) 'local carries the context of the caller
			apply  funcname 'local
			apply :function object [arg-name: expression ...]
			apply  funcname object [arg-name: expression ...]

			Set arguments of function to their values from given (directly or indirectly by 'local)
			context and evaluate it. Context will typically be a wrapping function.
			Use cases:
			- function (or native) extension, when argument names are the same, with maybe minor variations.
			- sharing of argument list between a set of functions (CLI lib is an example)
			Example:
				my-find: function
					compose [(spec-of :find) /my-ref]
					[
						..handle /my-ref..
						apply find 'local
					]
				my-find/my-ref/same/skip/only series needle n


		II	apply :function [arg-name: expression ref-name: logic ...]
			apply  funcname [arg-name: expression ref-name: logic ...]
			apply/verb :function [arg-name: value ref-name: logic ...]
			apply/verb  funcname [arg-name: value ref-name: logic ...]

			Call func with arguments and refinements from evaluated expressions
			or verbatim values followng the respective set-words.
			These set-words don't interfere with the expressions,
			so `apply .. [arg: arg]` is a valid usage, not requiring a `compose` call.
			Use case: programmatic call construction, esp. when refinements depend on data.
			Example:
				response: apply send-request [
					link:    params/url
					method:  params/method
					with:    yes						;) refinement state is trivially set
					args:    request
					data:    data						;) sets `data` argument to value of `data` word
					content: bin
					raw:     raw
				]

		Notes on 1st argument:
		- it has to support literal function values for they may be unnamed
		- it has to support function names for better informed stack trace
		- `apply name` form is chosen over `apply 'name` because if we make operator out of apply it will look better:
			->: make op! :apply
			find -> [series: s value: v]				;) rather than `'find -> [series: s value: v]`

		For simplicity in usage, APPLY ignores argument type (normal, lit-arg, get-arg).
		Values given are values passed to the function.
	}
]


#include %error-macro.red

apply: function [
	"Call a function NAME with a set of arguments ARGS"
	'name [word! function!] "Function name or literal"			;@@ support path here or `(in obj 'name)` will be enough?
	args [block! function! object! word!] "Block of [arg: expr ..], or a context to get values from"
	/verb "Do not evaluate expressions in the ARGS block, use them verbatim"
	/local value
][
	if word? :args [args: context? args]
	if all [not verb  block? :args] [					;-- evaluate expressions
		buf: clear copy args
		pos: args
	 	while [not tail? bgn: pos] [
	 		unless set-word? :pos/1 [ERROR "Expected set-word at (mold/part args 30)"]
	 		while [set-word? first pos: next pos][]		;-- skip 1 or more set-words
	 		set/any 'value do/next end: pos 'pos
	 		repeat i offset? bgn end [repend buf [bgn/:i :value]]
	 	]
	 	args: buf
	 	; ? args
	]
	
	;@@ TODO: hopefully in args=block case we'll be able to make it O(n)
	;@@ by having O(1) lookups of all set-words into some argument array specific to each particular function
	;@@ this implementation for now just uses `find` within args block, which makes it O(n^2)
	
	;@@ won't be needed in R/S
	call: reduce [path: as path! reduce [:name]]		;@@ in Red - impossible to add refinements to function literal
	
	either word? :name [
		set/any 'fun get/any name
		unless any-function? :fun [ERROR "NAME argument (name) does not refer to a function"]
	][
		fun: :name
		name: none
	]

	get-value: [
		either block? :args [
			select/skip args to set-word! word 2
		][
			w1: to word! word
			all [
				not w1 =? w2: bind w1 :args				;-- if we don't check it, binds to global ctx
				get/any w2
			]
		]
	]

	use-words?: yes
	foreach word spec-of :fun [
		;@@ the below part will be totally different in R/S,
		;@@ hopefully just setting values at corresponding offsets
		type: type? word
		case [
			type = refinement! [
				if set/any 'use-words? do get-value [append path to word! word]
			]
			not use-words? []							;-- refinement is not set, ignore words
			type = word!     [repend call ['quote do get-value]]
			;@@ extra work that won't be needed in R/S:
			type = lit-word! [repend call as paren! compose/only [(do get-value)]]
			type = get-word! [repend call [do get-value]]
			;@@ type checking - where? should interpreter do it for us?
		]
	]
	; print ["Constructed call:" mold call]
	do call
]

; value: "d"
; probe apply find [series: "abcdef" value: value only: case: yes]

; probe apply find object [series: "abcde" value: "d" only: case: yes]

; my-find: function spec-of :find [
; 	case: yes
; 	only: no
; 	apply find 'only
; ]
; probe my-find/only "abcd" "c"
