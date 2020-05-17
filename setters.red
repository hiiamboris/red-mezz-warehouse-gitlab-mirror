Red [
	title:   "Value setters"
	purpose: "Varies... ;)"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		Why set-words/set-paths?
			Set-words because this gets words automatically collected by `function`, and just reads better.
			Set-paths - to have syntax similar to set-words.
		Why I'm not using `set/any` but `set` in these functions, and do not allow unset for the value?
			To follow the normal `word: value` behavior, which throws an error when value is unset

		ONCE
			Syntax:
				once my-word: my-value
			Sets my-word to my-value only if the former is unset.

			If you have some initialization code in your script, and you reload this script often,
			use `once` to stop these code pieces from being re-evaluated upon loading.
			Simple values, functions, do not require it, but if the code affects global state - it becomes very handy.

			Question is, should it support paths?
				once my/path: my-value ?
			I haven't had a use case so far.

			Another question: should `once` and `default` be unified?
			Their use cases are somewhat different, even though similar in implementation.

		DEFAULT
			Syntax:
				default my-word: my-value
				default my/path: my-value
			Sets my-word or my/path to my-value only if former is none.
			
			This is similar to the construct we must be all using sometime in functions:
				my-word: any [my-word my-value]
			but reads better.
			
			Another subtle difference:
				my-word: any [my-word calculate-it]     -- will not call `calculate-it`
				default my-word: calculate-it           -- will call `calculate-it`
			When critical not to call extra code (slowdowns/crashes?), just resort to `any` form.
			I find that such cases are relatively rare and do not justify the `default my-word: [calculate-it]` form.

		MAYBE
			Syntax:
				maybe my-word: my-value
				maybe my/path: my-value
			Sets my-word or my/path to my-value only if it's current value does not strictly equal the new one.

			This is handy in reactivity to stop unnecessary events from firing, reduce lag, break dependency loops.
			It uses strict equality, because otherwise we won't be able to change e.g. "Text" to "TEXT".
			For numerics it's a drawback though, as changing from `0` to `0.0` to `0%` to `1e-100` produces an event.

		IMPORT
			Syntax:
				import my-ctx
			Import all words from a given context into the global namespace.

			This is sometimes useful in debugging, when you have multiple internal functions in some context,
			and you wanna play with those functions in console until you're satisfied with their results.
	}
]


once: func [
	"Set value of WORD to VAL only if it's unset"
	:word [set-word!]
	val   [default!] "New value"
][
	unless value? to word! word [set word :val]
	:val
]

default: func [
	"If SUBJ's value is none, set it to VAL"
	:subj [set-word! set-path!]
	val   [default!] "New value"
][
	if set-path? subj [subj: as path! subj]				;-- get does not work on set-paths
	if none =? get/any subj [set subj :val]				;-- `=?` is like 5% faster than `=`, and 2x faster than `none?`
	:val
]

maybe: func [
	"If SUBJ's value is not strictly equal to VAL, set it to VAL (for use in reactivity)"
	:subj [set-word! set-path!]
	val   [default!] "New value"
][
	if set-path? subj [subj: as path! subj]				;-- get does not work on set-paths
	unless :val == get/any subj [set subj :val]
	:val
]

import: func [
	"Import words from context CTX into the global namespace"
	ctx [object!]
][
	set  bind words-of ctx system/words  values-of ctx
]

