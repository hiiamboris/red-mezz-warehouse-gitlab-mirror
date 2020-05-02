Red [
	title:   "STEPWISE (function variant)"
	purpose: "Allows you write long compound expressions as a sequence of steps"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		stepwise [
			2							;== 2
			. * 3						;== 6
			. + .						;== 12
			append/dup "" "x" . / 3		;== "xxxx"
			clear next .				;== tail "x"
			head .						;== "x"
		]
	}
	limitations: {
		- diverts `return`, `exit` and `local` (will be fixed once we have fast native bind/only; without it will be too slow)
		- slower than the macro version - computational cost is paid at run time during each invocation
	}
]

#include %trace.red


;; NOTE: safe in recursion: stepwise [2 (stepwise [3]) * .]  -- returns 6, not 9
stepwise: function [
	"Evaluate code by setting `.` word to the result of each expression"
	. [block!] "Block of code"		;-- can't name this `code`, else `code` name will be exposed to itself by `bind` -- will be fixed by native bind/only
][
	trace 
		func [x [any-type!] _] [set/any '. :x]		;-- save result of the last expr in `.`
		also
			bind . '.								;-- `.` inside code block should refer to the local word
			unset '.								;-- first usage of `.` inside the code should yield `unset` rather than the code itself
]


comment {
	;; this version has 2-3x bigger memory footprint, and is ~5% slower
	stepwise: function [
		"Evaluate CODE by setting `.` word to the result of each expression"
		code [block!]
	][
		;; `code` can't be bound to `stepwise` context, or we expose it's locals
		bind code f: has [.] [							;-- localize `.` to allow recursion
			unset '.									;-- for `stepwise []` to equal `stepwise [.]`
			trace :setter code
		]
		setter: func [x [any-type!] _] bind [set/any '. :x] :f
		f
	]
}