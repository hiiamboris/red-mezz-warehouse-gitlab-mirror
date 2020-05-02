Red [
	title:   "TRACE mezzanine"
	purpose: "Step-by-step evaluation of a block of expressions with a callback"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		TRACE is a basis function to build upon.
		See CLOCK-EACH, STEPWISE and SHOW-TRACE for example usage
	}
	limitations: {
		- diverts `return`, `exit` and `local` (will be fixed once we have fast native bind/only; without it will be too slow)
		- slower than the macro version - computational cost is paid at run time during each invocation
	}
]

trace: func [
	"Evaluate each expression in CODE and pass it's result to the INSPECT function"
	inspect	[function!] "func [result [any-type!] next-code [block!]]"
	code	[block!]	"If empty, still evaluated once (resulting in unset)"
	/local r
][
	#assert [parse spec-of :inspect [thru word! quote [any-type!] thru word! not to word! end]]
	until [
		set/any 'r do/next code 'code					;-- eval at least once - to pass unset from an empty block
		inspect :r code
		tail? code
	]
	:r
]

