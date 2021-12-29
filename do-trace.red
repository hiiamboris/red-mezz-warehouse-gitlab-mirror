Red [
	title:   "DO-TRACE mezzanine"
	purpose: "Provide user-friendly tracing modes based on interpreter's instrumentation"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		DO-TRACE is NOT meant to be used in code directly.
		It is a foundation which collects all kinds of useful data during evaluation.
		Upon this foundation other higher level tools can be built.
		
		See `better-trace.red` for practical application of `do-trace`
		
		Known bugs:
		- do/next, reduce do not report expressions yet
		- throws and errors mess it up, so `attempt`, `try`, `catch` should be avoided for now
		- some compiled functions may produce unexpected event flow and mess it up
		  these are expected to have parse in their code
		  they should be fixed manually by adding [no-trace] flag to their spec
	}
]



context [
	debug?:   no
	;; input
	inspect:  none										;-- inspect function to call
	ievents:  none										;-- events accepted by this inspect function (none = unfiltered)
	iscopes:  none										;-- list of scopes accepted by this inspect fn (none = unfiltered)
	isubex?:  none										;-- whether to call inspect on subexpressions
	;; entered blocks/parens stack:
	blocks:   []										;-- copied
	orgblk:   []										;-- original
	;; depth tracking:
	fdepth:   0											;-- function call depth (prologs/epilogs only)
	level:    []										;-- nesting level of expressions in each block (last 0 = top lvl)
	path:     []										;-- path of refs up to current scope (starts empty)
	;; mirrors of Red stack (of values):
	stack:    []										;-- closer to code (words left alone, series copied)
	evstack:  []										;-- after evaluation, raw values
	;; entered expression lists:
	topexs:   []										;-- top-only, inside code copy
	subexs:   []										;-- all exprs, inside code copy
	orgexs:   []										;-- all exprs, inside original code
	stkexs:   []										;-- all exprs, inside the stack (partially evaluated)
	
	reset: function [] [
		set [inspect iscopes ievents] none
		blks: [blocks orgblk level path stack evstack topexs subexs orgexs stkexs]
		foreach b blks [clear get b]
		self/fdepth: 0
	]

	+=:  make op! func [s [series!] i [any-type!]] [append s :i]
	x=:  make op! func [s [series!] i [any-type!]] [change/only s :i]
	|=:  make op! func [s [series!] i [any-type!]] [append/only s :i]
	||=: make op! func [s [series!] i [any-type!]] [append/only/dup s :i 2]
	; -=:  make op! func [s [series!] n [integer]] [head clear skip tail s -2]
	
	refill: func [old [series!] new [any-type!]] [append clear old :new]

	;@@ TODO: get these two out?
	>>: make op! function [
		"Return series at an offset from head or shift bits to the right"
		data   [series! integer!]
		offset [integer!]
	][
		if integer? data [return shift-right data offset]
		skip head data offset
	]
	
	<<: make op! sneak: function [
		"Return series at an offset from tail or shift bits to the left"
		data   [series! integer!]
		offset [integer!]
	][
		if integer? data [return shift-left data offset]
		skip tail data negate offset
	]
	
	incr: function [x [word! series!] /by o] [
		o: any [o 1]
		either any [path? x word? x] [
			set x (get x) + o
		][
			change x x/1 + o
		]
	]

	set 'do-trace function [
		[no-trace]
		"Trace a block of code, calling inspect for each expression"
		inspect [function!] "func [event [word!] data [object!]]"
		code    [block!]    "If empty, still evaluated once"
		all?    [logic!]    "Trace all sub-expressions of each expression"
		deep?   [logic!]    "Enter functions and natives"
		debug?  [logic!]    "Dump all events encountered"
		/local b
	][
		if tracing? [exit]								;-- impossible to hot-swap tracers atm
		reset
		self/debug?:  debug?
		self/inspect: :inspect
		self/isubex?: all?
		self/ievents: if block? b: first body-of :inspect [b]
		self/iscopes: unless deep? [
			to hash! collect [
				keep/only head code
				parse code rule: [any [
					ahead set b any-block! (keep/only head b) into rule | skip
				]]
			] 
		] 
		do/trace code :data-tracer
	]
	
	;; generic tracer that collects hi-level info on the interpreter
	data-tracer: function [
	    event  [word!]                      			;-- Event name
	    code   [default!]				     			;-- Currently evaluated block
	    offset [integer!]                   			;-- Offset in evaluated block
	    value  [any-type!]                  			;-- Value currently processed
	    ref	   [any-type!]                  			;-- Reference of current call
	    frame  [pair!]                      			;-- Stack frame start/top positions
	][
		;; print out event info for debugging
		if debug? [
			code2: any [
				if all [
					code
					not tail? p: skip copy code offset
				][
					p: head change p as tag! uppercase form p/1
					if s: pick tail topexs -2 [p: at p index? s]
					p
				]
				code
			]
			print [
				uppercase pad event 7
				pad :ref 10
				pad mold/flat/part :value 20 22
				pad mold/flat/part code2 60 62
				pad level 8
			]
		]
		
		call: [
			all [										;-- filtering by events, scope, expression level:
				any [none? ievents  find ievents event]
				any [none? iscopes  none? code  find/same/only iscopes code]
				any [isubex?  0 = last level  all [1 = last level  find [open call return] event]]
				inspect self event code offset :value :ref
			]
		]
		
		;; update last top level expression end
		unless any [
			offset < 0
			find [prolog epilog enter exit init end] event
		][
			ccopy: skip last blocks offset
			topexs << 1 x= ccopy
			subexs << 1 x= ccopy
			if code [change/only orgexs << 1 code >> offset]
		]
				
		if find [return epilog exit expr] event [do call]
		switch event [
			prolog [incr    'fdepth]
			epilog [incr/by 'fdepth -1]
			
			fetch [										;-- save original values pushed to the stack
				;; series are copied to report as they appear in code
				;; this should be safe unless we expect literal series to be huge or cyclic
				stack |= either series? :value [copy/deep value][:value]
			]
			push [evstack |= :value]					;-- save evaluated values pushed to the stack
			
			open [										;-- mark start of a sub-expression
				unless code [exit]						;@@ temp workaround for do/next
				stkpos: stack << 1						;-- back because func name is already on the stack
				if all [								;@@ workaround for ops but it won't work in `op op op` situation
					word? :value
					op? get/any value
				][
					either value =? pick code offset + 1 [
						reverse stkpos: back stkpos
					][
						incr 'offset
					]
				]										;@@ need a more reliable solution
				incr/by 'offset -1						;-- -1 because open happens after the function name
				stkexs |= stkpos
				
				orgexs ||= skip code offset
				subexs ||= skip last blocks offset
				incr level << 1
			]
			call [path += any [ref <anon>]]				;-- collect evaluation path
			return [									;-- revert both
				unless code [exit]						;@@ temp workaround for do/next
				incr/by level << 1 -1
				stkpos: take/last stkexs				;-- update stack with new value
				refill evstack << length? stkpos :value
				refill stkpos :value					
				
				clear orgexs << 2
				clear subexs << 2
				take/last path
			]
			; error []	;@@
			
			enter [										;-- mark start of an inner block of top-level exprs
				stkexs |= tail stack
				blocks |= c2: copy/deep code
				orgblk |= code
				level  |= 0
				
				topexs ||= c2
				orgexs ||= code
				subexs ||= c2
			]
			exit [										;-- revert it
				stkpos: take/last stkexs
				clear evstack << length? stkpos 
				clear stkpos
				take/last blocks
				take/last orgblk
				take/last level
				
				clear topexs << 2
				clear orgexs << 2
				clear subexs << 2
			]
			expr [										;-- remove forgotten expressions from the stack
				stkpos: last stkexs
				clear evstack << length? stkpos 
				clear stkpos
				
				if 0 = last level [topexs << 2 x= last topexs]
				subexs << 2 x= last subexs
				orgexs << 2 x= last orgexs
			]
		]
		
		unless find [return epilog exit expr] event [do call]
	]

];; context


