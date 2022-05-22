Red [
	title:   "#ASSERT macro and ASSERT mezzanine"
	purpose: "Allow embedding sanity checks into the code, to limit error propagation and simplify debugging"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		TLDR:
			#assert [expression]
			#assert [expression "message"]
			#assert [
				expression1
				expression2 "message"
				expression3
				...
			]

		See assert.md for details.
	}
]

; #do [
; 	included: 1 + either all [value? 'included integer? :included] [included][0]
; 	print ["including assert.red" included "th time"]
; ]

#macro [#assert 'on]  func [s e] [assertions: on  []]
#macro [#assert 'off] func [s e] [assertions: off []]
#do [unless value? 'assertions [assertions: on]]		;-- only reset it on first include

#macro [#assert block!] func [[manual] s e /local nl] [	;-- allow macros within assert block!
	nl: new-line? s
	either assertions [
		change s 'assert
	][
		remove/part s e
	]
	new-line s nl
]

context [
	next-newline?: function [b [block!]] [
		b: next b
		forall b [if new-line? b [return b]]
		tail b
	]

	set 'assert function [
		"Evaluate a set of test expressions, showing a backtrace if any of them fail"
		tests [block!] "Delimited by new-line, optionally followed by an error message"
		/local result
	][
		copied: copy/deep tests							;-- save unmodified code ;@@ this is buggy for maps: #2167
		while [not tail? tests] [
			; print mold/flat copy/part tests 5
			set/any 'result do/next bgn: tests 'tests
			if all [
				:result
				any [new-line? tests  tail? tests]
			] [continue]								;-- total success, skip to the next test

			end: next-newline? bgn
			if 0 <> left: offset? tests end [			;-- check assertion alignment
				if any [
					left < 0							;-- code ends after newline
					left > 1							;-- more than one free token before the newline
					not string? :tests/1				;-- not a message between code and newline
				][
					do make error! form reduce [
						"Assertion is not new-line-aligned at:"
						mold/part at copied index? bgn 100		;-- mold the original code
					]
				]
				tests: end								;-- skip the message
			]

			unless :result [							;-- test fails, need to repeat it step by step
				msg: either left = 1 [first end: back end][""]
				err: next find form try [do make error! ""] "^/*** Stack:"
				prin ["ASSERTION FAILED!" msg "^/" err "^/"]
				expect copy/part at copied index? bgn at copied index? end		;-- expects single expression, or will report no error
				;-- no error thrown, to run other assertions
			]
		]
		()												;-- no return value
	]
]

;@@ `expect` includes trace-deep which has assertions, so must be included after defining 'assert'
;@@ watch out that `expect` itself does not include code that includes `assert`, or it'll crash
#include %expect.red

; #include %localize-macro.red
; #localize [#assert [
; 	a: 123
; 	not none? find/only [1 [1] 1] [1]
; 	1 = 1
; 	100
; 	1 = 2
; 	; 3 = 2 4
; 	2 = (2 + 1) "Message"
; 	3 + 0 = 3

; 	2							;-- valid multiline assertion
; 	-
; 	1
; 	=
; 	1
; ]]

