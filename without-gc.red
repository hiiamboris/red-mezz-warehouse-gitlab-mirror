Red [
	title:    "WITHOUT-GC function"
	purpose:  {Evaluate code with GC temporarily turned off, but restore GC's original state upon exit}
	author:   @hiiamboris
	license:  BSD-3
	provides: without-gc
	notes: {
		Relies on internals of sort at the moment.
		To be revised once we have a way to read GC state - REP #130.
	}
]

without-GC: function [
	"Evaluate CODE with GC temporarily turned off"
	code [block!]
	/local result
][
	sort/compare [1 1] func [a b] [set/any 'result do code]
	:result
]

