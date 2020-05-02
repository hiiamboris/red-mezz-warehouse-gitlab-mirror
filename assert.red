Red [
	title:   "Simple #ASSERT macro and ASSERT mezzanine"
	purpose: "Allow embedding sanity checks into the code, to limit error propagation and simplify debugging"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		Usage:
			#assert [expression]
			See below for more details.
		Tip: include %assert.red first for other scripts to be able to take advantage of it!

		Design deliberations.
		
		Why a macro? because it can eliminate code and with it - performance penalty in functions when turned off
		"#assert" token:
			- visually hints us that this is a directive and that the code may be omitted with all it's side effects
			- gets silently skipped if you do not include the %assert.red, so does no harm and produces no side effects

		`assert` mezz may be used to ensure that the contract is always tested
		and it's also the actual testing function, so can't get rid of it

		[contract in the form of a block]
			- ensures that the contract is not evaluated when assertions are turned off or not included
			- allows to display the original condition on failure
			- allows to report names of words that evaluated to wrong values
			- allows to include an error message

		Supported contract formats are:
			[conditional-expression 'culprit-word]
				conditional-expression evaluates to truthy/falsey value
				culprit-word may evaluate to:
				- a function value - then the word itself will be reported
				- any other value - then both word and it's value will be reported
				Examples:
					#assert [find series value  'series]		;) series will be blamed
					#assert [myfunc x y z  'myfunc]				;) myfunc will be blamed (useful for writing function tests)
					#assert [myfunc x y z  'z]					;) z will be blamed

			[conditional-expression "error message"]
				(anything other than any-word is formed and treated as an error message)
				This is great for documenting code logic, but not so much in actual error reports as it does not show the failed values.
				Examples:
					#assert [find series value  "given series must contain a value"]
					#assert [myfunc x y z  "myfunc should never have failed"]

			[conditional-expression]
				In this case the last value of conditional-expression is chosen as culprit-word.
				This is often handy as there's no need to separately specify a culprit:
					#assert [value]					;) obvious case where value should not be none
					#assert [n = length? s]			;) most likely `s` is what we wanna see on error
					#assert [block? b]				;) definitely we wanna see `b`
					#assert [find series value]		;) here it depends, maybe series is wrong, maybe value
					#assert [dir? dirize path]		;) we want `path` here
				As a general rule, try to rewrite expressions to put the test object at the end:
					#assert [good-value = my/path/accessor]
				rather than
					#assert [my/path/accessor = good-value]

		A more sophisticated version may be built upon TRACE-DEEP:
		see EXPECT, which shows full evaluation backtrace. But it's also slower of course.
		Theoretically, we could automatically reroute the contract into EXPECT on failure,
		but only if we knew there's no side effects and it can be safely repeated.
		I'm still considering if this is the way to go.

		Current limitation:
		For performance, I only `mold` the contract when it fails.
		It however might have been modified by it's own evaluation, so it will be molded in the modified state.
		Which is not a big deal though ;)
	}
]

#macro [#assert 'on]  func [s e] [assertions: on  []]
#macro [#assert 'off] func [s e] [assertions: off []]
#assert on

#macro [#assert block!] func [[manual] s e] [			;-- allow macros within assert block!
	either assertions [
		change s 'assert
	][	remove/part s 2
	]
]

assert: function [contract [block!]][
	set/any [cond msg] reduce contract
	unless :cond [
		print ["ASSERTION FAILURE:" mold/part contract 100]		;-- limit the output in case we have face trees or images
		if none? :msg [set/any 'msg last contract]
		if any [any-word? :msg any-path? :msg] [
			msg: either function? get/any msg
			[ rejoin ["" msg " result is unexpected"] ]
			[ rejoin ["" msg " is " mold/part/flat get/any msg 200] ]
		]
		do make error! form :msg
	]
]
