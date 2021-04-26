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
				<5>       0      ms           0 B [1 + 2]
				<5>      35      ms  53'687'707 B [append/dup [] 1 1000000]
				<5>      29      ms -26'902'506 B [recycle]
				<5>      21      ms          46 B [wait 0.01]
			You can see that it was evaluated <5> times, and what expression took more CPU or RAM.
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
				>> prof/each/times [1 2 + 3 add 4 5] 1000000
				<1000000>    .0002 ms           0 B [1]
				<1000000>    .0004 ms           0 B [2 + 3]
				<1000000>    .00038ms           0 B [add 4 5]

			Note: normally it returns the value of the last expression so it can be inlined,
			      but with /times it returns unset to reduce noise in the console.

			Units of measure:
				Time is displayed in milliseconds per iteration because:
				- sub-microseconds are beyond TRACE resolution and only can be found in CLOCK mezz
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
#include %trace.red
#include %setters.red
#include %format-readable.red

#macro ['*** to end] func [[manual] s e] [				;-- [manual] to support macros inside of it
	back clear change s reduce ['clock-each copy next s]
]

#macro [ahead paren! into ['* some [thru '*]]] func [[manual] s e] [
	e: s/1
	if '* = pick e length? e [							;-- R2 compatibility headaches
		remove s
		remove back tail e
		insert s reduce ['prof/each/quiet to block! next e]
	]
	s
]

once prof: context [									;-- don't reinclude or stats may be reset
	data: make hash! []									;-- collected stats and their code offsets

	format-delta: function [
		"Number formatter used internally by PROF/EACH"
		delta [float! integer!] dot-index [integer!]
	][
		s: format-readable/extend/clean delta
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

	reset: function ["Forget all collected profiling stats"] [clear data]

	;@@ TODO: get stats as a table (block), sorted output
	show: function [
		"Print all profiling stats collected so far"
		/only code [block!] "Only for the selected code block"
	][
		pos: data
		all [only  none? pos: find/same/only pos code  exit]	;-- find where /only points to or exit if not found
		foreach [_: code-copy: len: dt: ds: n:] pos [
			dt: dt / n											;-- always switch to microsecs so bigger times stand out
			dt: pad format-delta dt 5 10						;-- 9'999.9999 ms: dot=5 total=10
			ds: round/to ds / n 1
			ds: format-delta ds 12								;-- 999'999'999 b: dot=12, total=11
			slice: ellipsize (copy/part code-copy len) 40
			n: pad mold to tag! n 7								;-- <99999> iterations: total=7
			print rejoin [n dt "ms " ds " B " slice]
			if only [break]
		]
		()
	]

	set 'clock-each											;-- left for backward compatibility
	each: function [										;-- new interface: PROF/EACH
		"Display execution time of each expression in CODE"
		code [block!] "Result is only returned if N = 1"
		/times n [integer!] "Repeat the whole CODE N times (default: once); displayed time/RAM is per iteration"
		/quiet "Don't print anything, just save the results for later display via PROF/SHOW"
		/local result
	][
		code-copy: any [									;-- preserve the original code in case it changes during execution
			select/same/only data code						;-- could be preserved already
			copy/deep code
		]
		test-code: compose [none none (code)]				;-- need 2 no-ops to: (1) negate startup time of `trace`, (2) establish a baseline
		time+ram: make block! 64

		timer: func [x [any-type!] pos [block!]] [			;-- collects timing of each expression
			t2: now/precise									;-- 2 time markers here - to minimize `timer` influence on timings
			s2: stats
			dt: difference t2 t1							;-- in millisecs
			time+ram: change/only change change time+ram
				dt      + any [time+ram/1 0.0]				;-- save both timing...
				s2 - s1 + any [time+ram/2 0]				;-- ...allocations size...
				index? pos									;-- ...and position
			s1: stats
			t1: now/precise
			:x
		]

		loop n: any [n 1] [									;-- profile the code
			s1: stats
			t1: now/precise
			set/any 'result trace :timer test-code
			time+ram: head time+ram
		]

		baseline: first sort extract time+ram 3				;-- use the minimal timing as baseline (should be `none`)
		time+ram: skip time+ram 6							;-- hide startup time and baseline code
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
			unless quiet [show/only at code i]
			time+ram: next next time+ram
		]
		either n = 1 [:result][()]							;-- result is needed for transparent profiling with `***` and `(* *)`
	]
]

; recycle/off
; ; loop 10000 [(* 1 2 3 *)]
; loop 10 [(* wait 0.1 wait 0.01 wait 0.03 make [] 100000 *)]
; ; loop 100 [(* 1 2 3 wait 0.002 *)]
; prof/show
; prof/each/times [1] 10000



