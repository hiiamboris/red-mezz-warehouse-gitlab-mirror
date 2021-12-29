Red [
	title:   "TRACE replacement and ??? macro"
	purpose: "Extends builtin TRACE with user-friendly tracing modes"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		TRACE/HERE is the main use case
		it outputs the result of every literal expression it encounters: 
		
			trace/here [my code]
			
		or just insert `???` in the middle of the code to mark the start of trace:
		[
			... silent code
			???
			traced code ...
		]
		
		TRACE/DEEP also traces function calls
		i.e. every expression inside every called function
		
		TRACE/ALL also traces all sub-expressions
		e.g. `1 + 2` and `3 * 3` in `1 + 2 * 3`
		it is useful when you need to nail down the error
		
		TRACE/DEEP/ALL traces all sub-expressions in all function calls
		so it can generate a huge amount of info, which is only occasionally useful
		
		See tracing.md for more info.
	}
]


#include %do-trace.red

; #macro [ahead word! '??? copy code to end] func [[manual] s e] [	ahead is not known to R2, can't compile
#macro [p: word! :p '??? copy code to end] func [[manual] s e] [	;-- has to support inner `???`s inside the `???` block
	back clear change s reduce ['trace/here code]
]

unless find spec-of :trace /here [context [
	native-trace: :trace
	
	set 'trace function compose [
		[no-trace]
		(head clear find copy spec-of :native-trace /local)
		/here "Trace visible code only"
		/deep "Trace into functions and natives (incompatible with /here)"
		/all  "Trace all sub-expressions of each expression"
		/debug
	][
		either any [here all deep] [
			if system/words/all [deep here] [cause-error 'script 'bad-refines []]
			do-trace :inspect code all deep debug
		][
			either raw
				[native-trace/raw code]
				[native-trace     code]
		]
	]
	
	;; cannot put `indent` into the function itself,
	;; otherwise upon reentry it will instantly refer to a new `indent` which is not set yet
	widths: object [left: 40 right: 30]					;-- column widths, controllable
		
	;; yet another iteration of this func
	mold-part: function [value [any-type!] part [integer!] /only] [
		either only [
			ellipsize-at mold/flat/part/only :value part + 1 part
		][ 
			r: mold/flat/part :value part + 1
			if part < length? r [
				either all [
					any [any-object? :value  block? :value  hash? :value]
					find :r #"["						;-- has opening bracket but no closing one
				][
					clear change skip tail r -5 "...]"
				][
					clear change skip tail r -4 "..."
				]
			]
			r
		]
	]		
		
 	inspect: function [
 		data   [object!]								;-- do-trace stats collection
	    event  [word!]                      			;-- Event name
	    code   [default!]				     			;-- Currently evaluated block
	    offset [integer!]                   			;-- Offset in evaluated block
	    value  [any-type!]                  			;-- Value currently processed
	    ref	   [any-type!]                  			;-- Reference of current call
	    /local word
 	][
 		[expr error throw push return]
		report?: all select [
			expr [
				not data/isubex?
				0 = last data/level						;-- don't report sub-exprs
				not paren? last data/topexs				;-- don't report paren as top-level, even if it technically is
			]
			error [true]
			throw [true]
			push [
				data/isubex?
				any-word? set/any 'word last data/stack
				not same? word last data/evstack
				not find [yes no on off true false none] word
			]
			return [
				data/isubex?
			] 
		] event
		any [report? exit]
		
		full:    any [attempt [system/console/size/1] 80]
		width:   full - 7								;-- last column(1) + " => "(4) + min. indent(2)
		left:    min 60 to integer! width / 2			;-- cap at 60 as we don't want it to be huge
		right:   width - left
		indent:  append/dup clear ""          " " full - 1			;-- indent for code
		indent2: append/dup clear skip "  " 2 "`" full - 3			;-- indent for paths: prefixed by "  "
		level:   (length? data/level) - pick [1 0] 'call = event	;-- 'call' level is deeper by 1
		level:   level % 10 + 1 * 2						;-- cap at 20 as we don't want indent to occupy whole column
		
		either data/isubex? [
			expr: p: last data/stkexs
			either event = 'push [
				expr: back tail expr
			][
				while [set-word? :expr/-1] [expr: back expr]
			]
		][
			p: tail data/topexs
			expr: either 'error = event [p/-2][copy/part p/-2 p/-1]
		]
		if empty? expr [exit]							;@@ workaround for [a: 1] vs [a: 1 + 1] issue
		if paren? expr [expr: as [] expr]				;-- otherwise /only won't remove brackets
		if path?  code [expr: as path! expr]
		
		;; print current path, only works in non-/all mode
		last-path: []									;-- cache it, report only when changed
		unless any [data/isubex?  data/path == last-path] [
			p: change skip indent2 level 
				uppercase mold-part as path! data/path full - 1 - level
			t: tail data/topexs
			pexpr: any [if t/-4 [copy/part t/-4 t/-3] []]		;-- -4..-3 is the parent expression
			if :pexpr/1 == last data/path [pexpr: next pexpr]	;-- don't duplicate last path item
			unless empty? pexpr [
				change change p " " mold-part/only pexpr (length? p) - 1
			]
			print indent2
			append clear last-path data/path
		]
		
		;; print expression and result
		change        skip indent level       mold-part/only expr left - level
		change change skip indent left " => " mold-part :value right
		print indent
	]
	
]];; unless, context


; ;; test code:
; my-func: func [x] [
	; print "print from my-func"
	; if 1 < x [
		; uppercase pick "xy" random true
	; ]
; ]

; caesar: function [s k] [
	; a: charset [#"a" - #"z" #"A" - #"Z"]
	; forall s [if find a s/1 [s/1: (x: s/1 % 32) + 25 + k % 26 + 1 + (s/1 - x)]] s
; ]

; trace/all/deep [
	; do %0.red
	; do/next [1 + 2] 'p			;@@ not yet working
	; caesar "x" -25
	; op: make op! func [:x :y][:y]
	; do op 1 + 2
	; if 1 + 1 < add 2 + 3 4 [add 5 6]
	; b: [x y z]
	; j: 1 + 1
	; to-integer "123"
	; if 1 < 2 [3]
	; do [
		; j: (1 + 1 * 1)
		; try [1 / 0]				;@@ this skips events and destroys tracing
		; select b b/:j
	; ]
	; reduce [2 * 3 (4 + 5)]		;@@ not yet working right
	; my-func 1 + 2
	; this-is-an-error!
; ]

