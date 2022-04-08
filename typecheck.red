Red [
	title:   "TYPECHECK function"
	purpose: "Mini-DSL for type checking and constraint validity insurance"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		TIP: wrap it into #debug [] macro so it doesn't affect release code performance
		
		DSL summary:
		
			typecheck [
				word1 [type! (condition to test if of this type) ...]
				word2 [type1! (...) type2! ...]			;) multiple types and conditions are possible
				word3 [typeset!] 						;) conditions are optional and typesets are supported
				word4 [type1! type2!] (global test)		;) outside condition is tested regardless of the type
				...
			]
	}
]

; #include %assert.red
; #include %localize-macro.red

#include %keep-type.red

context [
	;; in line with #assert, doesn't throw any errors
	error: func [msg] [print ["TYPECHECK FAILED:" msg] none]

	set 'typecheck function [
		"Check types of all given words"
		words [block!] "A sequence of: word [type! (type-test) ...] (global-test)"
		/local word type
	][
		ok?: yes
		do-test: [
			unless do test [
				value: mold/flat/part get/any word 40
				error rejoin ["Test "mold test" failed for "word" = "value]
			]	
		]
		types: [
			list: (type-match?: no)						;-- no match on empty set
			any [
				if (type-match?) to end					;-- stop once found a match
			|	set type word! (
					value: get type
					type-match?: case [
						datatype? :value [value    = type? get/any word]
						typeset?  :value [find value type? get/any word]
						'else [error rejoin ["Word "type" must refer to a datatype or typeset"]]
					]
				)
				opt [set test paren! (all [type-match?  do do-test])]
			] (
				unless ok?: type-match? [
					type: type?/word get/any word
					allowed: mold keep-type list word!
					error rejoin ["Word "word" is of type "type", allowed: "allowed]
				]
			)
		]
		parse words [
			any [
				set word word! (type-match?: yes)
				opt [ahead block! into types]
				opt [set test paren! (do do-test)]
			]
			[end | p: (error rejoin ["Unexpected token "mold :p/1" in typecheck spec"])]
		]
		ok?
	]
]


#localize [#assert [
	(x: 1 y: 'y)
	typecheck [x [integer!] y [word!]]
	typecheck [x [none! integer!] y [any-word!]]
	typecheck [x [number! (x > 0)] y [any-word! (find [y] y)]]
]]
