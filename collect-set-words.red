Red [
	title:   "COLLECT-SET-WORDS mezzanine"
	purpose: "Helpful in localizing a piece of code"
	author:  @hiiamboris
	license: 'BSD-3
]


collect-set-words: function [
	"Deeply collect set-words from a block of code"
	code [block!]
][
	spec: spec-of function [] code
	parse spec [remove /local any change set w word! (to set-word! w)]
	spec
]

comment {
	;-- this version is 4x slower
	collect-set-words: function [
		"Deeply collect set-words from a block of code"
		code [block!]
	][
		rule: [any [
			ahead [block! | paren!] into rule
		|	keep set-word!
		|	skip
		]]
		parse code [collect rule]
	]
}