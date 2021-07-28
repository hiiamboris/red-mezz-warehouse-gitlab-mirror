Red [
	title:   "BULK mezzanine"
	purpose: "Evaluate an expression for multiple items at once"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		See https://github.com/greggirwin/red-hof/tree/master/code-analysis#bulk-syntax for design notes
	}
]


#include %assert.red
#include %error-macro.red
#include %new-each.red									;-- we want map-each


bulk: function [
	"Evaluate an expression, expanding path masks into paths with index for all series items"
	expr [block!] "Should contain at least one path with an asterisk '*'"
	/all "Return all iteration results rather than the last one"
	/local p *
][
	paths: clear []
	expr: copy/deep expr
	parse expr rule: [any [
		ahead set p any-path!
		into [any [
			change '* (to get-word! '*)					;-- replace it with a locally bound '*'
			(append/only paths p)						;-- remember the path for later check
		|	skip
		]]
	|	ahead [block! | paren!] into rule
	|	skip
	]]
	ns: unique map-each p unique paths [				;-- ensure all masked series lengths are equal
		length? get copy/part p back tail p
	]
	case [
		empty?      ns [ERROR "No path masks found in expression: (mold/part expr 50)"]
		not single? ns [ERROR "Path masks refer to series of different lengths in: (mold/part expr 50)"]
	]
	either all [
		collect [repeat * ns/1 [keep/only do expr]]
	][
		repeat * ns/1 expr
	]
]

#assert [(ss: ["ab-c" "-def"] a: [1 2 3] b: [2 3 4])]			;-- init test vars
#assert [[2 3 4 ] = r: bulk/all [b/*           ]  'r]
#assert [[3 5 7 ] = r: bulk/all [a/* + b/*     ]  'r]
#assert [[2 6 12] = r: bulk/all [a/* * b/*     ]  'r]			;-- should not override multiply operator
#assert [[2 6 12] = r: bulk/all [(a/* * b/*)   ]  'r]			;-- should affect parens
#assert [[2 6 12] = r: bulk/all [do [a/* * b/*]]  'r]			;-- should affect inner blocks
#assert [12       = r: bulk     [a/* * b/*     ]  'r]
#assert [[2 4 6 ] = r: (bulk    [a/*: a/* * 2] a) 'r]			;-- set-words must work
#assert [[["ab" "c"] ["" "def"]] = r: bulk/all [split ss/* "-"]  'r]
#assert [error? r: try [bulk [         ]]  'r]
#assert [error? r: try [bulk [b/1      ]]  'r]					;-- no asterisk
#assert [error? r: try [bulk [ss/*: a/*]]  'r]					;-- lengths do not match


