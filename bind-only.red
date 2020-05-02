Red [
	title:   "BIND-ONLY mezzanine"
	purpose: "Selectively bind a word or a few only (until we have a native)"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		Simple: 
			bind-only code 'my-word

		Interestingly, it does not share the normal bind's spec:
			- subject may never be a word, otherwise it makes no sense: `bind-only 'word target 'word`
			- there's no need in specifying a target as it can be implicitly derived from given words
		It should become a native though, as speed is it's major limitation

		The trick here is that we usually wanna bind a word that's in the current context.
		This saves an extra argument. Compare:
			bind-only code 'word 'word
		to just:
			bind-only code 'word

		So how to rebind some code to words from *other* contexts?
		Easy!
			bind-only code in my-ctx 'my-word
		Binding to different contexts at once is possible:
			c1: context [x: 1]
			c2: context [y: 2]
			c3: context [z: none]
			z: 3
			print bind-only [x y z] reduce [in c1 'x in c2 'y]
		Output:
			1 2 3
		In this case the targets block is likely already provided to the function and is bound accordingly.
	}
]

;; non-strict by default: rebinds any word type
bind-only: function [
	"Selective bind"
	where	[block!] "Block to bind"
	what	[any-word! block!] "Bound word or a block of, to replace to, in the where-block"
	/strict "Compare words strictly - not taking set-words for words, etc."
	/local w
][
	found?: does either block? what [
		finder: pick [find/same find] strict
		compose/deep [all [p: (finder) what w  ctx: p/1]]	;-- use found word's context
	][
		ctx: what										;-- use (static) context of 'what
		pick [ [w =? what] [w = what] ] strict
	]
	parse where rule: [any [
		ahead any-block! into rule						;-- into blocks, parens, paths, hash
	|	change [set w any-word! if (found?)] (bind w ctx)
	|	skip
	]]
	where
]
