Red [
	title:   "CLOCK-EACH mezzanine with baseline support"
	purpose: "Allows you to profile each expression in a block of code"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		Embed inside your script to find what's causing the most delay:
		 >> clock-each [
				1 + 2
				append/dup [] 1 1000000
				recycle
				wait 0.01
			]
		0.0 μs	[1 + 2]
		41.0 ms	[append/dup [] 1 1000000]
		17.0 ms	[recycle]
		10.0 ms	[wait 0.01]

		Use /times to profile synthetic code or code without side effects:
		 >> clock-each/times [
				wait 0.001
				wait 0.002
				wait 0.003
			] 100
		1.00 ms	[wait 0.001]
		2.00 ms	[wait 0.002]
		3.00 ms	[wait 0.003]

		 >> clock-each/times [1 2 + 3 add 4 5] 1000000
		0.02 μs	[1]
		0.22 μs	[2 + 3]
		0.27 μs	[add 4 5]
	}
]


#include %trace.red

clock-each: function [
	"Display execution time of each expression in CODE"
	code [block!]
	/times n [integer!] "Repeat the whole CODE N times (default: once); displayed time is per iteration"
][
	orig: copy/deep code								;-- preserve the original code in case it changes during execution
	code: append copy code none							;-- need a no-op to establish a baseline
	times: make block! 64

	timer: func [x [any-type!] pos [block!]] [			;-- collects timing of each expression
		t2: now/precise									;-- 2 time markers here - to minimize `timer` influence on timings
		dt: difference t2 t1							;-- in millisecs
		times: change/only change times
			dt + any [times/1 0.0]						;-- save both timing...
			index? pos									;-- ...and position
		t1: now/precise
	]

	loop n: any [n 1] [									;-- profile the code
		t1: now/precise
		trace :timer code
		times: head times
	]

	baseline: first sort extract times 2				;-- use the minimal timing as baseline
	clear skip tail times -2							;-- hide the baseline code
	times: insert times 1
	forall times [										;-- display the results
		set [p1 dt p2] back times
		dt: 1e3 / n * to float! dt - baseline				;-- into millisecs
		unit: either dt < 1 [dt: dt * 1e3 "μs^-"]["ms^-"]	;-- switch to microsecs?
		parse form dt [										;-- save 3 significant digits max
			0 3 [opt #"." skip] opt [to #"."] dt: (dt: head clear dt)
		]
		code: copy/part at orig p1 p2 - p1
		print [dt unit mold/flat/part code 70]
		times: next times
	]
	()													;@@ should it return the last value?
]

