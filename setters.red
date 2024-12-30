Red [
	title:    "Value setters"
	purpose:  "Simple convenience shortcuts for words assignment"
	author:   @hiiamboris
	license:  BSD-3
	provides: [once default maybe global export quietly anonymize pretending]
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
				maybe/same my/path: my-value
			Ditto, if current value is not same as the new one.

			This is handy in reactivity to stop unnecessary events from firing, reduce lag, break dependency loops.
			It uses strict equality, because otherwise we won't be able to change e.g. "Text" to "TEXT".
			For numerics it's a drawback though, as changing from `0` to `0.0` to `0%` to `1e-100` produces an event.
			/same is useful mostly for object values

		QUIETLY (a macro)
			Syntax:
				quietly my-word: my-value
				quietly my/path: my-value
			Sets my-word or my/path to my-value without triggering on-change* function (thus any kind of reactivity).
			
			Similar to (and is based on) set-quiet routine but supports paths and more readable set-word syntax.
			It's useful either to group multiple changes into one on-change signal,
			or when on-change incurs too much overhead for no gain (e.g. setting of face facets is 25x faster this way).

		EXPORT
			Syntax:
				export [my-func1 my-func2 ...]					;) exports listed words
				export my-ctx									;) exports all words in a context
			Is similar to `import`, but should be called from inside a context, and takes a list of words.

			This is handy when you want to makes a set of context words globally available.

		GLOBAL
			Syntax:
				global my-func:     my-value
				global ctx/my-func: my-value
			Export word or last word in the path into the global namespace.

			This is handy when you want to define a word in the context, but also want it globally available.
			Unlike `export`, this works on a single word/path.

		ANONYMIZE
			Syntax:
				anonymize 'my-word my-value
			It returns 'my-word set to my-value in an anonymous context.

			Useful when you want to have a collection of similarly spelled words with different values.
			It intentionally accepts word!-s only (not set-word!-s),
			because returned word does not belong to the wrapping function's context and should not be /local-ized.
	}
]


; #include %assert.red


once: func [
	"Set value of WORD to VALUE only if it's unset"
	'word [set-word! set-path!]
	value [default!] "New value"
][
	if unset? get/any word [set word :value]
	:value
]

default: func [
	"If WORD's value is none, set it to VALUE"
	'word [set-word! set-path!]
	value [default!] "New value"
][
	switch get/any word [#(none) [set word :value]]		;-- 20% faster than `none =?` which is 5% faster than `none =` and 2x faster than `none?`
	:value
]

maybe: func [
	"If WORDS's value is not strictly equal to VALUE, set it to VALUE (for use in reactivity)"
	'word [set-word! set-path!]
	value [default!] "New value"
	/same "Use =? as comparator instead of =="
][
	if either same [:value =? get/any word][:value == get/any word] [return :value]
	set word :value
]

global: function [
	"Export single word into the global namespace"
	'word [set-word! set-path!]
	value [default!]
][
	alias: either set-path? word [last word][word]
	set bind alias system/words set word :value
]

export: function [
	"Export a set of bound words into the global namespace"
	words [block! object!]
][
	if object? words [words: words-of words]
	foreach w words [set/any bind w system/words get/any :w]
]

anonymize: function [
	"Return WORD bound in an anonymous context and set to VALUE"
	word [any-word!] value [any-type!]
][
	o: construct change [] to set-word! word
	set/any/only o :value
	bind word o
]

pretending: function [
	"Evaluate CODE with WORD set to VALUE, then restore the old value"
	word [any-word! any-path!] value [default!] code [block!]
	/method method' [word!] "Preferred method: [trace (default) trap (faster) do (fastest, unsafe)]"
][
	old: get word
	set word :value
	following/:method code [set word :old] method'
]


;-- there's a lot of ways this function can be written carelessly...
#assert [
	'w     == anonymize 'w 0
	'value  = get anonymize 'value 'value
	true    = get anonymize 'value true
	'true   = get anonymize 'value 'true
	'none   = get anonymize 'value 'none
	unset?    get/any anonymize 'value ()
	[1 2]   = get/any anonymize 'value [1 2]
	#[a: 1] = get/any anonymize 'value #[a: 1]
	(object [a: 1]) = get/any anonymize 'value object [a: 1]
	set-word? get/any anonymize 'value quote value:
	lit-word? get/any anonymize 'value quote 'value
]


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
