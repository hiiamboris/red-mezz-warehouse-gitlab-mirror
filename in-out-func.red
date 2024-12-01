Red [
	title:   "IN-OUT-FUNC function constructor"
	purpose: "Make functions more readable by allowing lit-arg access as if it was a normal argument"
	author:  @hiiamboris
	license: 'BSD-3
]

#include %keep-type.red

in-out-func: function [
	"Make a function, automatically adding set/get to all lit-args access"
	spec [block!] "Should contain lit-args for any effect"
	body [block!]
][
	lit-words: keep-type spec lit-word!
	save-lf:    [p: (stored: new-line? p)]
	restore-lf: [(new-line p stored)]
	block-rule: [any [save-lf
		ahead set w get-word! if (find lit-words w)
		change only skip (as paren! reduce ['get/any to word! w]) restore-lf
	|	ahead set w word!     if (find lit-words w)
		change only skip (as paren! reduce ['get to word! w]) restore-lf
	|	ahead set w set-word! if (find lit-words w)
		insert ('set) change skip (to word! w) restore-lf
	|	ahead any-list! into block-rule
	|	ahead any-path! into path-rule
	|	ahead word! 'quote skip
	|	skip
	]]
	path-rule: [any [
		ahead set w get-word! if (find lit-words w) change only skip (as paren! reduce ['get/any to word! w])
	|	ahead any-list! into block-rule
	|	skip
	]]
	parse body: copy/deep body block-rule
	function spec body
]

