Red [
	title:   "Inline profiling macros and functions"
	purpose: "Profile any runtime piece of code with ease"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		Memo: (* *), ***, PROF/EACH, PROF/SHOW, PROF/RESET

		(* *) MACRO that silently collects stats of any code piece

			Wrap a part of your code with (* ... *) to profile it each time it is evaluated:
				loop 5 [
					print "some code"
				(*
					1 + 2
					append/dup [] 1 1000000
					recycle
					wait 0.01
				*)
					print "rest of the code"
				]
			Then call PROF/SHOW to see the stats:
				<5>      0%     0      ms           0 B [1 + 2]
				<5>     54%    93      ms  51'943'976 B [append/dup [] 1 1000000]
				<5>     35%    61      ms -25'166'638 B [recycle]
				<5>     11%    19      ms          46 B [wait 0.01]
			You can see that it was evaluated <5> times, total time spent in each expression, and what took more CPU or RAM.
			This macro is good for collecting stats on small operations, possibly in different parts of the code.


		*** MACRO that profiles each expression after it, and immediately shows the stats
		
			add `***` into any block to profile each expression after `***`:
				my-function [...][
					1 + 2
				***	append/dup [] 1 1000000			;) will print timings starting at this line
					recycle
					wait 0.01
				]
			It's fast to type and is good for quick performance analysis of complex operations,
			but will produce extensive output if iterated too many times.

		Both macros are wrappers around PROF/EACH and PROF/SHOW functions


		PROF/EACH [code]
			Profiles each expression while evaluating a block of code.
		
			Use /TIMES to profile synthetic code or code without side effects:
				>> prof/each/times [1 2 + 3 add 4 5] 999999
				<999999> 20%      .00071ms           0 B [1]
				<999999> 37%      .00127ms           0 B [2 + 3]
				<999999> 43%      .00147ms           0 B [add 4 5]

			Note: normally it returns the value of the last expression so it can be inlined,
			      but with /times it returns unset to reduce noise in the console.

			Units of measure:
				Time is displayed in milliseconds per iteration because:
				- sub-microseconds are beyond SHALLOW-TRACE resolution and only can be found in CLOCK mezz
				- less columns wasted for formatting, freeing space for code lines
				- output is nicely balanced around a central dot
				RAM is displayed in bytes per iteration because:
				- this aligns the column
				- bytes are integers so can be known precisely


		PROF/SHOW
			Shows all profiling stats collected so far.
			Called automatically by PROF/EACH unless it's used with /QUIET refinement.

		PROF/RESET
			Forgets all profiling stats collected so far.
	}
]


#include %assert.red
#include %shallow-trace.red
#include %setters.red
#include %format-readable.red

#macro [ahead word! '*** to end] func [[manual] s e] [	;-- [manual] to support macros inside of it ;@@ + workaround for #3554
	back clear change s reduce ['clock-each copy next s]
]

; #macro [ahead paren! into ['* some [thru '*]]] func [[manual] s e] [	-- this doesn't work in compiler (R2 parse)
#macro [p: paren! :p into [ahead word! '* some [thru [ahead word! '*]]]] func [[manual] s e] [
	e: s/1
	if '* = pick e length? e [							;-- R2 compatibility headaches
		remove s
		remove back tail e
		insert s reduce ['prof/each/quiet to block! next e]
	]
	s
]

once prof: context [									;-- don't reinclude or stats may be reset
	;; data format: [code  code-copy  length-of-code  total-time  total-ram  iteration-count  ...]
	data:         make hash! 120
	;; block of time+ram & code pairs that weren't processed due to control flow escapes:
	pending:      make block! 80
	;; block of [marker  start-time  start-stats]
	; manual-stack: make hash!  60						;@@ hash is buggy - #5118 (and #5096)
	manual-stack: make block! 60
	start-time:   none									;-- used to infer percentage of all time spent on profiled code

	format-delta: function [
		"Number formatter used internally by PROF/EACH"
		delta [number!] dot-index [integer!]
	][
		s: either percent? delta [
			format-readable/size         delta 0
		][	format-readable/extend/clean delta
		]
		dot: index? any [find s #"."  tail s]			;-- align the dot
		pad/left s dot-index - dot + length? s
	]

	ellipsize: function [
		"Molds block B with ellipsis if it's longer than N"
		b [block!] n [integer!]
	][
		b: mold/flat/part b n + 1
		if n < length? b [clear change skip b n - 4 "...]"]
		b
	]

	reset: func ["Forget all collected profiling stats"] [
		clear data ()
		start-time: none
	]

	;@@ TODO: get stats as a table (block), sorted output
	show: function [
		"Print all profiling stats collected so far"
		/only exprs [block!] "Block of blocks, each starting at a profiled expression (must be sequential)"
	][
		all [not only  not empty? pending  process none true]	;-- commit pending results if any
		pos: data
		all [only  none? pos: find/same/only pos exprs/1  exit]	;-- find where /only points to or exit if not found
		to-show: clear []
		width: any [attempt [system/console/size/x - 40] 40]
		foreach [code: code-copy: len: dt: ds: n:] pos [
			all [only  not code =? exprs/1  continue]			;-- skip results not selected for display
			dt: (t: dt) / n										;-- always switch to microsecs so bigger times stand out
			dt: pad format-delta dt 5 10						;-- 9'999.9999 ms: dot=5 total=10
			ds: round/to ds / n 1
			ds: format-delta ds 12								;-- 999'999'999 b: dot=12, total=11
			unless block? code [code-copy: reduce [:code]]		;-- code-copy field is used by manual profiling mode
			slice: ellipsize (copy/part code-copy len) width
			n: pad mold to tag! n 8								;-- '<99999> ' iterations: total=8
			repend to-show [n t dt "ms " ds " B " slice]		;-- 7 items
			if only [exprs: next exprs]
		]
		t-total: sum extract next to-show 7						;-- obtain total time spent during evaluation of chosen exprs
		if 0 = t-total [t-total: 1.0]							;-- avoid zero division
		while [not empty? to-show] [
			amnt: 100% * to-show/2 / t-total 4
			to-show/2: pad format-delta amnt 4 5				;-- '100% ' = 5 chars
			print rejoin copy/part to-show 7
			remove/part to-show 7
		]
		if start-time [
			elapsed: 1e3 * to float! difference now/precise/utc start-time
			amnt: format-readable/size 100% * (t-total / elapsed) 2
			print ["CPU load of profiled code:" amnt]
		]
		()
	]

	manual: function [
		"Profile time between start and end (can be reentrant)"
		mark [immediate! any-string!] "Token that should be same for start and end"
		/start /end
	][
		#assert [any [start end]]
		either start [
			unless start-time [self/start-time: now/precise/utc]
			repend manual-stack [:mark now/precise/utc stats]
		][
			;; measure time & ram delta, remove the started marker
			t: now/precise/utc
			s: stats
			pos: find/reverse/only/skip skip tail manual-stack -2 :mark 3
			#assert [pos]
			ms: 1e3 * to float! dt: difference t pos/2
			ds: s - pos/3       
			remove/part pos 3
			
			;; correct all other started markers by subtracting this one
			pos: manual-stack
			foreach [_ t s] pos [						;@@ should be for-each
				pos/2: t + dt
				pos/3: s + ds
				pos: skip pos 3
			]
			
			;; save result into data
			either pos: find/only/skip data :mark 6 [
				pos/4: pos/4 + ms
				pos/5: pos/5 + ds
				pos/6: pos/6 + 1
			][
				repend pos: tail data [:mark reduce [:mark] 1 ms ds 1]
			] 
		]
	]

	set 'clock-each											;-- left for backward compatibility
	each: function [										;-- new interface: PROF/EACH
		"Display execution time of each expression in CODE"
		code [block!] "Result is only returned if N = 1"
		/times n [integer!] "Repeat the whole CODE N times (default: once); displayed time/RAM is per iteration"
		/quiet "Don't print anything, just save the results for later display via PROF/SHOW"
		/local result
	][
		n: any [n 1]
		code-copy: any [									;-- preserve the original code in case it changes during execution
			select/same/only data code						;-- could be preserved already
			copy/deep code
		]
		test-code: compose [none none (code)]				;-- need 2 no-ops to: (1) negate startup time of `trace`, (2) establish a baseline
		time+ram: make block! 64
		repend pending [code code-copy n time+ram]			;-- stash stats in case the loop doesn't finish
		timer: func [x [any-type!] pos [block!]] [			;-- collects timing of each expression
			t2: now/utc/precise								;-- 2 time markers here - to minimize `timer` influence on timings
			s2: stats
			dt: difference t2 t1
			time+ram: change change change time+ram
				dt      + any [time+ram/1 0.0]				;-- save both timing...
				s2 - s1 + any [time+ram/2 0]				;-- ...allocations size...
				index? pos									;-- ...and position
			s1: stats
			t1: now/utc/precise								;-- /utc is 2x faster
			:x
		]

		loop n [											;-- profile the code
			s1: stats
			t1: now/utc/precise
			set/any 'result shallow-trace :timer test-code	;-- this may throw out of the profiler
			time+ram: head time+ram
		]

		process code quiet									;-- prepare & show the results
		either n = 1 [:result][()]							;-- result is needed for transparent profiling with `***` and `(* *)`
	]
	
	process: function [
		"Process pending profiling results (if any)"
		code [block! none!] "none to process everything"
		quiet [logic!] "Show or not"
	][
		unless code [
			while [code: self/pending/1] [process code quiet]
			exit
		]
	
		set [_: code-copy: n: time+ram:] pending: find/same/only/skip self/pending code 4
		#assert [pending]
		baseline: first sort extract time+ram 3				;-- use the minimal timing as baseline (should be `none`)
		time+ram: skip time+ram 6							;-- hide startup time and baseline code
		to-show: clear []									;-- list of expressions to print stats for
		forall time+ram [									;-- save & maybe display the results
			set [p1: dt: ds: p2:] back time+ram
			dt: 1e3 * to float! dt - baseline				;-- into millisecs
			i: p1 - 2										;-- p1 is off by 2 none values
			either pos: find/same/only data at code i [		;-- already saved? increase total time and iteration count
				pos/4: pos/4 + dt
				pos/5: pos/5 + ds
				pos/6: pos/6 + n
			][
				reduce/into [								;-- code is saved for the first time
					;-- code   moldable code   length   time RAM iterations
					at code i  at code-copy i  p2 - p1  dt   ds  n
				] pos: tail data
			]
			append/only to-show at code i
			time+ram: next next time+ram
		]
		remove/part pending 4
		unless quiet [show/only to-show]
	]
]

; recycle/off
; ; loop 10000 [(* 1 2 3 *)]
; loop 10 [(* wait 0.1 wait 0.01 wait 0.03 make [] 100000 *)]
; ; loop 100 [(* 1 2 3 wait 0.002 *)]
; prof/show
; prof/each/times [1] 10000

; prof/manual/start 'x
; wait 0.5
; prof/manual/start 'y
; wait 0.5
; prof/manual/start 'z
; wait 0.5
; prof/manual/end 'z
; prof/manual/end 'y
; wait 0.5
; prof/manual/end 'x
; prof/show

; prof/manual/start 'x
; prof/manual/start 'x
; wait 0.5
; prof/manual/end 'x
; wait 0.5
; prof/manual/end 'x
; prof/show

; loop 10000 [(* 1 2 3 continue 4 5 6 7 *) 2]
; probe 1
; prof/show
; halt

