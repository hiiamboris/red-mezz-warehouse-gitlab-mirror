Red [
	title:   "#composite macro & mezz"
	purpose: "String interpolation"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		It supports only parens as expression designators.

		EXAMPLES:

		#composite

			stdout: #composite %"(working-dir)stdout-(index).txt"
			pid: call/shell #composite {console-view.exe (to-local-file name) 1>(to-local-file stdout)}
			log-info #composite {Started worker (name) ("(")PID:(pid)(")")}
				;) note the natural escape mechanism: ("("), resembling an ugly parrot
			#composite "Worker build date: (var/date) commit: (var2)^/OS: (system/platform)"
			write/append cfg-file #composite "config: (mold config)"
		
			#macro [#print string!] func [[manual] s e] [insert remove s [print #composite] s]
			#print {invoking: (cmd)^/from: "(to-local-file what-dir)"}
			#print "error reading the config file: (msg)"

		composite

			cmd: composite['root] get bind either afile ['avcmd]['vcmd] :a+v
			prints: func [b [block!] s [string!]] [print composite b s]

		See `composite.md` for more
	}
]


; #include %assert.red
#include %with.red


context [
	non-paren: charset [not #"("]
	
	;@@ TODO: error inlining
	set 'composite function [ctx [block!] str [any-string!]] [
		s: as string! str				;-- use "string": load %file/url:// does something else entirely, <tags> get appended with <>
		b: parse s [collect [
			any [
				keep copy some non-paren
			|	s: (set [v: e:] transcode/next s) :e keep (:v)
			]
		]]
		as str rejoin with ctx b
	]
]


#assert [%" - 3 - <abc)))> - func1" == composite[] %"()() - (1 + 2) - (<abc)))>) - ('func)(1)()()"]
#assert [<tag flag=3/> == composite[] <tag flag=(mold 1 + 2)/>]



;@@ TODO: make an escape mechanism? although, it's already there: ("(") (")") (")))((()()("), but can be shorter perhaps?
;@@ TODO: support comments? e.g. `(;-- comments)` in multiline strings, if so - how should it count braces?
;@@ TODO: expand "(#macros)" ?
;; has to be both Red & R2-compatible
;; any-string! for composing files, urls, tags
;; load errors are reported at expand time by design
#macro [#composite set s any-string!] func [[manual] ss ee /local r e type load-expr wrap keep] [
	set/any 'error try [								;-- display errors rather than cryptic "error in macro!"
		r: copy []
		type: type? s
		s: to string! s									;-- use "string": load %file/url:// does something else entirely, <tags> get appended with <>

		;; loads "(expression)..and leaves the rest untouched"
		load-expr: has [rest val] [						;-- s should be at "("
			rest: s
			either rebol
				[ set [val rest] load/next rest ]
				[ val: load/next rest 'rest ]
			e: rest										;-- update the end-position
			val
		]

		;; removes unnecesary parens in obvious cases (to win some runtime performance)
		;; 2 or more tokens should remain parenthesized, so that only the last value is rejoin-ed
		;; forbidden _loadable_ types should also remain parenthesized:
		;;   - word/path (can be a function)
		;;   - set-word/set-path (would eat strings otherwise)
		;@@ TODO: to be extended once we're able to load functions/natives/actions/ops/unsets
		wrap: func [blk] [					
			all [								
				1 = length? blk
				not find [word! path! set-word! set-path!] type?/word first blk
				return first blk
			]
			to paren! blk
		]

		;; filter out empty strings for less runtime load (except for the 1st string - it determines result type)
		keep: func [x][
			if any [
				empty? r
				not any-string? x
				not empty? x
			][
				if empty? r [x: to type x]				;-- make rejoin's result of the same type as the template
				append/only r x
			]
		]

		marker: to char! 40								;@@ = #"(": workaround for #4534
		do compose [
			(pick [parse/all parse] object? rebol) s [
				any [
					s: to marker e: (keep copy/part s e)
					s: (keep wrap load-expr) :e
				]
				s: to end (keep copy s)
			]
		]
		;; change/part is different between red & R2, so: remove+insert
		remove/part ss ee
		insert ss reduce ['rejoin r]
		return ee
	]
	print ["***** ERROR in #COMPOSITE *****^/" :error]
	ee
]


#assert [
	(b: [#composite %"()() - (1 + 2) - (<abc)))>) - (func)(1)()()"]) == [
		rejoin [
			%""				;-- first string determines result type - should not be omitted
			() ()			;-- () makes an unset, no empty strings inbetween
			" - "			;-- subsequent string fragments of string type
			(1 + 2)			;-- 2+ tokens are parenthesized
			" - "
			<abc)))>		;-- an explicit tag! - not a string!; without parens around
			" - "
			(func)			;-- words are parenthesized
			1				;-- single token without parens
			() ()			;-- no unnecessary empty strings
		]
	]
	'b
]

#assert [
	(b: [#composite <tag flag=(mold 1 + 2)/>]) == [
		rejoin [
			<tag flag=>		;-- result is a <tag>
			(mold 1 + 2)
			{/}				;-- other strings should be normal strings, or we'll have <<">> result
		]
	]
	'b
]

; #assert [			;-- this is unloadable because of tag limitations
; 	[#composite <tag flag="(form 1 + 2)">] == [
; 		rejoin [
; 			<tag flag=">	;-- result is a <tag>
; 			(form 3)
; 			{"}				;-- other strings should be normal strings, or we'll have <<">> result
; 		]
; 	]
; ]


